# Chart Release Workflow Test Plan

## Overview

This test plan validates all controls in the chart release workflow pipeline:

```
Developer PR → W1 (Validate) → Auto-Merge → integration
                                    ↓
                              W2 (Filter Charts)
                                    ↓
                              charts/<chart> branch + PR to main
                                    ↓
                              W5 (Validate Atomic Chart PR)
                                    ↓
                              Human Review → Merge to main
                                    ↓
                              Release (Tag + Package + Publish)
```

## Prerequisites

### Repository Configuration

| Requirement                     | Location                                               | Value                             |
| ------------------------------- | ------------------------------------------------------ | --------------------------------- |
| Auto-merge enabled              | Settings → General → Pull Requests                     | ✓ Allow auto-merge                |
| `AUTO_MERGE_ALLOWED_BRANCHES`   | Settings → Secrets and variables → Actions → Variables | `integration`                     |
| Branch protection (integration) | Settings → Branches                                    | Require PR, status checks         |
| Branch protection (main)        | Settings → Branches                                    | Require PR, status checks, review |
| CODEOWNERS                      | `.github/CODEOWNERS`                                   | Lists trusted contributors        |

### Test User Accounts

| Account        | Purpose              | Requirements                          |
| -------------- | -------------------- | ------------------------------------- |
| Trusted User   | Tests pass scenarios | Listed in CODEOWNERS, has signing key |
| Untrusted User | Tests fail scenarios | NOT in CODEOWNERS                     |

### Test Chart

Create a minimal test chart that can be safely modified:

```bash
# charts/test-workflow/Chart.yaml
apiVersion: v2
name: test-workflow
description: Test chart for workflow validation
type: application
version: 0.1.0
appVersion: "1.0.0"
```

---

## Test Scenarios

### Auto-Merge Workflow (`auto-merge.yaml`)

#### Controls

| ID    | Control                   | Code Location                          |
| ----- | ------------------------- | -------------------------------------- |
| AM-C1 | W1 must succeed           | `workflow_run.conclusion == 'success'` |
| AM-C2 | Must be PR event          | `workflow_run.event == 'pull_request'` |
| AM-C3 | PR targets allowed branch | `ALLOWED_BASE_BRANCHES` check          |
| AM-C4 | PR must be open           | `--state open` filter                  |
| AM-C5 | Author in CODEOWNERS      | `grep -q "@$PR_AUTHOR"`                |
| AM-C6 | All commits signed        | `.commit.verification.verified`        |

#### Test Matrix

| Test ID | Control | Scenario                      | Expected                              | Cleanup                 |
| ------- | ------- | ----------------------------- | ------------------------------------- | ----------------------- |
| AM-T1   | AM-C1   | W1 fails (invalid Chart.yaml) | Workflow doesn't trigger              | Delete branch           |
| AM-T2   | AM-C2   | W1 via workflow_dispatch      | Job skips (`event != 'pull_request'`) | N/A                     |
| AM-T3   | AM-C3   | PR targets `main`             | "branch_not_allowed" warning          | Delete branch, close PR |
| AM-T4   | AM-C4   | Close PR before workflow runs | "No open PR found"                    | Delete branch           |
| AM-T5   | AM-C5   | Author NOT in CODEOWNERS      | Trust check fails                     | Delete branch, close PR |
| AM-T6   | AM-C5   | Author IN CODEOWNERS          | Trust check passes                    | Continue to AM-T7       |
| AM-T7   | AM-C6   | Unsigned commits              | Verification fails                    | Delete branch, close PR |
| AM-T8   | AM-C6   | All commits signed            | Verification passes                   | Continue to merge       |
| AM-T9   | ALL     | Trusted + Verified            | Auto-merge ENABLED                    | Merge completes         |
| AM-T10  | ALL     | Untrusted + Verified          | Auto-merge NOT enabled                | Manual merge required   |

---

### W2: Create Atomic Chart PR (`create-atomic-chart-pr.yaml`)

#### Controls

