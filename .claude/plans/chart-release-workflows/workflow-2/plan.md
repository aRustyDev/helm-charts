# Workflow 2: Filter Charts - Phase Plan

## Overview
**Trigger**: `push` → `integration` branch (with changes to `charts/**`)
**Purpose**: Detect changed charts and create per-chart branches for atomic processing

---

## Relevant Skills

Load these skills before planning, research, or implementation:

| Skill | Path | Relevance |
|-------|------|-----------|
| **CI/CD GitHub Actions** | `~/.claude/skills/cicd-github-actions-dev/SKILL.md` | Concurrency control, matrix jobs, branch operations, git commands in workflows |
| **Helm Chart Development** | `~/.claude/skills/k8s-helm-charts-dev/SKILL.md` | Chart structure, detecting chart changes |

**How to load**: Read the SKILL.md files at the start of implementation to access patterns and best practices.

---

## Prerequisites

### Shared Components Required
- [x] `detect_changed_charts` shell function (in attestation-lib.sh)
- [x] `extract_attestation_map` shell function (in attestation-lib.sh)
- [x] `get_source_pr` shell function (in attestation-lib.sh)

### Infrastructure Required
- [x] `integration` branch created
- [ ] `integration-chart-protection` ruleset configured (Phase 2.0)
- [ ] GitHub Actions added to ruleset bypass list OR GitHub App configured

### Upstream Dependencies
- [x] Workflow 1 must be functional (provides attestation map)

---

## Architecture Decision: Push vs PR

### Decision: Direct Push with Bypass

W2 will **directly push** to `integration/<chart>` branches using GitHub Actions with ruleset bypass.

**Rationale**:
- Simpler implementation than creating intermediate PRs
- Faster execution (no PR creation/merge cycle)
- `GITHUB_TOKEN` can push to branches if Actions is in the bypass list
- W3 already validates that only `integration` branch merges to `integration/<chart>`

**Alternative Considered**: Creating PRs from temporary branches was rejected due to:
- Added complexity (temp branch creation, PR creation, waiting for merge)
- No additional security benefit (W3 validates source anyway)

---

## Implementation Phases

### Phase 2.0: Infrastructure Setup
**Effort**: Low
**Dependencies**: None
**Blocker**: Must complete before other phases

**Tasks**:
1. Create `integration-chart-protection` ruleset:
   ```json
   {
     "name": "integration-chart-protection",
     "target": "branch",
     "enforcement": "active",
     "conditions": {
       "ref_name": {
         "include": ["refs/heads/integration/*"],
         "exclude": []
       }
     },
     "rules": [
       { "type": "non_fast_forward" }
     ],
     "bypass_actors": [
       {
         "actor_id": 5,
         "actor_type": "Integration",
         "bypass_mode": "always"
       }
     ]
   }
   ```
   Note: `actor_id: 5` is GitHub Actions. Verify with `gh api /repos/{owner}/{repo}/rulesets` after creation.

2. Verify GitHub Actions can push to `integration/*` branches

**Deliverable**: Ruleset created and tested

---

### Phase 2.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: Phase 2.0

**Tasks**:
1. Create `.github/workflows/filter-charts.yaml`
2. Configure trigger for `push` → `integration` with path filter `charts/**`
3. Set up permissions (contents: write, pull-requests: write, id-token: write, attestations: write)
4. Configure checkout with full history
5. Add concurrency control to prevent race conditions

**Code**:
```yaml
name: W2 - Filter Charts

on:
  push:
    branches:
      - integration
    paths:
      - 'charts/**'

permissions:
  contents: write
  pull-requests: write
  id-token: write
  attestations: write

concurrency:
  group: w2-filter-charts
  cancel-in-progress: false

env:
  TARGET_BRANCH: main
```

**Deliverable**: Workflow triggers on merge to integration

---

### Phase 2.2: Chart Detection Logic
**Effort**: Low
**Dependencies**: Phase 2.1

