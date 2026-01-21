# Phase 6: End-to-End Test Scenarios

## Overview

Full pipeline tests that exercise the complete workflow from contribution to release.

| Attribute | Value |
|-----------|-------|
| **Dependencies** | Phases 1-5 (all component tests) |
| **Time Estimate** | ~30-60 minutes per E2E scenario |
| **Infrastructure** | Full GitHub repository with all workflows |

> **📚 Skill References**:
> - `~/.claude/skills/method-verification-dev` - Verify each step with fresh output
> - `~/.claude/skills/cicd-github-actions-ops` - Debug failures systematically

---

## E2E Test Matrix

| Test ID | Scenario | Priority | Status |
|---------|----------|----------|--------|
| E2E-1 | Happy path (full pipeline) | P0 | [x] **IMPLEMENTED** |
| E2E-2 | Untrusted contributor path | P1 | [x] **IMPLEMENTED** |
| E2E-3 | Unsigned commit path | P1 | [x] **IMPLEMENTED** |
| E2E-4 | Multi-file-type atomization | P1 | [x] **IMPLEMENTED** |
| E2E-5 | Dependabot auto-merge flow | P1 | [ ] |
| E2E-6 | DLQ handling | P2 | [x] **IMPLEMENTED** |
| E2E-7 | Multiple charts changed | P1 | [x] **IMPLEMENTED** |
| E2E-8 | Missing attestation map | P2 | [ ] |
| E2E-9 | K8s test failure blocks release | P1 | [x] **IMPLEMENTED** |
| E2E-10 | Lint failure blocks release | P1 | [x] **IMPLEMENTED** |
| E2E-11 | Version bump failure | P2 | [ ] |
| E2E-12 | Attestation verification failure | P1 | [x] **IMPLEMENTED** |
| E2E-13 | Full lineage trace | P1 | [x] **IMPLEMENTED** |
| E2E-14 | Failure recovery (W2 cleanup) | P2 | [x] **IMPLEMENTED** |
| E2E-15 | Fork PR security flow | P1 | [x] **IMPLEMENTED** |

---

## E2E-1: Happy Path (Full Pipeline with Merge Queue)

**Objective**: Verify complete workflow from contribution to release via merge queue.

**Steps**:

1. Create feature branch from `integration`
2. Add minor feature to `charts/test-workflow` (bump minor)
3. Commit with `feat(test-workflow): add test feature` (signed)
4. Push and create PR to `integration`
5. Verify W1 passes (lint, artifacthub, commit, cherry-pick preview)
6. Verify signature check passes (FIRST)
7. Verify CODEOWNERS trust check passes (SECOND)
8. Verify auto-merge enables
9. **PR enters merge queue**
10. **Merge queue processes and merges PR**
11. Verify W2 atomizes:
    - Creates `chart/test-workflow` branch
    - Creates PR to main with related links
    - Triggers W5 via repository_dispatch
    - Resets integration to main
12. Verify W5 validates and version bumps
13. Approve and merge PR to `main`
14. Verify Release workflow:
    - **Creates tag FIRST** (`test-workflow-v0.2.0`)
    - Packages chart at tag
    - Generates attestation
    - Creates GitHub Release
    - Pushes to GHCR with Cosign signature

**Expected**:

- PR queued and merged via merge queue
- Version bumped from 0.1.0 → 0.2.0
- Tag `test-workflow-v0.2.0` created BEFORE packaging
- Package in GHCR with Cosign signature
- GitHub Release created with attestation
- Attestation verifiable via `gh attestation verify`
- Integration branch reset to main

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