| ID    | Control                          | Code Location                          |
| ----- | -------------------------------- | -------------------------------------- |
| W2-C1 | Trigger on integration push      | `push.branches: [integration]`         |
| W2-C2 | Only process charts/\*\* changes | `paths: ['charts/**']`                 |
| W2-C3 | Chart must have Chart.yaml       | `if [[ -f "charts/$dir/Chart.yaml" ]]` |
| W2-C4 | Concurrency control              | `group: w2-filter-charts`              |
| W2-C5 | Create charts/<chart> branch     | Branch creation logic                  |
| W2-C6 | Create PR to main                | `gh pr create --base main`             |

#### Test Matrix

| Test ID | Control | Scenario                               | Expected                        | Cleanup         |
| ------- | ------- | -------------------------------------- | ------------------------------- | --------------- |
| W2-T1   | W2-C1   | Push to integration (not charts/)      | Workflow doesn't run            | N/A             |
| W2-T2   | W2-C2   | Push to main (not integration)         | Workflow doesn't run            | N/A             |
| W2-T3   | W2-C3   | Change file in charts/ but not a chart | Skipped with notice             | N/A             |
| W2-T4   | W2-C4   | Concurrent pushes to integration       | Second waits or cancels         | N/A             |
| W2-T5   | W2-C5   | Single chart change                    | Creates `charts/<chart>` branch | Delete branch   |
| W2-T6   | W2-C5   | Multiple chart changes                 | Creates multiple branches       | Delete branches |
| W2-T7   | W2-C6   | PR already exists for branch           | Updates existing PR             | N/A             |

---

### W5: Validate Atomic Chart PR (`validate-atomic-chart-pr.yaml`)

#### Controls

| ID    | Control                   | Code Location                                       |
| ----- | ------------------------- | --------------------------------------------------- |
| W5-C1 | PR targets main           | `pull_request.branches: [main]`                     |
| W5-C2 | Dispatch actor validation | `ALLOWED_DISPATCH_ACTORS` check                     |
| W5-C3 | Source branch pattern     | `^charts/[a-z0-9-]+$` or `^integration/[a-z0-9-]+$` |
| W5-C4 | Chart must exist          | `has_charts == 'true'`                              |
| W5-C5 | ArtifactHub lint pass     | `ah lint --kind helm`                               |
| W5-C6 | Helm lint pass            | `ct lint`                                           |
| W5-C7 | K8s matrix tests pass     | `ct install` on v1.32, v1.33, v1.34                 |
| W5-C8 | Version bump logic        | Conventional commit parsing                         |
| W5-C9 | Cleanup on merge          | Delete source branch                                |

#### Test Matrix

| Test ID | Control | Scenario                           | Expected                          | Cleanup           |
| ------- | ------- | ---------------------------------- | --------------------------------- | ----------------- |
| W5-T1   | W5-C1   | PR targets integration             | Workflow doesn't run              | Close PR          |
| W5-T2   | W5-C2   | Dispatch from unauthorized actor   | "Unauthorized actor" error        | N/A               |
| W5-T3   | W5-C2   | Dispatch from github-actions[bot]  | Actor validated                   | Continue          |
| W5-T4   | W5-C3   | PR from `feature/` branch          | "does not match expected pattern" | Close PR          |
| W5-T5   | W5-C3   | PR from `charts/test` branch       | Branch validated                  | Continue          |
| W5-T6   | W5-C4   | PR with no chart changes           | Skip validation jobs              | Close PR          |
| W5-T7   | W5-C5   | Chart missing ArtifactHub metadata | Lint fails                        | Fix and retry     |
| W5-T8   | W5-C6   | Chart with Helm lint errors        | ct lint fails                     | Fix and retry     |
| W5-T9   | W5-C7   | Chart install fails on K8s 1.32    | Matrix job fails                  | Fix and retry     |
| W5-T10  | W5-C8   | `fix(chart):` commit               | Patch version bump                | Verify Chart.yaml |
| W5-T11  | W5-C8   | `feat(chart):` commit              | Minor version bump                | Verify Chart.yaml |
| W5-T12  | W5-C8   | `feat(chart)!:` commit             | Major version bump                | Verify Chart.yaml |
| W5-T13  | W5-C9   | Merge PR to main                   | Source branch deleted             | Verify deletion   |

