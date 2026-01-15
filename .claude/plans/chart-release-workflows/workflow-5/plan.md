# Workflow 5: Validate & SemVer Bump - Phase Plan

## Overview
**Trigger**: `pull_request` → `main` branch (with changes to `charts/**`)
**Purpose**: Verify attestation lineage, bump version, generate overall attestation

---

## Prerequisites

### Shared Components Required (Build First)
- [ ] `extract_attestation_map` shell function
- [ ] `verify_attestation_chain` shell function
- [ ] `update_attestation_map` shell function

### Infrastructure Required
- [ ] `main-protection` ruleset configured
- [ ] release-please configuration files
- [ ] GitHub App token for pushing version bump

### Upstream Dependencies
- [ ] Workflow 4 creates the PRs this workflow validates

---

## Implementation Phases

### Phase 5.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: None

**Tasks**:
1. Create `.github/workflows/validate-semver-bump.yaml`
2. Configure trigger for `pull_request` → `main` with path filter `charts/**`
3. Set up permissions (contents: write, pull-requests: write, id-token: write, attestations: write)

**Deliverable**: Workflow triggers on PR to main with chart changes

---

### Phase 5.2: Attestation Map Extraction
**Effort**: Low
**Dependencies**: Phase 5.1, `extract_attestation_map`

**Tasks**:
1. Get PR body using `gh pr view`
2. Extract attestation map from HTML comment
3. Validate JSON format
4. Fail if no attestation map found

**Code**:
```bash
PR_BODY=$(gh pr view $PR_NUMBER --json body -q '.body')
ATTESTATION_MAP=$(echo "$PR_BODY" | \
  grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | \
  tr -d '\0')

if [ -z "$ATTESTATION_MAP" ]; then
  echo "::error::No attestation map found"
  exit 1
fi
```

---

### Phase 5.3: Attestation Chain Verification
**Effort**: High
**Dependencies**: Phase 5.2, `verify_attestation_chain`

**Tasks**:
1. Iterate over each attestation ID in map
2. Verify each using `gh attestation verify`
3. Track failures
4. Generate attestation for verification result

**Questions**:
- [ ] What exactly does `gh attestation verify` verify?
- [ ] How to handle attestations for different subject types?
- [ ] What if attestation was deleted?

**Gaps**:
- Need to understand `gh attestation verify` API fully
- May need to verify against specific artifact digests

---

### Phase 5.4: Chart Detection
**Effort**: Low
**Dependencies**: Phase 5.1

**Tasks**:
1. Determine which chart is being released
2. Get current version from Chart.yaml
3. Handle edge case of multiple charts (should not happen with atomic flow)

**Code**:
```bash
CHART=$(git diff --name-only origin/main...HEAD | \
  grep '^charts/' | \
  cut -d'/' -f2 | \
  sort -u | \
  head -1)

CURRENT_VERSION=$(grep '^version:' "charts/$CHART/Chart.yaml" | awk '{print $2}')
```

---

### Phase 5.5: Version Bump Determination
**Effort**: Medium
**Dependencies**: Phase 5.4, release-please config

**Tasks**:
1. Run release-please in dry-run mode
2. Parse output for new version
3. Fallback: calculate patch bump if release-please fails

**Options**:
```yaml
# Option A: release-please action
- uses: googleapis/release-please-action@v4
  with:
    dry-run: true
    config-file: release-please-config.json

# Option B: release-please CLI
- run: |
    npx release-please release-pr \
      --dry-run \
      --repo-url=${{ github.repository }}
```

**Questions**:
- [ ] Can release-please run on a non-default branch?
- [ ] How to get just the version bump without creating PR?
- [ ] What if release-please determines no bump needed?

**Gaps**:
- release-please behavior with atomic chart PRs unclear
- May need custom version calculation logic

---

### Phase 5.6: Apply Version Bump
**Effort**: Medium
**Dependencies**: Phase 5.5, GitHub App token

**Tasks**:
1. Update Chart.yaml with new version
2. Commit the change to PR branch
3. Push commit

**Code**:
```bash
# Update version
sed -i "s/^version: .*/version: $NEW_VERSION/" "charts/$CHART/Chart.yaml"

# Commit
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"
git add "charts/$CHART/Chart.yaml"
git commit -m "chore($CHART): bump version to $NEW_VERSION"

# Push
git push origin HEAD:${{ github.head_ref }}
```

**Questions**:
- [ ] Can we push to PR branch with GITHUB_TOKEN?
- [ ] What if PR branch is protected?
- [ ] How to handle concurrent workflow runs?

**Gaps**:
- May need elevated token to push
- Need to handle push conflicts

---

### Phase 5.7: Generate Attestations
**Effort**: High
**Dependencies**: Phase 5.3, Phase 5.6

**Tasks**:
1. Attest the verification result
2. Attest the version bump (Chart.yaml)
3. Generate overall attestation (manifest file)
4. Update PR description with new attestation IDs

**Attestation Manifest**:
```json
{
  "version": "1.0",
  "chart": "<chart-name>",
  "new_version": "<version>",
  "pr": <pr-number>,
  "commit": "<sha>",
  "lineage": { <upstream attestations> },
  "this_stage": {
    "verification": "<attestation-id>",
    "semver-bump": "<attestation-id>"
  }
}
```

---

### Phase 5.8: Status Check Registration
**Effort**: Low
**Dependencies**: Phase 5.7

**Tasks**:
1. Ensure workflow reports status correctly
2. Register as required check in ruleset
3. Block merge until all checks pass

---

## File Structure

```
.github/
├── workflows/
│   └── validate-semver-bump.yaml    # Main workflow
├── scripts/
│   └── attestation-lib.sh           # Shared functions
├── release-please-config.json       # release-please config
└── .release-please-manifest.json    # release-please manifest
```

---

## Dependencies Graph

```
┌──────────────────────┐
│ Workflow 4 creates   │
│ PR to main           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 5.1: Base      │
│ Workflow             │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 5.2: Extract   │
│ Attestation Map      │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌─────────────┐
│Phase 5.3│ │Phase 5.4    │
│Verify   │ │Chart        │
│Chain    │ │Detection    │
└────┬────┘ └──────┬──────┘
     │             │
     └──────┬──────┘
            ▼
┌──────────────────────┐
│ Phase 5.5: Version   │
│ Bump Determination   │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ Phase 5.6: Apply     │
│ Version Bump         │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ Phase 5.7: Generate  │
│ Attestations         │
└──────────────────────┘
```

---

## Open Questions

1. **Attestation Verification**: What does `gh attestation verify` actually check?
2. **Token Permissions**: Can GITHUB_TOKEN push to PR branches?
3. **release-please Integration**: How to get version without creating PR?
4. **Concurrent Runs**: How to handle multiple workflow runs on same PR?
5. **Failed Verification**: What happens if attestation verification fails?
6. **No Bump Needed**: What if release-please determines no version change?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Attestation verification fails unexpectedly | High | Clear error messages, docs |
| Can't push version bump | High | Use GitHub App token |
| release-please doesn't work in this context | High | Fallback to manual calculation |
| Concurrent runs cause conflicts | Medium | Use concurrency group |
| Attestation storage size limit | Low | Monitor PR description size |

---

## Success Criteria

- [ ] Workflow triggers on PR to main with chart changes
- [ ] Extracts and parses attestation map correctly
- [ ] Verifies all attestations in chain
- [ ] Determines correct version bump
- [ ] Commits version bump to PR branch
- [ ] Generates attestations for verification and bump
- [ ] Updates PR description with new attestation IDs
- [ ] Workflow completes in < 5 minutes