# Verify integration was reset
git fetch origin
git log origin/integration --oneline -1
git log origin/main --oneline -1
# Should be the same commit
```

**Cleanup**:

- Delete `chart/test-workflow` branch (should be auto-deleted by W5)
- Keep tag and release (document in test log)

---

## E2E-2: Untrusted Contributor Path

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

## E2E-3: Unsigned Commit Path

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

## E2E-4: Multi-File-Type Atomization

**Objective**: Verify atomization correctly handles multiple file types in single PR.

**Steps**:

1. Create feature branch from `integration`
2. Make changes to:
   - `charts/cloudflared/values.yaml` (chart change)
   - `docs/src/cloudflared/configuration.md` (docs change)
   - `.github/workflows/release.yaml` (CI change)
3. Commit with `feat(cloudflared): add feature with docs and CI updates` (signed)
4. Create PR to `integration`
5. Verify W1 passes (including cherry-pick preview)
6. Merge via merge queue
7. Verify W2 creates THREE atomic branches and PRs:
   - `chart/cloudflared` → PR to main
   - `docs/cloudflared` → PR to main
   - `ci/release` → PR to main
8. Verify each PR references siblings (related links)
9. Verify W5 runs different validation per branch type:
   - Chart: lint, artifacthub, K8s tests
   - Docs: markdown lint, link validation
   - CI: actionlint, syntax check
10. Merge all PRs to main
11. Verify Release only runs for chart PR

**Expected**:

- Three separate atomic branches created
- Each PR has related links to siblings
- Different validation jobs per branch type
- Only chart PR triggers release workflow
- Integration reset to main after atomization

**Cleanup**:

- Delete atomic branches (should be auto-deleted by W5)
- Revert test changes if needed

---

## E2E-5: Dependabot Auto-Merge Flow

**Objective**: Verify dependabot PRs auto-merge via separate trust path.

**Steps**:

1. Wait for or trigger dependabot PR (or simulate with dependabot[bot] author)
2. Verify PR targets `integration` branch (not main)
3. Verify W1 runs:
   - Signature check passes (dependabot signs commits)
   - Trust check passes via dependabot path (skips CODEOWNERS)
4. Verify auto-merge enables
5. PR enters merge queue
6. PR merges to integration
7. Verify W2 atomizes normally
8. Verify W5 validates CI changes
9. Merge to main

**Expected**:

- Dependabot PR targets integration
- CODEOWNERS check skipped
- Signature check still enforced
- Auto-merge enabled
- Normal atomization flow

**Cleanup**:

- Let dependabot PR merge normally
- Monitor for any issues

---

## E2E-6: DLQ Handling for Unmatched Files

**Objective**: Verify DLQ correctly handles files not matching any pattern.

**Steps**:

1. Create feature branch from `integration`
2. Add files that don't match any pattern:
   - `scripts/custom-tool.sh`
   - `misc/notes.txt`
3. Also add a valid chart change (to ensure partial success)
4. Create PR to `integration`
5. Merge via merge queue
6. Verify W2:
   - Creates `chart/*` branch for valid chart change
   - Creates DLQ branch `dlq/<pr-number>` for unmatched files
   - Creates DLQ issue with file list
7. Verify DLQ issue contains:
   - List of unmatched files
   - Resolution steps
   - Link to DLQ branch

**Expected**:

- Matched files atomized normally
- Unmatched files go to DLQ branch
- DLQ issue created automatically
- Manual intervention required for DLQ files

**Cleanup**:

- Close DLQ issue after reviewing
- Delete DLQ branch
- Delete atomic branches

---

## E2E-7: Multiple Charts Changed (Independent Release)

**Objective**: Verify multiple charts are processed and released independently.

**Steps**:

1. Change both `charts/test-workflow` and `charts/cloudflared`
2. Merge to `integration`
3. Verify W2 creates TWO chart branches and TWO PRs:
   - `chart/test-workflow` → PR to main
   - `chart/cloudflared` → PR to main
4. Verify W5 runs on each independently
5. Merge both PRs to main
6. Verify Release workflow runs TWICE (once per chart):
   - `test-workflow-v*` tag and release
   - `cloudflared-v*` tag and release

**Expected**:

- Two independent pipelines
- Each chart versioned separately
- Each chart released separately
- No cross-contamination

**Cleanup**:

- Delete test branches
- Revert test changes if needed

---

## E2E-8: Missing Attestation Map Blocks Release

**Objective**: Verify that releases handle missing attestation maps appropriately.

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
- This is a known limitation

**Cleanup**:

- Delete test branch
- Delete tag if created
- Delete release if created

---

## E2E-9: K8s Test Failure Blocks Release

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

## E2E-10: Lint Failure Blocks Release

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

## E2E-11: Version Bump Failure Blocks Release

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

## E2E-12: Attestation Verification Failure Detection

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

## E2E-13: Full Lineage Trace Verification

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

## E2E-14: Failure Recovery (W2 Cleanup)

**Objective**: Verify W2 properly cleans up on failure.

**Steps**:

1. Create PR that will cause W2 failure (e.g., large binary file)
2. Merge to integration
3. Observe W2 failure during branch creation
4. Verify cleanup occurs:
   - Partial branches deleted
   - Error logged with clear message
   - Integration state preserved

**Expected**:

- No orphan branches left
- Error clearly indicates failure point
- Integration can be retried

**Cleanup**:

- Delete any remaining test branches
- Verify integration state

---

## E2E-15: Fork PR Security Flow

**Objective**: Verify fork PRs have appropriate security restrictions.

**Steps**:

1. Create fork of repository
2. Make changes in fork (including workflow modifications)
3. Create PR from fork to integration
4. Verify:
   - Limited permissions (no write access)
   - Secrets not exposed
   - CI validation runs with read-only
   - Auto-merge NOT enabled (untrusted source)
5. Manual review required

**Expected**:

- Fork PR cannot access secrets
- Cannot directly trigger W2
- actionlint validates workflow changes
- Manual approval required at all stages

**Cleanup**:

- Close PR
- Delete fork (if test-only)

---

## Cleanup Procedures

### After Each E2E Test

```bash
# Delete test branches
git push origin --delete <branch-name>

# Close test PRs
gh pr close <PR-number> --delete-branch

# Revert test changes (if on protected branch)
git revert <commit-sha>
```

### Artifacts to Preserve

| Artifact | Keep? | Reason |
|----------|-------|--------|
| Test chart (`charts/test-workflow/`) | NO | Remove after testing |
| Test results documentation | YES | Add to `docs/testing/` |
| Workflow fixes discovered | YES | Commit improvements |

### Artifacts to Remove

| Artifact | How to Remove |
|----------|---------------|
| Test branches | `git push origin --delete <branch>` |
| Test PRs | `gh pr close --delete-branch` |
| Test tags | `git push origin --delete <tag>` |
| Test releases | Delete via GitHub UI |
| Test chart | `rm -rf charts/test-workflow && git commit` |

---

## Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| E2E-1 | Complete pipeline, release created | Any stage fails |
| E2E-2 | Manual review required | Auto-merge enabled |
| E2E-4 | Three branches, correct validation | Wrong routing |
| E2E-9 | K8s failure blocks release | Release created despite failure |
| E2E-12 | Tampered package fails verify | Tampered package passes |

---

## Checklist

### Critical Path (P0)
- [x] E2E-1: Happy path with merge queue

### High Priority (P1)
- [x] E2E-2: Untrusted user flow
- [x] E2E-3: Unsigned commit flow
- [x] E2E-4: Multi-file-type atomization
- [ ] E2E-5: Dependabot auto-merge flow
- [x] E2E-7: Multiple charts changed
- [x] E2E-9: K8s test failure blocks release
- [x] E2E-10: Lint failure blocks release
- [x] E2E-12: Attestation verification failure
- [x] E2E-13: Full lineage trace verification
- [x] E2E-15: Fork PR security flow

### Medium Priority (P2)
- [x] E2E-6: DLQ handling
- [ ] E2E-8: Missing attestation map
- [ ] E2E-11: Version bump failure
- [x] E2E-14: Failure recovery

### Negative Tests
- [x] E2E-16: Direct push blocked
- [x] E2E-17: Bypass integration blocked
- [ ] E2E-18: Fork workflow modification
- [x] E2E-19: Release idempotency
- [x] E2E-20: Invalid commit format

---

## Failure Investigation

> **📚 Skill References**:
> - `~/.claude/skills/cicd-github-actions-ops` - Systematic debugging
> - `~/.claude/skills/method-debugging-systematic-eng` - Root cause analysis

When an E2E test fails:

1. **Identify which phase failed**: W1, W2, W5, or Release
2. **Check workflow logs**: `gh run view <run-id> --log`
3. **Check branch state**: `git branch -r | grep "chart/\|docs/\|ci/"`
4. **Check PR state**: `gh pr list --base main --state all`
5. **Find root cause before fixing** - don't patch symptoms

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Auto-merge not enabled | Trust check failed | Verify CODEOWNERS, signing |
| Wrong branch type | Pattern mismatch | Check atomic-branches.json |
| Release doesn't trigger | Not from chart/* | Verify source branch |
| Attestation missing | Step skipped | Check workflow conditions |

---

## Test Fixtures Per E2E (P6-G1 Resolved)

### Fixtures Overview

| E2E | Required Fixtures | Location | Created |
|-----|-------------------|----------|---------|
| E2E-1 | Valid chart change | `.github/tests/fixtures/e2e-1-happy-path/` | [ ] |
| E2E-4 | Multi-type change | `.github/tests/fixtures/e2e-4-multi-type/` | [ ] |
| E2E-6 | DLQ files | `.github/tests/fixtures/e2e-6-dlq/` | [ ] |
| E2E-9 | K8s-failing chart | `.github/tests/fixtures/e2e-9-k8s-fail/` | [ ] |
| E2E-10 | Lint-failing chart | `.github/tests/fixtures/e2e-10-lint-fail/` | [ ] |

### E2E-1 Fixture: Valid Chart Change

```bash
# .github/tests/fixtures/e2e-1-happy-path/create.sh
#!/usr/bin/env bash
set -euo pipefail

CHART="test-workflow"

# Add a valid feature to the chart
cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-1 Test: Valid feature addition
e2eTest:
  enabled: false
  replicas: 1
EOF

# Add corresponding template
cat > "charts/$CHART/templates/e2e-test-configmap.yaml" << 'EOF'
{{- if .Values.e2eTest.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "test-workflow.fullname" . }}-e2e
data:
  replicas: "{{ .Values.e2eTest.replicas }}"
{{- end }}
EOF

echo "E2E-1 fixtures created"
```

### E2E-4 Fixture: Multi-Type Change

```bash
# .github/tests/fixtures/e2e-4-multi-type/create.sh
#!/usr/bin/env bash
set -euo pipefail

# Chart change
echo "# E2E-4 chart change" >> charts/test-workflow/values.yaml

# Docs change
mkdir -p docs/src/test-topic
cat > docs/src/test-topic/e2e-test.md << 'EOF'
# E2E-4 Test Document

This document tests multi-type atomization.
EOF

# CI change
cat > .github/workflows/e2e-test.yaml << 'EOF'
name: E2E Test Workflow
on: workflow_dispatch
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo "E2E-4 test"
EOF

echo "E2E-4 multi-type fixtures created"
```

### E2E-6 Fixture: DLQ Files

```bash
# .github/tests/fixtures/e2e-6-dlq/create.sh
#!/usr/bin/env bash
set -euo pipefail

# Create files that don't match any pattern
mkdir -p scripts misc

cat > scripts/e2e-test.sh << 'EOF'
#!/bin/bash
echo "This file goes to DLQ"
EOF

cat > misc/notes.txt << 'EOF'
E2E-6: Unmatched file for DLQ testing
EOF

# Also add a valid chart change
echo "# E2E-6 valid chart change" >> charts/test-workflow/values.yaml

echo "E2E-6 DLQ fixtures created"
```

### E2E-9 Fixture: K8s-Failing Chart

```bash
# .github/tests/fixtures/e2e-9-k8s-fail/create.sh
#!/usr/bin/env bash
set -euo pipefail

CHART="test-workflow"

# Add template that fails K8s install (requires undefined value)
cat > "charts/$CHART/templates/e2e-fail-k8s.yaml" << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "test-workflow.fullname" . }}-e2e-fail
data:
  # This will fail because value doesn't exist
  required: {{ required "e2eFail.value is required" .Values.e2eFail.value }}
EOF

echo "E2E-9 K8s-fail fixtures created"
```

### E2E-10 Fixture: Lint-Failing Chart

```bash
# .github/tests/fixtures/e2e-10-lint-fail/create.sh
#!/usr/bin/env bash
set -euo pipefail

CHART="test-workflow"

# Remove required field from Chart.yaml (backup first)
cp "charts/$CHART/Chart.yaml" "charts/$CHART/Chart.yaml.bak"

# Remove description (required by ArtifactHub)
sed -i.tmp '/^description:/d' "charts/$CHART/Chart.yaml"
rm "charts/$CHART/Chart.yaml.tmp"

echo "E2E-10 lint-fail fixtures created"
echo "Remember to restore: cp charts/$CHART/Chart.yaml.bak charts/$CHART/Chart.yaml"
```

### Fixture Cleanup Script

```bash
#!/usr/bin/env bash
# .github/tests/fixtures/cleanup.sh

set -euo pipefail

echo "Cleaning up E2E fixtures..."

# E2E-1
git checkout charts/test-workflow/values.yaml
rm -f charts/test-workflow/templates/e2e-test-configmap.yaml

# E2E-4
rm -rf docs/src/test-topic
rm -f .github/workflows/e2e-test.yaml
git checkout charts/test-workflow/values.yaml

# E2E-6
rm -rf scripts misc
git checkout charts/test-workflow/values.yaml

# E2E-9
rm -f charts/test-workflow/templates/e2e-fail-k8s.yaml

# E2E-10
if [[ -f charts/test-workflow/Chart.yaml.bak ]]; then
  mv charts/test-workflow/Chart.yaml.bak charts/test-workflow/Chart.yaml
fi

echo "Cleanup complete"
```

---

## E2E Dependency Graph (P6-G2 Resolved)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        E2E TEST DEPENDENCY GRAPH                             │
└─────────────────────────────────────────────────────────────────────────────┘

INDEPENDENT (can run in any order):
═══════════════════════════════════════════════════════════════════════════════

E2E-1 (Happy Path) ────────────────────────────────────────────────────────────
  │                                                                    45-60min
  │
  ├── E2E-2 (Untrusted) ─────────────────────────────────── independent  30min
  ├── E2E-3 (Unsigned) ──────────────────────────────────── independent  20min
  ├── E2E-4 (Multi-type) ────────────────────────────────── independent  45min
  │
  │   ┌─────────────────────────────────────────────────────────────────────┐
  │   │ These can run in parallel after E2E-1 creates artifacts:            │
  │   │                                                                     │
  ├───┼── E2E-12 (Verify failure) ─── requires E2E-1 release        15min  │
  └───┼── E2E-13 (Lineage trace) ──── requires E2E-1 release        20min  │
      └─────────────────────────────────────────────────────────────────────┘


PARALLEL GROUP A (can run simultaneously):
═══════════════════════════════════════════════════════════════════════════════

┌─────────────┬─────────────┬─────────────┬─────────────┬─────────────┐
│   E2E-6     │   E2E-7     │   E2E-8     │   E2E-9     │   E2E-10    │
│   DLQ       │   Multi     │   Attest    │   K8s Fail  │   Lint Fail │
│   30min     │   60min     │   25min     │   25min     │   20min     │
└─────────────┴─────────────┴─────────────┴─────────────┴─────────────┘


PARALLEL GROUP B (can run simultaneously):
═══════════════════════════════════════════════════════════════════════════════

┌─────────────┬─────────────┬─────────────┐
│   E2E-11    │   E2E-14    │   E2E-15    │
│   Version   │   Recovery  │   Fork      │
│   25min     │   30min     │   30min     │
└─────────────┴─────────────┴─────────────┘


SPECIAL TIMING:
═══════════════════════════════════════════════════════════════════════════════

E2E-5 (Dependabot) ────── Wait for dependabot PR (unpredictable timing)
                         Can be skipped or mocked for regular testing


OPTIMAL EXECUTION ORDER:
═══════════════════════════════════════════════════════════════════════════════

Phase 1: E2E-1 (required baseline)
Phase 2: E2E-2, E2E-3, E2E-4 (parallel, independent)
Phase 3: E2E-6 through E2E-11 (parallel group A+B)
Phase 4: E2E-12, E2E-13 (requires E2E-1 artifacts)
Phase 5: E2E-14, E2E-15 (parallel)
Optional: E2E-5 (when dependabot PR available)

Total Time: ~4-5 hours (serial) or ~2-3 hours (parallel)
```

---

## Time Estimates Per E2E (P6-G3 Resolved)

| E2E | Time | Breakdown | Parallelizable |
|-----|------|-----------|----------------|
| E2E-1 | 45-60 min | W1: 5min, Queue: 5min, W2: 10min, W5: 15min, Merge: 5min, Release: 10min | No (baseline) |
| E2E-2 | 30 min | Fork: 5min, PR: 5min, W1: 5min, Manual: 10min, Verify: 5min | Yes |
| E2E-3 | 20 min | Branch: 2min, Commit: 2min, PR: 5min, Verify: 5min, Cleanup: 5min | Yes |
| E2E-4 | 45 min | Create: 5min, W1: 5min, W2: 10min, W5x3: 20min, Verify: 5min | Yes |
| E2E-5 | Variable | Wait: 0-7 days, Verify: 15min | Async |
| E2E-6 | 30 min | Create: 5min, W1: 5min, W2: 10min, DLQ: 5min, Verify: 5min | Yes |
| E2E-7 | 60 min | Create: 10min, W1: 5min, W2: 15min, W5x2: 20min, Release: 10min | Yes |
| E2E-8 | 25 min | Create: 5min, W1: 5min, W2: 5min, W5: 5min, Verify: 5min | Yes |
| E2E-9 | 25 min | Fixture: 5min, W1: 5min, W5: 10min (fail), Verify: 5min | Yes |
| E2E-10 | 20 min | Fixture: 5min, W1: 5min (fail), Verify: 5min, Cleanup: 5min | Yes |
| E2E-11 | 25 min | Setup: 5min, W1: 5min, W5: 10min, Verify: 5min | Yes |
| E2E-12 | 15 min | Download: 2min, Tamper: 2min, Verify: 5min, Cleanup: 5min | After E2E-1 |
| E2E-13 | 20 min | Script: 5min, Trace: 10min, Document: 5min | After E2E-1 |
| E2E-14 | 30 min | Trigger fail: 10min, Recovery: 15min, Verify: 5min | Yes |
| E2E-15 | 30 min | Fork: 5min, PR: 5min, Verify: 15min, Cleanup: 5min | Yes |

### Time Budget Summary

| Execution Mode | Total Time | Notes |
|----------------|------------|-------|
| Serial (all tests) | 6-8 hours | One at a time |
| Parallel (optimized) | 2-3 hours | With dependencies respected |
| Smoke Tests Only | 1-1.5 hours | E2E-1, E2E-4, E2E-9 |

---

## E2E Automation Scripts (P6-G4 Resolved)

### Master Test Runner

```bash
#!/usr/bin/env bash
# .github/tests/e2e/run-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$RESULTS_DIR/run.log"; }

# Parse arguments
PARALLEL=false
TESTS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --parallel) PARALLEL=true; shift ;;
    --tests) TESTS="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

log "Starting E2E test suite"
log "Results: $RESULTS_DIR"
log "Parallel: $PARALLEL"

# Run tests
run_test() {
  local test_id="$1"
  local test_script="$SCRIPT_DIR/$test_id.sh"

  if [[ ! -f "$test_script" ]]; then
    log "SKIP: $test_id (no script)"
    return 0
  fi

  log "START: $test_id"
  local start_time=$(date +%s)

  if bash "$test_script" > "$RESULTS_DIR/$test_id.log" 2>&1; then
    local status="PASS"
  else
    local status="FAIL"
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  log "$status: $test_id (${duration}s)"
  echo "$test_id,$status,$duration" >> "$RESULTS_DIR/summary.csv"
}

# Define test order
ALL_TESTS=(
  "e2e-1-happy-path"
  "e2e-2-untrusted"
  "e2e-3-unsigned"
  "e2e-4-multi-type"
  "e2e-6-dlq"
  "e2e-7-multi-chart"
  "e2e-9-k8s-fail"
  "e2e-10-lint-fail"
  "e2e-12-verify-fail"
  "e2e-13-lineage"
  "e2e-14-recovery"
  "e2e-15-fork"
)

# Filter tests if specified
if [[ -n "$TESTS" ]]; then
  IFS=',' read -ra SELECTED_TESTS <<< "$TESTS"
else
  SELECTED_TESTS=("${ALL_TESTS[@]}")
fi

# Run tests
if [[ "$PARALLEL" == "true" ]]; then
  log "Running in parallel mode"
  for test in "${SELECTED_TESTS[@]}"; do
    run_test "$test" &
  done
  wait
else
  log "Running in serial mode"
  for test in "${SELECTED_TESTS[@]}"; do
    run_test "$test"
  done
fi

# Summary
log ""
log "=== SUMMARY ==="
cat "$RESULTS_DIR/summary.csv"
log ""
log "Results saved to: $RESULTS_DIR"
```

### Individual Test Script Template

```bash
#!/usr/bin/env bash
# .github/tests/e2e/e2e-1-happy-path.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Test metadata
TEST_ID="E2E-1"
TEST_NAME="Happy Path"
EXPECTED_TIME=60

log "Starting $TEST_ID: $TEST_NAME"

# Prerequisites
assert_on_integration
assert_clean_working_tree
assert_codeowners_member

# Step 1: Create test branch
log "Step 1: Creating test branch"
BRANCH="test/e2e-1-$(date +%Y%m%d%H%M%S)"
git checkout -b "$BRANCH"

# Step 2: Apply fixtures
log "Step 2: Applying fixtures"
bash "$SCRIPT_DIR/../fixtures/e2e-1-happy-path/create.sh"

# Step 3: Commit with signature
log "Step 3: Committing changes"
git add .
git commit -S -m "feat(test-workflow): E2E-1 happy path test"

# Step 4: Push and create PR
log "Step 4: Creating PR"
git push origin "$BRANCH"
PR_URL=$(gh pr create --base integration --title "Test E2E-1: Happy Path" --body "Automated E2E test")
PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')

# Step 5: Wait for W1
log "Step 5: Waiting for W1 validation"
wait_for_workflow "validate-contribution-pr" "$PR_NUMBER"

# Step 6: Wait for auto-merge
log "Step 6: Waiting for merge queue"
wait_for_merge "$PR_NUMBER"

# Step 7: Wait for W2
log "Step 7: Waiting for W2 atomization"
wait_for_workflow "atomize-integration-pr"

# Step 8: Find atomic PR
log "Step 8: Finding atomic PR"
ATOMIC_PR=$(gh pr list --base main --head "chart/test-workflow" --json number -q '.[0].number')

# Step 9: Wait for W5
log "Step 9: Waiting for W5 validation"
wait_for_workflow "validate-atomic-pr" "$ATOMIC_PR"

# Step 10: Merge atomic PR
log "Step 10: Merging atomic PR"
gh pr merge "$ATOMIC_PR" --squash

# Step 11: Wait for release
log "Step 11: Waiting for release"
wait_for_workflow "release-atomic-chart"

# Verify
log "Verifying release..."
RELEASE_TAG=$(gh release list --limit 1 --json tagName -q '.[0].tagName')
assert_not_empty "$RELEASE_TAG" "Release tag"

log "Verifying attestation..."
gh release download "$RELEASE_TAG" --pattern "*.tgz"
gh attestation verify *.tgz --repo aRustyDev/helm-charts

# Cleanup
log "Cleanup..."
rm -f *.tgz
git checkout integration
git branch -D "$BRANCH" 2>/dev/null || true

log "$TEST_ID: PASSED"
```

### Common Library

```bash
#!/usr/bin/env bash
# .github/tests/e2e/lib/common.sh

log() { echo "[$(date +%H:%M:%S)] $*"; }

assert_on_integration() {
  local current=$(git branch --show-current)
  if [[ "$current" != "integration" ]]; then
    log "ERROR: Must be on integration branch (currently: $current)"
    exit 1
  fi
}

assert_clean_working_tree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    log "ERROR: Working tree not clean"
    git status --short
    exit 1
  fi
}

assert_codeowners_member() {
  local user=$(gh api user --jq '.login')
  if ! grep -q "@$user" .github/CODEOWNERS 2>/dev/null; then
    log "WARNING: $user may not be in CODEOWNERS"
  fi
}

assert_not_empty() {
  local value="$1"
  local name="$2"
  if [[ -z "$value" ]]; then
    log "ERROR: $name is empty"
    exit 1
  fi
}

wait_for_workflow() {
  local workflow="$1"
  local pr_number="${2:-}"
  local timeout=600  # 10 minutes
  local interval=30

  log "Waiting for $workflow..."

  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local status
    if [[ -n "$pr_number" ]]; then
      status=$(gh pr view "$pr_number" --json statusCheckRollup \
        --jq ".statusCheckRollup[] | select(.name | contains(\"$workflow\")) | .conclusion" | head -1)
    else
      status=$(gh run list --workflow="$workflow.yaml" --limit 1 --json conclusion -q '.[0].conclusion')
    fi

    if [[ "$status" == "success" ]]; then
      log "$workflow completed successfully"
      return 0
    elif [[ "$status" == "failure" ]]; then
      log "ERROR: $workflow failed"
      return 1
    fi

    sleep $interval
    elapsed=$((elapsed + interval))
    log "Waiting... ($elapsed/${timeout}s)"
  done

  log "ERROR: Timeout waiting for $workflow"
  return 1
}

wait_for_merge() {
  local pr_number="$1"
  local timeout=600
  local interval=30

  log "Waiting for PR #$pr_number to merge..."

  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local state=$(gh pr view "$pr_number" --json state -q '.state')

    if [[ "$state" == "MERGED" ]]; then
      log "PR #$pr_number merged"
      return 0
    elif [[ "$state" == "CLOSED" ]]; then
      log "ERROR: PR #$pr_number was closed without merge"
      return 1
    fi

    sleep $interval
    elapsed=$((elapsed + interval))
    log "Waiting... ($elapsed/${timeout}s) - state: $state"
  done

  log "ERROR: Timeout waiting for merge"
  return 1
}
```

---

## Negative E2E Tests (P6-G5 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| E2E-16 | Direct push to protected branch | Ruleset blocks | [x] **IMPLEMENTED** |
| E2E-17 | PR to main bypassing integration | Workflow warns or blocks | [x] **IMPLEMENTED** |
| E2E-18 | Modify workflow from fork | Limited permissions | [ ] |
| E2E-19 | Release re-trigger (idempotency) | Skip with notice | [x] **IMPLEMENTED** |
| E2E-20 | Invalid conventional commit | Commit validation fails | [x] **IMPLEMENTED** |

### E2E-16: Direct Push to Protected Branch

```bash
# Test: Verify rulesets block direct push

# 1. Attempt direct push to integration
git checkout integration
echo "test" >> test.txt
git add .
git commit -S -m "test: direct push"

# Expected: Push rejected by ruleset
git push origin integration 2>&1 | tee /tmp/e2e-16.log

if grep -q "rejected" /tmp/e2e-16.log; then
  echo "E2E-16: PASS - Direct push blocked"
else
  echo "E2E-16: FAIL - Direct push allowed"
  exit 1
fi

# Cleanup
git reset --hard HEAD~1
```

### E2E-17: PR to Main Bypassing Integration

```bash
# Test: Verify PRs to main from non-atomic branches are handled

# 1. Create non-atomic branch
git checkout main
git checkout -b test/e2e-17-bypass
echo "test" >> charts/test-workflow/values.yaml
git add .
git commit -S -m "feat(test-workflow): bypass integration"
git push origin HEAD

# 2. Create PR to main (bypassing integration)
gh pr create --base main --title "Test E2E-17: Bypass Integration"

# Expected: W5 should NOT run (no repository_dispatch)
# OR: validation should fail/warn

# 3. Check workflow status
sleep 30
RUNS=$(gh run list --workflow=validate-atomic-pr.yaml --limit 5 --json headBranch \
  --jq '[.[] | select(.headBranch == "test/e2e-17-bypass")] | length')

if [[ "$RUNS" == "0" ]]; then
  echo "E2E-17: PASS - W5 not triggered for non-atomic branch"
else
  echo "E2E-17: WARNING - W5 triggered for non-atomic branch"
fi

# Cleanup
gh pr close --delete-branch
```

### E2E-19: Release Re-Trigger (Idempotency)

```bash
# Test: Re-running release workflow doesn't create duplicate

# Prerequisites: E2E-1 completed, release exists
CHART="test-workflow"
TAG=$(gh release list --limit 1 --json tagName -q '.[0].tagName')

# 1. Get current release info
RELEASE_BEFORE=$(gh release view "$TAG" --json createdAt -q '.createdAt')

# 2. Re-run release workflow
gh workflow run release-atomic-chart.yaml

# 3. Wait for completion
sleep 60

# 4. Verify no duplicate release
RELEASE_COUNT=$(gh release list --json tagName -q "[.[] | select(.tagName == \"$TAG\")] | length")

if [[ "$RELEASE_COUNT" == "1" ]]; then
  echo "E2E-19: PASS - No duplicate release"
else
  echo "E2E-19: FAIL - Duplicate release created"
  exit 1
fi

# 5. Verify workflow logged "already exists"
RUN_ID=$(gh run list --workflow=release-atomic-chart.yaml --limit 1 --json databaseId -q '.[0].databaseId')
if gh run view "$RUN_ID" --log | grep -q "already exists"; then
  echo "E2E-19: PASS - Idempotent skip detected"
fi
```

### E2E-20: Invalid Conventional Commit

```bash
# Test: Non-conventional commit is rejected

# 1. Create branch with invalid commit
git checkout integration
git checkout -b test/e2e-20-bad-commit
echo "test" >> charts/test-workflow/values.yaml
git add .
git commit -S -m "updated stuff"  # Invalid: not conventional
git push origin HEAD

# 2. Create PR
gh pr create --base integration --title "Test E2E-20: Bad Commit"

# 3. Wait for W1
sleep 30

# 4. Verify commit validation failed
PR_NUMBER=$(gh pr list --head "test/e2e-20-bad-commit" --json number -q '.[0].number')
COMMIT_CHECK=$(gh pr view "$PR_NUMBER" --json statusCheckRollup \
  --jq '.statusCheckRollup[] | select(.name | contains("commit")) | .conclusion')

if [[ "$COMMIT_CHECK" == "failure" ]]; then
  echo "E2E-20: PASS - Invalid commit rejected"
else
  echo "E2E-20: FAIL - Invalid commit accepted"
  exit 1
fi

# Cleanup
gh pr close --delete-branch
```

---

## GAPs Resolution Status

| GAP ID | Description | Priority | Status |
|--------|-------------|----------|--------|
| P6-G1 | Add test fixtures/data requirements per E2E | High | [x] **RESOLVED** |
| P6-G2 | Add E2E dependency graph visualization | Medium | [x] **RESOLVED** |
| P6-G3 | Add time estimates per E2E scenario | Medium | [x] **RESOLVED** |
| P6-G4 | Add E2E automation scripts | Low | [x] **RESOLVED** |
| P6-G5 | Add negative E2E tests (intentional breakage) | Medium | [x] **RESOLVED** |

### Resolution Summary

- **P6-G1**: Created fixture scripts for E2E-1, 4, 6, 9, 10 with cleanup
- **P6-G2**: ASCII dependency graph with execution phases and timing
- **P6-G3**: Detailed time breakdown per E2E with parallelization notes
- **P6-G4**: Complete automation suite with master runner and common library
- **P6-G5**: Added E2E-16 through E2E-20 negative tests

---

## Implementation Status

### Test Scripts Created

| File | Description |
|------|-------------|
| `.github/tests/e2e/run-all.sh` | Master test runner with parallel/serial modes |
| `.github/tests/e2e/lib/common.sh` | Common library with logging, assertions, git/GH helpers |
| `.github/tests/e2e/lib/common.bats` | BATS unit tests for common library |
| `.github/tests/e2e/e2e-1-happy-path.sh` | Full pipeline test |
| `.github/tests/e2e/e2e-2-untrusted.sh` | Untrusted contributor flow |
| `.github/tests/e2e/e2e-3-unsigned.sh` | Unsigned commit handling |
| `.github/tests/e2e/e2e-4-multi-type.sh` | Multi-file-type atomization |
| `.github/tests/e2e/e2e-6-dlq.sh` | DLQ handling |
| `.github/tests/e2e/e2e-7-multi-chart.sh` | Multiple charts |
| `.github/tests/e2e/e2e-9-k8s-fail.sh` | K8s test failure |
| `.github/tests/e2e/e2e-10-lint-fail.sh` | Lint failure |
| `.github/tests/e2e/e2e-12-verify-fail.sh` | Attestation verification |
| `.github/tests/e2e/e2e-13-lineage.sh` | Full lineage trace |
| `.github/tests/e2e/e2e-14-recovery.sh` | Failure recovery |
| `.github/tests/e2e/e2e-15-fork.sh` | Fork PR security |
| `.github/tests/e2e/e2e-16-direct-push.sh` | Direct push blocked |
| `.github/tests/e2e/e2e-17-bypass.sh` | Bypass integration |
| `.github/tests/e2e/e2e-19-idempotent.sh` | Release idempotency |
| `.github/tests/e2e/e2e-20-bad-commit.sh` | Invalid commit format |

### Fixtures Created

| Directory | Description |
|-----------|-------------|
| `.github/tests/e2e/fixtures/e2e-1-happy-path/` | Valid chart feature |
| `.github/tests/e2e/fixtures/e2e-4-multi-type/` | Chart + docs + CI changes |
| `.github/tests/e2e/fixtures/e2e-6-dlq/` | Non-matching files for DLQ |
| `.github/tests/e2e/fixtures/e2e-9-k8s-fail/` | Template that fails install |
| `.github/tests/e2e/fixtures/e2e-10-lint-fail/` | Chart.yaml missing description |
| `.github/tests/e2e/fixtures/cleanup-all.sh` | Master cleanup script |

### Running the Tests

```bash
# Run all tests serially
.github/tests/e2e/run-all.sh

# Run specific tests
.github/tests/e2e/run-all.sh --tests e2e-1-happy-path,e2e-9-k8s-fail

# Run tests in parallel (where safe)
.github/tests/e2e/run-all.sh --parallel

# Dry run (show what would execute)
.github/tests/e2e/run-all.sh --dry-run

# Run BATS unit tests
bats .github/tests/e2e/lib/common.bats
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `E2E_REPO` | Auto-detected | GitHub repository (owner/repo) |
| `E2E_CHART` | `test-workflow` | Chart to use for testing |
| `E2E_TIMEOUT` | `600` | Workflow wait timeout in seconds |
| `E2E_MOCK` | `false` | Enable mock mode for local testing |

### Tests Not Yet Implemented

The following tests require additional infrastructure or manual setup:

- **E2E-5** (Dependabot): Requires waiting for dependabot PRs
- **E2E-8** (Missing attestation map): Requires bypassing W2
- **E2E-11** (Version bump failure): Requires specific commit patterns
- **E2E-18** (Fork workflow modification): Requires fork repository
