# Workflow 3: Enforce Atomic Chart PRs - Phase Plan

> [!WARNING]
> **OBSOLETE**: This workflow is no longer needed in the simplified flow.
>
> **Original Purpose**: Validate and auto-merge PRs from `integration` branch to `integration/<chart>` branches.
>
> **Why Obsolete**: W2 was simplified to push directly to `integration/<chart>` and create PRs to `main`, eliminating the intermediate step that W3 was designed to handle. The `integration` branch (singular) is no longer used.
>
> **Replaced By**: W2 now handles the full flow (lint-test → push to integration/<chart> → create PR to main).
>
> **Remaining Value**: The source branch validation pattern may be useful reference for W5's validation of `integration/<chart>` → `main` PRs.

---

## Overview
**Trigger**: `pull_request` → `integration/*` branches
**Purpose**: Validate source branch is `integration` and auto-merge valid PRs

---

## Relevant Skills

Load these skills before planning, research, or implementation:

| Skill | Path | Relevance |
|-------|------|-----------|
| **CI/CD GitHub Actions** | `~/.claude/skills/cicd-github-actions-dev/SKILL.md` | PR validation, auto-merge patterns, conditional workflows |
| **GitHub App Development** | `~/.claude/skills/github-app-dev/SKILL.md` | If elevated permissions needed for auto-merge |

**How to load**: Read the SKILL.md files at the start of implementation to access patterns and best practices.

---

## Prerequisites

### Shared Components Required (Build First)
- [ ] `validate_source_branch` shell function

### Infrastructure Required
- [ ] `integration-chart-protection` ruleset configured
- [ ] Auto-merge enabled in repository settings

### Upstream Dependencies
- [ ] Workflow 2 creates the PRs this workflow validates

---

## Implementation Phases

### Phase 3.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: None

**Tasks**:
1. Create `.github/workflows/enforce-atomic-prs.yaml`
2. Configure trigger for `pull_request` → `integration/*`
3. Set up permissions (pull-requests: write, contents: write)

**Deliverable**: Workflow triggers on PR to any `integration/<chart>` branch

---

### Phase 3.2: Source Branch Validation
**Effort**: Low
**Dependencies**: Phase 3.1

**Tasks**:
1. Implement `validate_source_branch` function
2. Check `github.head_ref` equals `integration`
3. If invalid: set output flag for later steps

**Code**:
```bash
validate_source_branch() {
  local source="$1"
  local expected="$2"

  if [[ "$source" != "$expected" ]]; then
    echo "::error::Invalid source branch: $source (expected: $expected)"
    return 1
  fi
  return 0
}
```

**Questions**:
- [ ] Should we allow any exception to the source branch rule?
- [ ] How to handle PRs created manually (not by Workflow 2)?

---

### Phase 3.3: Invalid PR Handling
**Effort**: Low
**Dependencies**: Phase 3.2

**Tasks**:
1. If source branch is invalid:
   - Add explanatory comment to PR
   - Close the PR
   - Exit workflow with failure

**Code**:
```yaml
- name: Close invalid PR
  if: steps.validate.outputs.valid == 'false'
  run: |
    gh pr close ${{ github.event.pull_request.number }} \
      --comment "This PR was auto-closed because only 'integration' branch can merge to integration/<chart> branches."
```

---

### Phase 3.4: Attestation Map Verification
**Effort**: Medium
**Dependencies**: Phase 3.2, `extract_attestation_map`

**Tasks**:
1. Extract attestation map from PR body
2. Verify map exists (warning if missing)
3. Optionally verify attestation IDs are valid

**Questions**:
- [ ] Should missing attestation map block merge?
- [ ] Should we verify attestations here or defer to Workflow 5?

**Gaps**:
- Need to decide verification depth at this stage

---

### Phase 3.5: Auto-Merge Implementation
**Effort**: Medium
**Dependencies**: Phase 3.2, Phase 3.4

**Tasks**:
1. If source branch is valid:
   - Enable auto-merge on the PR
   - Use squash merge strategy
2. Consider using `pascalgn/automerge-action` or `gh pr merge --auto`

**Options**:
```yaml
# Option A: gh CLI
- name: Auto-merge
  run: |
    gh pr merge ${{ github.event.pull_request.number }} \
      --auto --squash

# Option B: automerge-action
- uses: pascalgn/automerge-action@v0.16.3
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    MERGE_METHOD: squash
```

**Questions**:
- [ ] Which auto-merge approach is more reliable?
- [ ] Should merge be immediate or wait for status checks?
- [ ] What merge commit message format?

**Gaps**:
- Need to ensure auto-merge works with branch protection

---

### Phase 3.6: Status Check Integration
**Effort**: Low
**Dependencies**: Phase 3.5

**Tasks**:
1. Register this workflow as a status check
2. Configure ruleset to require this check
3. Ensure auto-merge waits for check completion

---

## File Structure

```
.github/
├── workflows/
│   └── enforce-atomic-prs.yaml    # Main workflow
└── scripts/
    └── attestation-lib.sh         # Shared functions
```

---

## Dependencies Graph

```
┌──────────────────────┐
│ Workflow 2 creates   │
│ PR to integration/*  │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 3.1: Base      │
│ Workflow             │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 3.2: Source    │
│ Branch Validation    │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌─────────────┐
│Phase 3.3│ │Phase 3.4    │
│Invalid  │ │Attestation  │
│PR Close │ │Verification │
└─────────┘ └──────┬──────┘
                   │
                   ▼
         ┌──────────────────┐
         │ Phase 3.5:       │
         │ Auto-Merge       │
         └──────────────────┘
```

---

## Open Questions

1. **Auto-Merge Timing**: Should merge happen immediately or after checks?
2. **Attestation Verification Depth**: Verify IDs here or defer to W5?
3. **Manual PRs**: How to handle PRs created manually to `integration/<chart>`?
4. **Merge Commit Format**: What should the squash commit message be?
5. **Failure Recovery**: If auto-merge fails, how to retry?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Auto-merge fails silently | High | Add retry logic, notifications |
| Manual PRs bypass workflow | Medium | Ruleset + workflow validation |
| Branch protection blocks merge | High | Configure bypass for Actions |
| Race condition with W2 | Low | Idempotent operations |

---

## Success Criteria

- [ ] Workflow triggers on PR to `integration/*`
- [ ] Invalid source branch PRs are closed with explanation
- [ ] Valid source branch PRs are auto-merged
- [ ] Merge uses squash strategy
- [ ] Attestation map presence is verified
- [ ] Workflow completes in < 2 minutes