---

### Release Workflow (`release-atomic-chart.yaml`)

#### Controls

| ID   | Control                      | Code Location                     |
| ---- | ---------------------------- | --------------------------------- |
| R-C1 | Trigger on main push         | `push.branches: [main]`           |
| R-C2 | Only process charts/\*\*     | `paths: ['charts/**']`            |
| R-C3 | Tag doesn't already exist    | `git rev-parse "$TAG_NAME"` check |
| R-C4 | Tag points to correct commit | Compare existing tag SHA          |
| R-C5 | Chart.yaml has version       | `VERSION=$(grep '^version:')`     |
| R-C6 | Package attestation          | `attest-build-provenance`         |
| R-C7 | GHCR push                    | `helm push` + Cosign sign         |
| R-C8 | GitHub Release created       | `gh release create`               |
| R-C9 | Release branch updated       | Push to `release` branch          |

#### Test Matrix

| Test ID | Control | Scenario                         | Expected                   | Cleanup            |
| ------- | ------- | -------------------------------- | -------------------------- | ------------------ |
| R-T1    | R-C1    | Push to integration (not main)   | Workflow doesn't run       | N/A                |
| R-T2    | R-C2    | Push to main (non-chart files)   | Workflow doesn't run       | N/A                |
| R-T3    | R-C3    | Tag already exists (same commit) | Skip with notice           | N/A                |
| R-T4    | R-C4    | Tag exists at different commit   | Error - version not bumped | Investigate        |
| R-T5    | R-C5    | Chart.yaml missing version       | Error extracting version   | Fix Chart.yaml     |
| R-T6    | R-C6    | Package created                  | Attestation generated      | Verify attestation |
| R-T7    | R-C7    | GHCR push                        | Chart in registry + signed | Verify with cosign |
| R-T8    | R-C8    | Release created                  | GitHub Release exists      | Verify assets      |
| R-T9    | R-C9    | Release branch updated           | index.yaml updated         | Verify content     |

---

### Attestation and Provenance (`release-atomic-chart.yaml`)

#### Controls

| ID    | Control                          | Code Location                                    |
| ----- | -------------------------------- | ------------------------------------------------ |
| AT-C1 | Package attestation generated    | `attest-build-provenance` action                 |
| AT-C2 | Attestation attached to artifact | `--subject-path` pointing to package             |
| AT-C3 | Cosign signature on OCI          | `cosign sign` with OIDC                          |
| AT-C4 | Attestation verifiable           | `gh attestation verify` succeeds                 |
| AT-C5 | Cosign signature verifiable      | `cosign verify` succeeds                         |
| AT-C6 | Attestation includes build info  | Contains workflow, commit SHA, repository        |

#### Test Matrix

| Test ID | Control | Scenario                            | Expected                                   | Verification                              |
| ------- | ------- | ----------------------------------- | ------------------------------------------ | ----------------------------------------- |
| AT-T1   | AT-C1   | Release workflow completes          | Attestation step succeeds                  | Check workflow logs                       |
| AT-T2   | AT-C2   | Package has attestation             | Attestation linked to .tgz artifact        | `gh attestation verify <package>`         |
| AT-T3   | AT-C3   | OCI image has Cosign signature      | Signature exists in registry               | `cosign tree ghcr.io/.../chart`           |
| AT-T4   | AT-C4   | Verify package attestation          | Returns valid attestation JSON             | `gh attestation verify --format json`     |
| AT-T5   | AT-C5   | Verify Cosign signature             | Verification succeeds with OIDC issuer     | `cosign verify --certificate-oidc-issuer` |
| AT-T6   | AT-C6   | Attestation contains build metadata | Includes repo, workflow, SHA, actor        | Parse attestation JSON                    |
| AT-T7   | AT-C4   | Tampered package fails verification | Attestation verify fails                   | Modify .tgz, run verify                   |
| AT-T8   | AT-C5   | Wrong issuer fails verification     | Cosign verify fails                        | Use wrong `--certificate-oidc-issuer`     |

#### Attestation Lineage Tests

These tests verify the complete chain of trust through the pipeline.

