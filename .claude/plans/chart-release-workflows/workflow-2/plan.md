# Workflow 2: Filter Charts - Phase Plan

## Overview
**Trigger**: `push` → `integration` branch (with changes to `charts/**`)
**Purpose**: Detect changed charts and create per-chart branches for atomic processing

---

## Prerequisites

### Shared Components Required (Build First)
- [ ] `detect_changed_charts` shell function
- [ ] `extract_attestation_map` shell function

### Infrastructure Required
- [ ] `integration` branch created
- [ ] `integration-chart-protection` ruleset configured
- [ ] GitHub App token or elevated permissions for branch creation

### Upstream Dependencies
- [ ] Workflow 1 must be functional (provides attestation map)

---

## Implementation Phases

### Phase 2.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: Integration branch exists

**Tasks**:
1. Create `.github/workflows/filter-charts.yaml`
2. Configure trigger for `push` → `integration` with path filter `charts/**`
3. Set up permissions (contents: write, pull-requests: write)
4. Configure checkout with full history

**Deliverable**: Workflow triggers on merge to integration

---

### Phase 2.2: Chart Detection Logic
**Effort**: Low
**Dependencies**: Phase 2.1

**Tasks**:
1. Implement `detect_changed_charts` function
2. Parse git diff to identify changed chart directories
3. Output list of chart names
4. Handle edge case: non-chart files in charts/ directory

**Code**:
```bash
detect_changed_charts() {
  git diff --name-only HEAD~1 HEAD | \
    grep '^charts/' | \
    cut -d'/' -f2 | \
    sort -u
}
```

**Questions**:
- [ ] How to handle changes to shared templates (if any)?
- [ ] What if only Chart.lock changes (dependency update)?

---

### Phase 2.3: Source PR Discovery
**Effort**: Medium
**Dependencies**: Phase 2.1

**Tasks**:
1. Find the PR that was merged (created this push)
2. Extract PR body containing attestation map
3. Store for use in downstream PRs

**Questions**:
- [ ] How to reliably find the merged PR? By SHA search?
- [ ] What if merge was via squash vs merge commit?

**Gaps**:
- Need to handle different merge strategies (squash, merge, rebase)

---

### Phase 2.4: Per-Chart Branch Management
**Effort**: High
**Dependencies**: Phase 2.2, GitHub App token

**Tasks**:
1. For each detected chart:
   - Check if `integration/<chart>` branch exists
   - Create branch if not, or fetch if exists
   - Checkout only the chart's files from merge commit
   - Commit changes with conventional commit format
   - Push branch

**Code**:
```bash
for chart in $(detect_changed_charts); do
  # Create or update branch
  git checkout integration/$chart 2>/dev/null || \
    git checkout -b integration/$chart integration

  # Checkout only this chart's files
  git checkout $MERGE_SHA -- charts/$chart/

  # Commit
  git add charts/$chart/
  git commit -m "chore($chart): sync from integration"

  # Push
  git push origin integration/$chart --force-with-lease
done
```

**Questions**:
- [ ] Use `--force-with-lease` or regular push?
- [ ] How to handle push conflicts?
- [ ] What permissions are needed for branch creation?

**Gaps**:
- Need elevated token to push to branches
- Branch protection may block push

---

### Phase 2.5: PR Creation/Update
**Effort**: Medium
**Dependencies**: Phase 2.4, `extract_attestation_map`

**Tasks**:
1. For each chart, check if PR already exists
2. If exists: PR auto-updates with new commits
3. If not: Create new PR with:
   - Title: `chore(<chart>): atomic release preparation`
   - Body: Source PR reference, attestation map
4. Use `peter-evans/create-pull-request@v6` or `gh pr create`

**Questions**:
- [ ] Use action or gh CLI for PR creation?
- [ ] How to update existing PR body with new attestation map?

---

### Phase 2.6: Error Handling & Cleanup
**Effort**: Low
**Dependencies**: All previous phases

**Tasks**:
1. Handle partial failures (some charts succeed, others fail)
2. Log detailed errors for debugging
3. Consider cleanup of stale `integration/<chart>` branches

**Questions**:
- [ ] Should we delete stale `integration/<chart>` branches?
- [ ] How long to keep branches after merge?

---

## File Structure

```
.github/
├── workflows/
│   └── filter-charts.yaml       # Main workflow
└── scripts/
    └── attestation-lib.sh       # Shared functions
```

---

## Dependencies Graph

```
┌──────────────────────┐
│ Workflow 1 Complete  │
│ (PR merged to integ) │
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
│ Phase 2.6: Error     │
│ Handling             │
└──────────────────────┘
```

---

## Open Questions

1. **Token Permissions**: Can `GITHUB_TOKEN` create branches, or do we need GitHub App?
2. **Merge Strategy**: How to handle squash merge vs merge commit for PR discovery?
3. **Branch Conflicts**: What if `integration/<chart>` has unpushed changes?
4. **Cleanup Policy**: When to delete `integration/<chart>` branches?
5. **Multi-Chart Commits**: How to handle a commit touching Chart.yaml in multiple charts?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Token can't create branches | High | Use GitHub App token |
| PR discovery fails | Medium | Fallback to commit message parsing |
| Branch push conflicts | Medium | Use --force-with-lease, retry |
| Workflow runs multiple times for same merge | Low | Idempotent operations |

---

## Success Criteria

- [ ] Workflow triggers on merge to `integration`
- [ ] Correctly identifies all changed charts
- [ ] Creates `integration/<chart>` branch per chart
- [ ] Opens PR for each chart branch
- [ ] PR body contains source PR reference
- [ ] PR body contains attestation map from source
- [ ] Handles multiple charts in single merge