**Tasks**:
1. Use existing `detect_changed_charts` function from attestation-lib.sh
2. Handle both squash merges and merge commits
3. Output list of chart names as JSON array for matrix jobs
4. Handle edge case: non-chart files in charts/ directory

**Code**:
```bash
detect_charts_for_push() {
  # Handle both squash merges and merge commits
  local range
  if git rev-parse HEAD^2 >/dev/null 2>&1; then
    # Merge commit - compare against first parent
    range="HEAD^..HEAD"
  else
    # Squash merge or regular commit
    range="HEAD~1..HEAD"
  fi

  git diff --name-only "$range" | \
    grep '^charts/' | \
    cut -d'/' -f2 | \
    sort -u
}
```

**Edge Cases Handled**:
- Changes to shared files (e.g., `charts/README.md`) → filtered out by checking for Chart.yaml
- Only Chart.lock changes → included (dependency updates should flow through)

---

### Phase 2.3: Source PR Discovery
**Effort**: Medium
**Dependencies**: Phase 2.1

**Tasks**:
1. Find the PR that was merged (created this push)
2. Extract PR body containing attestation map
3. Validate attestation map exists (warn if missing, don't block)
4. Store source PR number and attestation map for downstream use

**Code**:
```bash
# Use get_source_pr from attestation-lib.sh
source .github/scripts/attestation-lib.sh

SOURCE_PR=$(get_source_pr HEAD)
if [[ -z "$SOURCE_PR" ]]; then
  echo "::warning::Could not find source PR for merge commit"
  ATTESTATION_MAP='{}'
else
  echo "::notice::Source PR: #$SOURCE_PR"
  ATTESTATION_MAP=$(extract_attestation_map "$SOURCE_PR")

  if [[ "$ATTESTATION_MAP" == "{}" ]]; then
    echo "::warning::Source PR #$SOURCE_PR has no attestation map"
  else
    echo "::notice::Found attestation map with $(echo "$ATTESTATION_MAP" | jq 'keys | length') entries"
  fi
fi
```

**Merge Strategy Handling**:
| Strategy | PR Discovery Method |
|----------|---------------------|
| Squash merge | PR # in commit message |
| Merge commit | GitHub API lookup by SHA |
| Rebase merge | GitHub API lookup by SHA |

---

### Phase 2.4: Per-Chart Branch Management
**Effort**: High
**Dependencies**: Phase 2.2, Phase 2.3

**Tasks**:
1. For each detected chart:
   - Create `integration/<chart>` branch from current HEAD if it doesn't exist
   - Or update existing branch with new changes
2. Use atomic operations to prevent partial failures
3. Handle push conflicts with retry logic

**Code**:
```bash
process_chart() {
  local chart="$1"
  local source_pr="$2"
  local attestation_map="$3"

  echo "::group::Processing chart: $chart"

  local branch="integration/$chart"

  # Check if branch exists remotely
  if git ls-remote --heads origin "$branch" | grep -q "$branch"; then
    echo "Branch $branch exists, will update"
    git fetch origin "$branch"
    git checkout -B "$branch" "origin/$branch"

    # Cherry-pick or merge the chart changes
    git checkout HEAD -- "charts/$chart/"
  else
    echo "Creating new branch: $branch"
    git checkout -b "$branch"
  fi

  # Check if there are changes to commit
  if git diff --cached --quiet && git diff --quiet "charts/$chart/"; then
    echo "::notice::No changes to commit for $chart"
    echo "::endgroup::"
    return 0
  fi

  # Stage and commit changes
  git add "charts/$chart/"
  git commit -m "chore($chart): sync from integration

Source PR: #$source_pr
Attestation Map: $attestation_map"

  # Push with retry logic
  local max_retries=3
  for ((i=1; i<=max_retries; i++)); do
    if git push origin "$branch" --force-with-lease; then
      echo "::notice::Successfully pushed $branch"
      break
    fi

    if [[ $i -eq $max_retries ]]; then
      echo "::error::Failed to push $branch after $max_retries attempts"
      return 1
    fi

    echo "::warning::Push failed, retrying ($i/$max_retries)..."
    git fetch origin "$branch"
    git rebase "origin/$branch"
    sleep $((i * 2))
  done

  echo "::endgroup::"
}
```

**Conflict Resolution Strategy**:
- Use `--force-with-lease` to detect concurrent updates
- On conflict: fetch, rebase, retry (up to 3 times)
- If still failing: fail the job, require manual intervention

---

### Phase 2.5: PR Creation/Update
**Effort**: Medium
**Dependencies**: Phase 2.4

**Tasks**:
1. For each chart branch, check if PR to `main` already exists
2. If PR exists: Update PR body with new attestation map
3. If no PR: Create new PR with:
   - Title: `chore(<chart>): promote to main`
   - Body: Source PR reference, full attestation map, changelog preview
4. Label PRs for easy identification

**Code**:
```bash
create_or_update_pr() {
  local chart="$1"
  local source_pr="$2"
  local attestation_map="$3"

  local branch="integration/$chart"

  # Check for existing PR
  local existing_pr
  existing_pr=$(gh pr list --head "$branch" --base main --json number --jq '.[0].number' 2>/dev/null || echo "")

  local pr_body
  pr_body=$(cat <<EOF
## Chart: $chart

Promoting changes from integration branch to main.

### Source
- Source PR: #$source_pr
- Source Branch: integration

### Attestation Lineage
This PR carries forward the attestation chain from the source PR.

<!-- ATTESTATION_MAP
$attestation_map
-->

---
*This PR was automatically created by W2 - Filter Charts workflow.*
EOF
)

  if [[ -n "$existing_pr" ]]; then
    echo "::notice::Updating existing PR #$existing_pr for $chart"
    gh pr edit "$existing_pr" --body "$pr_body"
  else
    echo "::notice::Creating new PR for $chart"
    gh pr create \
      --head "$branch" \
      --base main \
      --title "chore($chart): promote to main" \
      --body "$pr_body" \
      --label "automated,chart-release"
  fi
}
```

**PR Body Contents**:
- Reference to source PR (for traceability)
- Full attestation map (copied from source PR)
- Chart name clearly identified
- Automation marker

---

### Phase 2.6: W2 Attestation Generation
**Effort**: Medium
**Dependencies**: Phase 2.4, Phase 2.5

**Tasks**:
1. Generate attestation for the W2 filtering operation
2. Subject: List of charts processed + source PR
3. Store attestation ID for downstream verification

**Code**:
```yaml
- name: Generate W2 attestation
  id: w2-attestation
  env:
    CHARTS_PROCESSED: ${{ steps.detect.outputs.charts }}
    SOURCE_PR: ${{ steps.source.outputs.pr_number }}
  run: |
    # Create subject content
    SUBJECT_CONTENT=$(cat <<EOF
    {
      "workflow": "W2-filter-charts",
      "source_pr": "$SOURCE_PR",
      "charts_processed": $CHARTS_PROCESSED,
      "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    }
    EOF
    )

    # Generate digest
    DIGEST=$(echo -n "$SUBJECT_CONTENT" | sha256sum | cut -d' ' -f1)
    echo "digest=sha256:$DIGEST" >> "$GITHUB_OUTPUT"
    echo "subject=$SUBJECT_CONTENT" >> "$GITHUB_OUTPUT"

- name: Create attestation
  id: attestation
  uses: actions/attest-build-provenance@v2
  with:
    subject-name: "w2-filter-charts"
    subject-digest: ${{ steps.w2-attestation.outputs.digest }}
    push-to-registry: false
```

---

### Phase 2.7: Branch Cleanup Policy
**Effort**: Low
**Dependencies**: All previous phases

**Tasks**:
1. Define cleanup triggers:
   - `integration/<chart>` branch deleted after PR merged to main
   - Stale branches (no PR, older than 7 days) cleaned up weekly
2. Implement cleanup in W6 (after tag creation) or separate scheduled workflow

**Cleanup Strategy**:
| Scenario | Action | Timing |
|----------|--------|--------|
| PR merged to main | Delete `integration/<chart>` branch | W6 (post-tag) |
| PR closed without merge | Keep branch for retry | Manual cleanup |
| Stale branch (no activity) | Delete if no open PR | Weekly cron job |

**Code** (for W6 or separate workflow):
```bash
cleanup_chart_branch() {
  local chart="$1"
  local branch="integration/$chart"

  # Verify no open PRs from this branch
  local open_prs
  open_prs=$(gh pr list --head "$branch" --state open --json number --jq 'length')

  if [[ "$open_prs" -eq 0 ]]; then
    echo "::notice::Deleting branch $branch (no open PRs)"
    git push origin --delete "$branch" || true
  else
    echo "::warning::Cannot delete $branch - has $open_prs open PR(s)"
  fi
}
```

---

### Phase 2.8: Error Handling & Observability
**Effort**: Low
**Dependencies**: All previous phases

**Tasks**:
1. Handle partial failures (some charts succeed, others fail)
2. Create summary output with status per chart
3. Send notifications on failure (via job summary)

**Code**:
```yaml
- name: Generate summary
  if: always()
  run: |
    echo "## W2 - Filter Charts Summary" >> $GITHUB_STEP_SUMMARY
    echo "" >> $GITHUB_STEP_SUMMARY
    echo "| Chart | Branch | PR | Status |" >> $GITHUB_STEP_SUMMARY
    echo "|-------|--------|-------|--------|" >> $GITHUB_STEP_SUMMARY

    for result in $CHART_RESULTS; do
      chart=$(echo "$result" | cut -d: -f1)
      status=$(echo "$result" | cut -d: -f2)
      pr=$(echo "$result" | cut -d: -f3)

      if [[ "$status" == "success" ]]; then
        echo "| $chart | integration/$chart | #$pr | :white_check_mark: |" >> $GITHUB_STEP_SUMMARY
      else
        echo "| $chart | integration/$chart | - | :x: $status |" >> $GITHUB_STEP_SUMMARY
      fi
    done
```

---

## File Structure

```
.github/
├── workflows/
│   └── filter-charts.yaml       # Main W2 workflow
└── scripts/
    └── attestation-lib.sh       # Shared functions (existing)
```

---

## Dependencies Graph

```
┌──────────────────────┐
│ Phase 2.0: Infra     │ ◄── BLOCKER: Must complete first
│ (ruleset setup)      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 2.1: Base      │
│ Workflow             │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌─────────────┐
│Phase 2.2│ │Phase 2.3    │
│Chart    │ │Source PR    │
│Detection│ │Discovery    │
└────┬────┘ └──────┬──────┘
     │             │
     └──────┬──────┘
            ▼
┌──────────────────────┐
│ Phase 2.4: Branch    │
│ Management           │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ Phase 2.5: PR        │
│ Creation             │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ Phase 2.6: W2        │
│ Attestation          │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌─────────────┐
│Phase 2.7│ │Phase 2.8    │
│Cleanup  │ │Error        │
│Policy   │ │Handling     │
└─────────┘ └─────────────┘
```

---

## Resolved Questions

| Question | Resolution |
|----------|------------|
| Token Permissions | Use `GITHUB_TOKEN` with GitHub Actions in ruleset bypass list |
| Merge Strategy | Updated `detect_changed_charts` to handle merge commits |
| Branch Conflicts | Use `--force-with-lease` with retry logic |
| Cleanup Policy | Delete after merge to main; weekly cleanup of stale branches |
| Multi-Chart Commits | Copy full attestation map to each per-chart PR |
| PR Direction | W2 pushes directly to branches; W4 creates PRs to main |

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Actions can't push to protected branches | High | Verify ruleset bypass before implementation |
| Source PR discovery fails | Medium | Warn but continue; attestation chain has gap |
| Branch push conflicts | Medium | Retry with exponential backoff |
| Workflow runs multiple times | Low | Concurrency group prevents parallel runs |
| Partial chart failures | Medium | Continue processing other charts; report failures |

---

## Success Criteria

- [ ] Workflow triggers on merge to `integration` with chart changes
- [ ] Correctly identifies all changed charts (squash and merge commits)
- [ ] Creates `integration/<chart>` branch per chart
- [ ] Opens/updates PR for each chart → main
- [ ] PR body contains source PR reference
- [ ] PR body contains attestation map from source
- [ ] W2 generates its own attestation
- [ ] Handles multiple charts in single merge
- [ ] Provides clear summary output
- [ ] Cleanup policy documented and ready for W6

---

## Architectural Note: Check Distribution Strategy

### W1 vs W5 Check Placement

The workflow design intentionally distributes checks between W1 and W5:

| Check Type | W1 (PR → Integration) | W5 (PR → Main) | Rationale |
|------------|:---------------------:|:--------------:|-----------|
| Commit validation | ✓ | | Catch early, applies to all |
| Helm lint (`ct lint`) | ✓ | | Fast, static analysis |
| ArtifactHub lint | ✓ | | Metadata validation |
| Changelog preview | ✓ | | Developer feedback |
| Attestation verification | | ✓ | Requires complete chain |
| **K8s compatibility matrix** | | ✓ | Per-chart, deploys to KinD |
| SemVer bump | | ✓ | Per-chart versioning |
| **Security scanning** | | ✓ | Per-chart, expensive |
| **SBOM generation** | | ✓ | Per-chart artifact |
| **License compliance** | | ✓ | Per-chart analysis |
| **Integration tests** | | ✓ | Chart-specific |

**Note**: Security-related checks (marked in bold) are **OUT OF SCOPE** for initial implementation but are annotated here for future context. They belong in W5 because:
1. They're expensive to run and benefit from isolated chart context
2. Security findings are more actionable per-chart
3. SBOM/attestations should be generated for the specific release candidate

### Future Security Checks (Out of Scope)

When implementing security checks, add to W5:
```yaml
# Example future additions to W5
- name: Security scan with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'config'
    scan-ref: 'charts/${{ matrix.chart }}'

- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    path: 'charts/${{ matrix.chart }}'

- name: Kubesec scan
  run: |
    helm template charts/${{ matrix.chart }} | kubesec scan -
```

---

## Architectural Note: Impact on W3/W4

The updated W2 design simplifies the flow compared to the original plan:

**Original Design**:
```
W2: integration → push to integration/<chart> → PR: integration → integration/<chart>
W3: Validate PR to integration/<chart>, auto-merge
W4: PR: integration/<chart> → main
```

**Updated Design**:
```
W2: integration → push to integration/<chart> → PR: integration/<chart> → main
```

**Implications**:
- **W3**: Original purpose (validate PRs to `integration/<chart>`) is no longer needed
  - New purpose: Could validate PRs from `integration/<chart>` to `main`
  - Or: W3 becomes optional/deleted
- **W4**: Original purpose (create PRs to main) is now handled by W2
  - New purpose: Could be merged into W2 or deleted
  - Or: Repurpose for PR formatting/updates

**Recommendation**: Review and update W3/W4 plans to align with this simplified flow. Consider:
1. Merging W3+W4 functionality into W5 (which validates PRs to main)
2. Or keeping W3 as a gate for PRs to main (replacing original W4 purpose)

---

## Cross-References

- **Upstream**: [W1 - Validate Contribution](../workflow-1/plan.md)
- **Downstream**: [W3 - Enforce Atomic PRs](../workflow-3/plan.md), [W4 - Format PRs](../workflow-4/plan.md)
- **Infrastructure**: [Rulesets Index](../rulesets-index.md), [GitHub App Plan](../infrastructure/github-app/plan.md)
- **Shared Code**: [attestation-lib.sh](../../../../.github/scripts/attestation-lib.sh)