| Test ID | Scenario                           | Expected                                          | Verification                                         |
| ------- | ---------------------------------- | ------------------------------------------------- | ---------------------------------------------------- |
| AL-T1   | Trace release to merge commit      | Release attestation references merge commit SHA   | Compare attestation SHA with `git log main`          |
| AL-T2   | Trace merge to atomic PR           | Merge commit matches PR merge SHA                 | `gh pr view --json mergeCommit`                      |
| AL-T3   | Trace atomic PR to integration     | PR source branch created from integration commit  | `git log charts/<chart>..integration`                |
| AL-T4   | Trace integration to contributor   | Integration commit from merged contribution PR    | `git log integration --oneline`                      |
| AL-T5   | Full lineage audit                 | Can trace release back to original contributor PR | Chain: Release → main → PR → charts/* → integration  |
| AL-T6   | Attestation actor matches workflow | `github-actions[bot]` or workflow actor in claims | Parse attestation `predicate.invocation.actor`       |

#### Verification Commands Reference

```bash
# Verify GitHub attestation on package
gh attestation verify charts/test-workflow-0.2.0.tgz \
  --repo aRustyDev/helm-charts

# Verify with JSON output for detailed inspection
gh attestation verify charts/test-workflow-0.2.0.tgz \
  --repo aRustyDev/helm-charts \
  --format json | jq '.attestations[].verificationResult'

# Verify Cosign signature on OCI image
cosign verify ghcr.io/arustydev/helm-charts/test-workflow:0.2.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "github.com/aRustyDev/helm-charts"

# View Cosign signature tree
cosign tree ghcr.io/arustydev/helm-charts/test-workflow:0.2.0

# Extract attestation predicate for lineage verification
gh attestation verify charts/test-workflow-0.2.0.tgz \
  --repo aRustyDev/helm-charts \
  --format json | jq '.attestations[0].bundle.dsseEnvelope.payload' | \
  base64 -d | jq '.predicate'
```

---

## End-to-End Test Scenarios

### E2E-1: Happy Path (Full Pipeline)

**Objective**: Verify complete workflow from contribution to release.

**Steps**:

1. Create feature branch from `integration`
2. Add minor feature to `charts/test-workflow` (bump minor)
3. Commit with `feat(test-workflow): add test feature` (signed)
4. Push and create PR to `integration`
5. Verify W1 passes
6. Verify auto-merge enables (if trusted + verified)
7. PR merges to `integration`
8. Verify W2 creates `charts/test-workflow` branch + PR to `main`
9. Verify W5 runs validation + bumps version
10. Approve and merge PR to `main`
11. Verify Release workflow creates tag + publishes

**Expected**:

- Version bumped from 0.1.0 → 0.2.0
- Tag `test-workflow-v0.2.0` created
- Package in GHCR with Cosign signature
- GitHub Release created with attestation
- Attestation verifiable via `gh attestation verify`

**Post-Release Verification**:

```bash
# Verify GitHub attestation
gh attestation verify <release-asset>.tgz --repo aRustyDev/helm-charts

# Verify Cosign signature
cosign verify ghcr.io/arustydev/helm-charts/test-workflow:0.2.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

# Verify lineage (attestation contains correct commit SHA)
gh attestation verify <release-asset>.tgz --repo aRustyDev/helm-charts --format json | \
  jq '.attestations[0].bundle.dsseEnvelope.payload' | base64 -d | \
  jq '.predicate.invocation.configSource.digest.sha1'
```

**Cleanup**:

- Delete `charts/test-workflow` branch
- Keep tag and release (document in test log)

---

### E2E-2: Untrusted Contributor Path

**Objective**: Verify untrusted contributors require manual review at integration.

**Steps**:

1. Fork repo as untrusted user
2. Create same feature change
3. Create PR from fork to `integration`
4. Verify W1 passes
5. Verify auto-merge does NOT enable
6. Manual review and merge required
7. Verify rest of pipeline works normally

**Expected**:

- Auto-merge skipped
- Manual merge works
- W2 → W5 → Release functions normally

**Cleanup**:

- Close PR if not merged
- Delete any test branches

---

### E2E-3: Unsigned Commit Path

**Objective**: Verify unsigned commits require manual review.

**Steps**:

1. Create feature branch
2. Commit with `--no-gpg-sign`
3. Create PR to `integration`
4. Verify W1 passes
5. Verify auto-merge does NOT enable (unverified commits)
6. Manually merge
7. Verify rest of pipeline works

**Expected**:

- Auto-merge skipped due to unverified commits
- Pipeline continues after manual merge

**Cleanup**:

- Delete test branches

---

### E2E-4: Multiple Charts Changed

**Objective**: Verify multiple charts are processed independently.

**Steps**:

1. Change both `charts/test-workflow` and `charts/cloudflared`
2. Merge to `integration`
3. Verify W2 creates TWO branches and TWO PRs
4. Verify W5 runs on each independently
5. Merge both PRs
6. Verify Release creates separate tags/releases

**Expected**:

- Two independent pipelines
- Each chart versioned separately
- Each chart released separately

**Cleanup**:

- Delete test branches
- Revert test changes if needed

---

### E2E-5: Missing Attestation Map Blocks Release

**Objective**: Verify that releases cannot proceed without valid attestation maps.

**Scenario**: A PR is merged to main that bypasses W5 validation (e.g., manually created PR without going through W2).

**Steps**:

1. Create `charts/test-workflow` branch directly from main (bypassing integration/W2)
2. Make a chart change with version bump
3. Create PR to main from this branch
4. PR passes W5 lint tests but has no attestation map (wasn't created by W2)
5. Attempt to merge and observe release workflow

**Expected**:

- W5 validation jobs run and pass
- PR description has NO `<!-- W5_ATTESTATION_MAP -->` section
- Release workflow runs but logs warning about missing attestation data
- Release proceeds BUT tag annotation shows "No attestation data available"
- Future improvement: Block release if attestation map missing

**Current Behavior** (documents gap):

- Release currently proceeds without attestation map
- This is a known limitation documented in [Limitations](./docs/src/attestation/limitations.md)

**Cleanup**:

- Delete test branch
- Delete tag if created
- Delete release if created

---

### E2E-6: K8s Test Failure Blocks Release

**Objective**: Verify that a K8s test failure in W5 prevents the chart from being released.

**Steps**:

1. Create chart change that passes lint but fails install tests
   ```yaml
   # Example: Invalid resource that passes lint but fails install
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: {{ .Release.Name }}-test
   data:
     key: {{ required "value is required" .Values.nonexistent }}
   ```
2. Merge to integration (W1 passes, only lint checks)
3. W2 creates atomic PR to main
4. W5 runs: lint passes, K8s matrix tests FAIL
5. PR cannot merge (required checks fail)

**Expected**:

- W5 k8s-test jobs fail
- Required status checks block merge
- No release is created
- Attestation map shows test failures

**Verification**:

```bash
# Check PR status
gh pr view <pr-number> --json statusCheckRollup --jq '.statusCheckRollup[] | select(.conclusion != "SUCCESS")'

# Verify no tag was created
git tag -l "test-workflow-*" | tail -1
```

**Cleanup**:

- Fix the chart or close PR
- Delete test branches

---

### E2E-7: Lint Failure Blocks Release

**Objective**: Verify that lint failures in W5 prevent release.

**Steps**:

1. Create chart change with lint errors (but valid YAML)
   ```yaml
   # Missing required Chart.yaml fields
   apiVersion: v2
   name: test-workflow
   # Missing: version, description
   ```
2. Merge to integration
3. W2 creates atomic PR
4. W5 runs: ArtifactHub lint or ct lint FAIL
5. PR cannot merge

**Expected**:

- artifacthub-lint or helm-lint jobs fail
- Required status checks block merge
- No release is created

**Cleanup**:

- Fix chart or close PR
- Delete test branches

---

### E2E-8: Version Bump Failure Blocks Release

**Objective**: Verify that if version bump fails, the release has appropriate handling.

**Steps**:

1. Create chart change with invalid conventional commit
   ```
   "update something"  # Not conventional commit format
   ```
2. Merge to integration
3. W2 creates atomic PR
4. W5 runs: version-bump determines no bump needed (non-conventional)
5. If Chart.yaml version already exists as tag...

**Expected**:

- Version bump job logs "no version bump needed" or determines bump type
- If tag already exists at different commit → Release workflow errors
- Release workflow checks for tag collision before creating

**Verification**:

```bash
# Check if tag exists at different commit
TAG="test-workflow-v0.1.0"
EXISTING=$(git rev-list -n 1 "$TAG" 2>/dev/null || echo "none")
CURRENT="${{ github.sha }}"
if [[ "$EXISTING" != "none" && "$EXISTING" != "$CURRENT" ]]; then
  echo "ERROR: Tag exists at different commit!"
fi
```

**Cleanup**:

- Close PR if test-only
- Delete test branches

---

### E2E-9: Attestation Verification Failure Detection

**Objective**: Verify that consumers can detect attestation verification failures.

**Steps**:

1. Complete E2E-1 to create a valid release
2. Download the released package
3. Modify the package (simulate tampering)
4. Attempt to verify the tampered package

**Expected**:

- `gh attestation verify` fails on tampered package
- `cosign verify` fails on modified OCI image
- Error message clearly indicates verification failure

**Verification Commands**:

```bash
# Download valid package
gh release download test-workflow-v0.2.0 \
  --repo aRustyDev/helm-charts \
  --pattern "test-workflow-0.2.0.tgz"

# Verify original (should pass)
gh attestation verify test-workflow-0.2.0.tgz --repo aRustyDev/helm-charts
echo "Original verification: PASSED"

# Tamper with package
cp test-workflow-0.2.0.tgz test-workflow-0.2.0-tampered.tgz
echo "malicious" >> test-workflow-0.2.0-tampered.tgz

# Verify tampered (should fail)
if gh attestation verify test-workflow-0.2.0-tampered.tgz --repo aRustyDev/helm-charts 2>&1; then
  echo "ERROR: Tampered package verified (unexpected)"
  exit 1
else
  echo "Tampered verification: CORRECTLY FAILED"
fi
```

**Cleanup**:

- Remove downloaded test files

---

### E2E-10: Full Lineage Trace Verification

**Objective**: Verify complete lineage can be traced from release to original contributor.

**Steps**:

1. Complete E2E-1 with a trusted contributor
2. After release, perform full lineage trace
3. Verify each link in the chain

**Verification Script**:

```bash
#!/usr/bin/env bash
set -euo pipefail

CHART="test-workflow"
VERSION="0.2.0"
TAG="${CHART}-v${VERSION}"
REPO="aRustyDev/helm-charts"

echo "=== Full Lineage Trace for $TAG ==="

# Step 1: Get release commit
echo "1. Getting release commit..."
RELEASE_SHA=$(gh api "/repos/${REPO}/git/ref/tags/${TAG}" --jq '.object.sha')
echo "   Release SHA: $RELEASE_SHA"

# Step 2: Find merge PR
echo "2. Finding merge PR..."
MERGE_PR=$(gh api "/repos/${REPO}/commits/${RELEASE_SHA}/pulls" --jq '.[0].number')
echo "   Merge PR: #$MERGE_PR"

# Step 3: Get PR source branch
echo "3. Getting PR source branch..."
SOURCE_BRANCH=$(gh pr view "$MERGE_PR" --repo "$REPO" --json headRefName -q '.headRefName')
echo "   Source branch: $SOURCE_BRANCH"

# Step 4: Extract attestation map
echo "4. Extracting attestation map..."
ATTESTATION=$(gh pr view "$MERGE_PR" --repo "$REPO" --json body -q '.body' | grep -A5 "W5_ATTESTATION_MAP" || echo "Not found")
if [[ "$ATTESTATION" != "Not found" ]]; then
  echo "   Attestation map: PRESENT"
else
  echo "   Attestation map: MISSING (gap in lineage)"
fi

# Step 5: Verify Cosign signature
echo "5. Verifying Cosign signature..."
if cosign verify "ghcr.io/arustydev/helm-charts/${CHART}:${VERSION}" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp "github.com/aRustyDev/helm-charts" \
    --output text 2>/dev/null; then
  echo "   Cosign: VALID"
else
  echo "   Cosign: INVALID"
fi

echo ""
echo "=== Lineage Trace Complete ==="
```

**Expected**:

- All 5 steps complete successfully
- Each link in chain verifiable
- Attestation map present in merge PR
- Cosign signature valid

**Cleanup**:

- None (uses existing release from E2E-1)

---

## Cleanup Procedures

### After Each Test

1. **Delete test branches**:

   ```bash
   git push origin --delete <branch-name>
   ```

2. **Close test PRs**:

   ```bash
   gh pr close <PR-number> --delete-branch
   ```

3. **Revert test changes** (if on protected branch):
   ```bash
   git revert <commit-sha>
   ```

### Artifacts to Preserve in Version Control

| Artifact                             | Keep? | Reason                       |
| ------------------------------------ | ----- | ---------------------------- |
| Test chart (`charts/test-workflow/`) | NO    | Remove after testing         |
| Test results documentation           | YES   | Add to `docs/testing/`       |
| Workflow fixes discovered            | YES   | Commit improvements          |
| This test plan                       | YES   | Reference for future testing |

### Artifacts to Remove

| Artifact      | How to Remove                                   |
| ------------- | ----------------------------------------------- |
| Test branches | `git push origin --delete <branch>`             |
| Test PRs      | `gh pr close --delete-branch`                   |
| Test tags     | `git push origin --delete <tag>` (if test-only) |
| Test releases | Delete via GitHub UI (if test-only)             |
| Test chart    | `rm -rf charts/test-workflow && git commit`     |

---

## Test Execution Checklist

### Phase 1: Auto-Merge Tests

- [ ] AM-T1: W1 failure prevents trigger
- [ ] AM-T5: Untrusted author blocked
- [ ] AM-T7: Unsigned commits blocked
- [ ] AM-T9: Happy path works

### Phase 2: W2 Tests

- [ ] W2-T1: Path filtering works
- [ ] W2-T5: Single chart creates branch/PR
- [ ] W2-T6: Multiple charts handled

### Phase 3: W5 Tests

- [ ] W5-T4: Invalid branch pattern rejected
- [ ] W5-T5: Valid branch accepted
- [ ] W5-T10: Patch version bump
- [ ] W5-T11: Minor version bump
- [ ] W5-T13: Cleanup on merge

### Phase 4: Release Tests

- [ ] R-T3: Duplicate tag handling
- [ ] R-T7: GHCR push + signing
- [ ] R-T8: GitHub Release created

### Phase 5: Attestation Tests

- [ ] AT-T2: Package has attestation
- [ ] AT-T4: Verify package attestation
- [ ] AT-T5: Verify Cosign signature
- [ ] AT-T6: Attestation contains build metadata
- [ ] AT-T7: Tampered package fails verification
- [ ] AL-T1: Trace release to merge commit
- [ ] AL-T5: Full lineage audit

### Phase 6: End-to-End

- [ ] E2E-1: Happy path complete
- [ ] E2E-2: Untrusted user flow
- [ ] E2E-3: Unsigned commit flow
- [ ] E2E-4: Multiple charts
- [ ] E2E-5: Missing attestation map handling
- [ ] E2E-6: K8s test failure blocks release
- [ ] E2E-7: Lint failure blocks release
- [ ] E2E-8: Version bump failure handling
- [ ] E2E-9: Attestation verification failure detection
- [ ] E2E-10: Full lineage trace verification

---

## Notes

### Test Order Dependencies

Some tests must run in sequence:

1. AM tests should complete before E2E tests
2. W2 tests require integration branch access
3. W5 tests require W2 to create the PR first
4. Release tests require W5 to complete

### Test Isolation

To avoid interference:

- Use unique chart names for parallel tests
- Use unique branch names with test ID prefix
- Clean up immediately after each test

### Failure Investigation

When a test fails:

1. Check workflow run logs
2. Check branch protection rules
3. Check repository variables
4. Check CODEOWNERS file
5. Document in test results
