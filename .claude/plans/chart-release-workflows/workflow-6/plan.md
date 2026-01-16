# Workflow 6: Atomic Chart Tagging - Phase Plan

## Overview
**Trigger**: `push` → `main` branch (with changes to `charts/**`)
**Purpose**: Create immutable annotated tags and open PR to release branch

---

## Relevant Skills

Load these skills before planning, research, or implementation:

| Skill | Path | Relevance |
|-------|------|-----------|
| **CI/CD GitHub Actions** | `~/.claude/skills/cicd-github-actions-dev/SKILL.md` | Tag creation, gh CLI patterns, PR creation |
| **Helm Chart Development** | `~/.claude/skills/k8s-helm-charts-dev/SKILL.md` | Chart versioning, semantic version extraction |
| **GitHub App Development** | `~/.claude/skills/github-app-dev/SKILL.md` | If elevated permissions needed for tag creation |

**How to load**: Read the SKILL.md files at the start of implementation to access patterns and best practices.

---

## Prerequisites

### Shared Components Required (Build First)
- [ ] `detect_changed_charts` shell function
- [ ] `extract_attestation_map` shell function

### Infrastructure Required
- [ ] `release-tag-protection` ruleset configured (blocks manual tag creation)
- [ ] GitHub App token with tag creation permissions
- [ ] `release` branch created

### Upstream Dependencies
- [ ] Workflow 5 must have merged the PR (triggers this workflow)

---

## Implementation Phases

### Phase 6.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: None

**Tasks**:
1. Create `.github/workflows/atomic-chart-tagging.yaml`
2. Configure trigger for `push` → `main` with path filter `charts/**`
3. Set up permissions (contents: write, pull-requests: write)
4. Use GitHub App token for tag creation

**Deliverable**: Workflow triggers on merge to main with chart changes

---

### Phase 6.2: Chart Detection
**Effort**: Low
**Dependencies**: Phase 6.1, `detect_changed_charts`

**Tasks**:
1. Detect which charts changed in this merge
2. For each chart, get current version from Chart.yaml
3. Store list for iteration

---

### Phase 6.3: Source PR Discovery
**Effort**: Medium
**Dependencies**: Phase 6.1, `extract_attestation_map`

**Tasks**:
1. Find the PR that was merged (created this push)
2. Extract attestation map from PR body
3. Store for tag annotation

**Code**:
```bash
PR_DATA=$(gh pr list \
  --state merged \
  --search "${{ github.sha }}" \
  --json number,body \
  --limit 1 \
  -q '.[0]')

PR_NUMBER=$(echo "$PR_DATA" | jq -r '.number')
ATTESTATION_MAP=$(extract_attestation_map "$PR_NUMBER")
```

---

### Phase 6.4: Changelog Extraction
**Effort**: Medium
**Dependencies**: Phase 6.2

**Tasks**:
1. For each chart, check for CHANGELOG.md
2. Extract entries for the current version
3. Format for tag annotation

**Questions**:
- [ ] Is there a CHANGELOG.md per chart or combined?
- [ ] What format is the changelog in?
- [ ] Generate changelog dynamically or expect it to exist?

---

### Phase 6.5: Tag Creation
**Effort**: High
**Dependencies**: Phase 6.3, Phase 6.4, GitHub App token

**Tasks**:
1. For each chart:
   - Construct tag name: `<chart>-v<version>`
   - Check if tag already exists (idempotent)
   - Create annotated tag with:
     - Release header
     - Attestation lineage
     - Changelog
     - Source PR reference
   - Push tag

**Tag Annotation Format**:
```
Release: <chart> v<version>

Attestation Lineage:
- lint-test-v1.32.11: <attestation-id>
- lint-test-v1.33.7: <attestation-id>
- workflow-5-verify: <attestation-id>
- workflow-5-semver: <attestation-id>
- workflow-5-overall: <attestation-id>

Changelog:
<changelog content>

Source PR: #<number>
Commit: <sha>
```

**Code**:
```bash
git tag -a "$TAG_NAME" -m "$(cat <<EOF
Release: $CHART v$VERSION

Attestation Lineage:
$(echo "$ATTESTATION_MAP" | jq -r 'to_entries | .[] | "- \(.key): \(.value)"')

Changelog:
$CHANGELOG

Source PR: #$PR_NUMBER
Commit: ${{ github.sha }}
EOF
)"

git push origin "$TAG_NAME"
```

**Questions**:
- [ ] What token is needed to push tags with protection?
- [ ] How to handle tag already exists?

**Gaps**:
- Need GitHub App token to bypass tag protection
- May need to configure bypass in ruleset

---

### Phase 6.6: PR to Release Branch
**Effort**: Medium
**Dependencies**: Phase 6.5

**Tasks**:
1. Check if PR `main → release` already exists
2. If not, create PR with:
   - Title: `release: <tag-names>`
   - Body: Tags created, charts released, attestation map
3. If exists, PR auto-updates with new commits

**Questions**:
- [ ] One PR per tag or batch multiple tags?
- [ ] Should we wait for all tags before creating PR?

---

### Phase 6.7: Branch Cleanup (Optional)
**Effort**: Low
**Dependencies**: Phase 6.5

**Tasks**:
1. Delete `integration/<chart>` branches after successful tagging
2. Only if all checks passed

**Questions**:
- [ ] When to delete integration branches?
- [ ] Who triggers cleanup - this workflow or separate?

---

## File Structure

```
.github/
├── workflows/
│   └── atomic-chart-tagging.yaml    # Main workflow
└── scripts/
    └── attestation-lib.sh           # Shared functions
```

---

## Dependencies Graph

```
┌──────────────────────┐
│ Workflow 5 merges    │
│ PR to main           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 6.1: Base      │
│ Workflow             │
└──────────┬───────────┘
           │
     ┌─────┼─────┐
     ▼     ▼     ▼
┌──────┐ ┌──────┐ ┌──────────┐
│6.2   │ │6.3   │ │6.4       │
│Chart │ │Source│ │Changelog │
│Detect│ │PR    │ │Extract   │
└──┬───┘ └──┬───┘ └────┬─────┘
   │        │          │
   └────────┼──────────┘
            ▼
┌──────────────────────┐
│ Phase 6.5: Tag       │
│ Creation             │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 6.6: PR to     │
│ Release              │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 6.7: Branch    │
│ Cleanup (Optional)   │
└──────────────────────┘
```

---

## Open Questions

1. **Tag Push Permissions**: How to push tags with tag protection enabled?
2. **Changelog Format**: Where does changelog content come from?
3. **Multiple Charts**: How to handle multiple charts in one merge?
4. **Existing Tags**: Skip or fail if tag exists?
5. **PR Batching**: One release PR per tag or batch?
6. **Branch Cleanup**: When and how to delete integration branches?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Can't push tags due to protection | High | Configure ruleset bypass for Actions |
| Tag already exists | Low | Skip with warning (idempotent) |
| Source PR not found | Medium | Fallback to commit info |
| Changelog missing | Low | Use commit messages |
| Multiple workflow runs | Low | Check tag existence first |

---

## Success Criteria

- [ ] Workflow triggers on merge to main with chart changes
- [ ] Creates annotated tag per chart: `<chart>-v<version>`
- [ ] Tag annotation contains attestation lineage
- [ ] Tag annotation contains changelog
- [ ] Pushes tags successfully
- [ ] Creates PR to release branch
- [ ] Handles existing tags gracefully
- [ ] Workflow completes in < 5 minutes
