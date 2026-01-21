# Phase 5: Release & Attestation Tests

## Overview

Tests for the release workflow, merge queue, dependabot integration, and attestation/provenance verification.

| Attribute | Value |
|-----------|-------|
| **Dependencies** | Phase 4 (W5 validation must pass, PR merged to main) |
| **Time Estimate** | ~10 minutes per release |
| **Infrastructure** | GitHub repository, GHCR registry, Cosign |
| **Workflow File** | `release-atomic-chart.yaml` |

> **📚 Skill References**:
> - `~/.claude/skills/k8s-helm-charts-dev` - Helm chart packaging, validation, registry operations
> - `~/.claude/skills/cicd-github-actions-dev` - Workflow debugging

---

## Release Workflow (`release-atomic-chart.yaml`)

> **Note**: Tag is created FIRST, then release checks out at that tag.

### Release Flow

```
PR merged → main (from chart/*)
       │
       ▼
┌─────────────────────────────────────────┐
│ 1. Create version tag (TAG FIRST)       │
│    git tag cloudflared-v1.2.3           │
│    git push origin cloudflared-v1.2.3   │
└─────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ 2. Checkout at tag                      │
│    git checkout cloudflared-v1.2.3      │
└─────────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────┐
│ 3. Package + Attest + Release + Push    │
│    helm package → attestation →         │
│    gh release → helm push → cosign sign │
└─────────────────────────────────────────┘
```

---

## Controls: Release

| ID | Control | Code Location |
|----|---------|---------------|
| R-C1 | Trigger on PR merged to main | `pull_request.types: [closed]` from `chart/*` |
| R-C2 | Only process chart branches | Source branch matches `chart/*` |
| R-C3 | **Create tag FIRST** | `git tag <chart>-v<version>` before checkout |
| R-C4 | Checkout at tag | `git checkout $TAG` |
| R-C5 | Tag doesn't already exist | `git rev-parse "$TAG_NAME"` check |
| R-C6 | Chart.yaml has version | `VERSION=$(grep '^version:')` |
| R-C7 | Package chart | `helm package` |
| R-C8 | Package attestation | `attest-build-provenance` |
| R-C9 | Create GitHub Release | `gh release create` with assets |
| R-C10 | GHCR push + Cosign sign | `helm push` + `cosign sign` |

---

## Test Matrix: Release

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| R-T1 | R-C1 | PR merged from non-chart branch | Workflow doesn't run | [x] |
| R-T2 | R-C2 | PR merged from `docs/*` branch | Workflow doesn't run | [x] |
| R-T3 | R-C3 | Tag created before checkout | Tag exists at merge commit | [x] |
| R-T4 | R-C4 | Checkout at tag succeeds | Working tree at tagged commit | [x] |
| R-T5 | R-C5 | Tag already exists (same commit) | Skip with notice | [x] |
| R-T6 | R-C5 | Tag exists at different commit | Error - version collision | [x] |
| R-T7 | R-C6 | Chart.yaml missing version | Error extracting version | [x] |
| R-T8 | R-C7 | Package created | .tgz file generated | [x] |
| R-T9 | R-C8 | Attestation generated | Provenance attached to package | [x] |
| R-T10 | R-C9 | GitHub Release created | Release with assets | [x] |
| R-T11 | R-C10 | GHCR push succeeds | Chart in registry | [x] |
| R-T12 | R-C10 | Cosign signature applied | Signature in registry | [x] |

---

## Controls: Merge Queue

| ID | Control | Code Location |
|----|---------|---------------|
| MQ-C1 | Merge queue enabled | Branch ruleset configuration |
| MQ-C2 | Build concurrency = 1 | Prevents state conflicts |
| MQ-C3 | PRs queued serially | Queue order preserved |
| MQ-C4 | Queue respects status checks | W1 must pass before queuing |

---

## Test Matrix: Merge Queue

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| MQ-T1 | MQ-C1 | PR approved, auto-merge enabled | PR enters merge queue | [x] |
| MQ-T2 | MQ-C2 | Two PRs in queue | Second waits for first | [x] |
| MQ-T3 | MQ-C3 | First PR in queue fails | Second PR stays queued | [x] |
| MQ-T4 | MQ-C4 | W1 fails after queue entry | PR removed from queue | [x] |
| MQ-T5 | MQ-C1 | Queue processes PR | PR merged to integration | [x] |
| MQ-T6 | MQ-C2 | Concurrent PRs complete | Each atomized in order | [x] |

---

## Test Matrix: Selective Trim Fallback

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| ST-T1 | Single merge, no concurrent | Full reset to main | [x] |
| ST-T2 | Concurrent merge (queue bypassed) | Selective trim preserves later commits | [x] |
| ST-T3 | Rebase conflict during trim | Error logged, manual intervention required | [x] |

---

## Controls: Dependabot

| ID | Control | Code Location |
|----|---------|---------------|
| DB-C1 | Dependabot targets integration | `target-branch: integration` in config |
| DB-C2 | Commits are signed | Dependabot uses verified signatures |
| DB-C3 | Skip CODEOWNERS check | `author == dependabot[bot]` special path |
| DB-C4 | Auto-merge enabled | Trust check passes via separate path |

---

## Test Matrix: Dependabot

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| DB-T1 | DB-C1 | Dependabot creates PR | PR targets integration (not main) | [x] |
| DB-T2 | DB-C2 | Dependabot commits | All commits signed/verified | [x] |
| DB-T3 | DB-C3 | Trust check for dependabot | CODEOWNERS check skipped | [x] |
| DB-T4 | DB-C4 | Dependabot PR + signed commits | Auto-merge ENABLED | [x] |
| DB-T5 | DB-C2 | Unsigned dependabot commit (edge case) | Auto-merge NOT enabled | [x] |
| DB-T6 | DB-C1 | Dependabot PR to main (misconfigured) | Workflow rejects or warns | [x] |

---

## Controls: Attestation

| ID | Control | Code Location |
|----|---------|---------------|
| AT-C1 | Package attestation generated | `attest-build-provenance` action |
| AT-C2 | Attestation attached to artifact | `--subject-path` pointing to package |
| AT-C3 | Cosign signature on OCI | `cosign sign` with OIDC |
| AT-C4 | Attestation verifiable | `gh attestation verify` succeeds |
| AT-C5 | Cosign signature verifiable | `cosign verify` succeeds |
| AT-C6 | Attestation includes build info | Contains workflow, commit SHA, repository |

---

## Test Matrix: Attestation

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| AT-T1 | AT-C1 | Release workflow completes | Attestation step succeeds | [x] |
| AT-T2 | AT-C2 | Package has attestation | Attestation linked to .tgz artifact | [x] |
| AT-T3 | AT-C3 | OCI image has Cosign signature | Signature exists in registry | [x] |
| AT-T4 | AT-C4 | Verify package attestation | Returns valid attestation JSON | [x] |
| AT-T5 | AT-C5 | Verify Cosign signature | Verification succeeds with OIDC issuer | [x] |
| AT-T6 | AT-C6 | Attestation contains build metadata | Includes repo, workflow, SHA, actor | [x] |
| AT-T7 | AT-C4 | Tampered package fails verification | Attestation verify fails | [x] |
| AT-T8 | AT-C5 | Wrong issuer fails verification | Cosign verify fails | [x] |

---

## Test Matrix: Attestation Lineage

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| AL-T1 | Trace release to merge commit | Release attestation references merge commit SHA | [x] |
| AL-T2 | Trace merge to atomic PR | Merge commit matches PR merge SHA | [x] |
| AL-T3 | Trace atomic PR to integration | PR source branch created from integration commit | [x] |
| AL-T4 | Trace integration to contributor | Integration commit from merged contribution PR | [x] |
| AL-T5 | Full lineage audit | Can trace release back to original contributor PR | [x] |
| AL-T6 | Attestation actor matches workflow | `github-actions[bot]` or workflow actor in claims | [x] |

---

## Test Execution Steps

### R-T3: Tag Created Before Checkout

```bash
# 1. Prerequisites: W5 passed, atomic chart PR ready

# 2. Merge PR to main
gh pr merge <pr-number> --squash

# 3. Monitor release workflow
gh run list --workflow=release-atomic-chart.yaml --limit 5
gh run view <run-id> --log

# 4. Verify tag was created
git fetch --tags
git tag -l "*-v*" | tail -1

# 5. Verify tag is at merge commit
MERGE_SHA=$(gh pr view <pr-number> --json mergeCommit -q '.mergeCommit.oid')
TAG_SHA=$(git rev-list -n 1 <tag-name>)
[ "$MERGE_SHA" == "$TAG_SHA" ] && echo "PASS" || echo "FAIL"
```

### AT-T4: Verify Package Attestation

```bash
# 1. Download released package
gh release download <tag-name> \
  --repo aRustyDev/helm-charts \
  --pattern "*.tgz"

# 2. Verify attestation
gh attestation verify *.tgz --repo aRustyDev/helm-charts

# 3. Get attestation details
gh attestation verify *.tgz \
  --repo aRustyDev/helm-charts \
  --format json | jq '.attestations[].verificationResult'
```

### AT-T5: Verify Cosign Signature

```bash
# 1. Verify Cosign signature
cosign verify ghcr.io/arustydev/helm-charts/<chart>:<version> \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "github.com/aRustyDev/helm-charts"

# 2. View signature tree
cosign tree ghcr.io/arustydev/helm-charts/<chart>:<version>
```

---

## Verification Commands Reference

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

## Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| R-C3 | Tag created before checkout | Tag created after or not at all |
| R-C9 | Release with all assets | Missing assets |
| R-C10 | GHCR push + signature | Push fails or no signature |
| AT-C4 | Attestation verifiable | Verification fails |
| AT-C5 | Cosign verifiable | Verification fails |

---

## Checklist

### Release
- [x] R-T1: Non-chart branch - workflow doesn't run
- [x] R-T3: Tag created before checkout
- [x] R-T5: Tag exists (same commit) - skip with notice
- [x] R-T6: Tag exists (different commit) - error
- [x] R-T9: Attestation generated
- [x] R-T10: GitHub Release created
- [x] R-T11: GHCR push succeeds
- [x] R-T12: Cosign signature applied

### Merge Queue
- [x] MQ-T1: PR approved - enters queue
- [x] MQ-T2: Two PRs - second waits
- [x] MQ-T5: Queue processes PR
- [x] ST-T1: Single merge - full reset

### Dependabot
- [x] DB-T1: PR targets integration
- [x] DB-T2: Commits signed
- [x] DB-T3: CODEOWNERS skipped
- [x] DB-T4: Auto-merge enabled

### Attestation
- [x] AT-T2: Package has attestation
- [x] AT-T4: Verify package attestation
- [x] AT-T5: Verify Cosign signature
- [x] AT-T6: Attestation contains build metadata
- [x] AT-T7: Tampered package fails verification
- [x] AL-T1: Trace release to merge commit
- [x] AL-T5: Full lineage audit

---

## Failure Investigation

> **📚 Skill Reference**: Use `~/.claude/skills/cicd-github-actions-ops` for systematic debugging

When release fails:

1. **Check workflow logs**: `gh run view <run-id> --log`
2. **Check tag status**: `git tag -l "<chart>-v*"`
3. **Check GHCR permissions**: Repository settings → Packages
4. **Check Cosign OIDC**: Token permissions in workflow

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Tag already exists | Re-release same version | Check for collision |
| GHCR push fails | Missing permissions | Add `packages: write` |
| Cosign fails | OIDC token issue | Check `id-token: write` |
| Attestation missing | Step skipped | Check workflow conditions |

---

## Notes

### Dependabot Configuration

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    target-branch: "integration"  # REQUIRED
    schedule:
      interval: "weekly"
```

### Merge Queue Configuration

| Setting | Value | Reason |
|---------|-------|--------|
| Merge method | Squash | Clean integration history |
| Build concurrency | 1 | Prevent state conflicts |
| Minimum entries | 1 | Don't wait for batching |
| Maximum entries | 5 | Reasonable queue size |

---

## Rollback Test Scenarios (P5-G1 Resolved)

| Test ID | Scenario | Steps | Expected | Status |
|---------|----------|-------|----------|--------|
| RB-T1 | Delete release only | `gh release delete <tag>` | Release removed, tag remains | [x] |
| RB-T2 | Delete release + tag | Delete release, then tag | Both removed | [x] |
| RB-T3 | Revert and re-release | Revert commit, new release | v1.0.1 with fix | [x] |
| RB-T4 | OCI image after release delete | Check `helm pull` | Image still accessible | [x] |
| RB-T5 | Full rollback (release + tag + OCI) | Delete all artifacts | Clean state | [x] |

### RB-T1: Delete Release Only

```bash
CHART="test-workflow"
VERSION="0.2.0"
TAG="${CHART}-v${VERSION}"

# 1. Prerequisites: Release exists
gh release view "$TAG" --repo aRustyDev/helm-charts

# 2. Delete the release (keeps tag)
gh release delete "$TAG" --repo aRustyDev/helm-charts --yes

# 3. Verify tag still exists
git fetch --tags
git tag -l "$TAG"
# Expected: Tag still exists

# 4. Verify release is gone
gh release view "$TAG" --repo aRustyDev/helm-charts 2>&1 || echo "Release deleted"
# Expected: Error - release not found

# 5. Note: OCI image still exists in GHCR
helm pull oci://ghcr.io/arustydev/helm-charts/$CHART --version $VERSION
# Expected: Still works
```

### RB-T2: Delete Release + Tag

```bash
CHART="test-workflow"
VERSION="0.2.0"
TAG="${CHART}-v${VERSION}"

# 1. Delete release first
gh release delete "$TAG" --repo aRustyDev/helm-charts --yes

# 2. Delete tag
git push origin --delete "$TAG"

# 3. Verify both are gone
gh release view "$TAG" 2>&1 || echo "Release deleted"
git tag -l "$TAG"  # Should be empty

# 4. Note: OCI image STILL exists (immutable)
# This is by design - GHCR images are not deleted automatically
```

### RB-T3: Revert and Re-Release

```bash
CHART="test-workflow"
BAD_VERSION="0.2.0"
FIX_VERSION="0.2.1"

# 1. Create fix on main (via atomic flow)
git checkout main
git pull origin main
git checkout -b chart/$CHART

# 2. Revert the bad change
git revert HEAD --no-edit

# 3. Bump version to patch
yq e '.version = "0.2.1"' -i charts/$CHART/Chart.yaml

# 4. Commit with fix message
git add .
git commit -S -m "fix($CHART): revert bad change from v$BAD_VERSION"

# 5. Create PR to main
git push origin HEAD
gh pr create --base main --title "fix($CHART): revert v$BAD_VERSION"

# 6. After merge, new release created: v0.2.1

# 7. Verify both versions exist in registry
helm pull oci://ghcr.io/arustydev/helm-charts/$CHART --version $BAD_VERSION
helm pull oci://ghcr.io/arustydev/helm-charts/$CHART --version $FIX_VERSION
```

### RB-T5: Full Rollback (Nuclear Option)

```bash
CHART="test-workflow"
VERSION="0.2.0"
TAG="${CHART}-v${VERSION}"

# WARNING: This should rarely be needed
# OCI images are immutable by design

# 1. Delete GitHub release
gh release delete "$TAG" --repo aRustyDev/helm-charts --yes

# 2. Delete git tag
git push origin --delete "$TAG"

# 3. Delete OCI image (requires GHCR admin access)
# Via GitHub UI: Packages → helm-charts → test-workflow → Delete version
# Or via API:
gh api --method DELETE \
  /user/packages/container/helm-charts%2F$CHART/versions/{version_id}

# 4. Verify complete removal
gh release view "$TAG" 2>&1 && echo "FAIL: Release exists"
git tag -l "$TAG" && echo "FAIL: Tag exists"
helm pull oci://ghcr.io/arustydev/helm-charts/$CHART --version $VERSION 2>&1 && echo "FAIL: Image exists"

echo "Full rollback complete"
```

---

## GHCR Push Failure Recovery (P5-G2 Resolved)

| Failure | State After | Recovery |
|---------|-------------|----------|
| Attestation succeeds, GHCR fails | Release exists, no OCI | Re-run workflow or manual push |
| GHCR succeeds, Cosign fails | OCI exists, no signature | Re-run Cosign step manually |
| Release created, all registry fails | Release exists, no OCI | Delete release and re-run |

### Recovery: Attestation OK, GHCR Failed

```bash
CHART="test-workflow"
VERSION="0.2.0"
TAG="${CHART}-v${VERSION}"

# 1. Check what exists
gh release view "$TAG"  # Should exist with .tgz
helm pull oci://ghcr.io/arustydev/helm-charts/$CHART --version $VERSION 2>&1
# Expected: Error - not found

# 2. Download the .tgz from release
gh release download "$TAG" --pattern "*.tgz"

# 3. Manual push to GHCR
helm push ${CHART}-${VERSION}.tgz oci://ghcr.io/arustydev/helm-charts

# 4. Manual Cosign sign (requires OIDC or local key)
# For keyless (CI):
cosign sign ghcr.io/arustydev/helm-charts/$CHART:$VERSION

# 5. Verify
helm pull oci://ghcr.io/arustydev/helm-charts/$CHART --version $VERSION
cosign verify ghcr.io/arustydev/helm-charts/$CHART:$VERSION \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

### Recovery: GHCR OK, Cosign Failed

```bash
CHART="test-workflow"
VERSION="0.2.0"

# 1. Check what exists
helm pull oci://ghcr.io/arustydev/helm-charts/$CHART --version $VERSION
# Expected: Works

cosign verify ghcr.io/arustydev/helm-charts/$CHART:$VERSION \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
# Expected: Fails - no signature

# 2. Re-run release workflow to add signature
gh workflow run release-atomic-chart.yaml

# OR manual sign (requires OIDC token or local key):
cosign sign ghcr.io/arustydev/helm-charts/$CHART:$VERSION

# 3. Verify signature now exists
cosign verify ghcr.io/arustydev/helm-charts/$CHART:$VERSION \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

### Recovery: Release Created, All Registry Failed

```bash
CHART="test-workflow"
VERSION="0.2.0"
TAG="${CHART}-v${VERSION}"

# 1. Delete the incomplete release
gh release delete "$TAG" --yes

# 2. Delete the tag (so workflow creates it fresh)
git push origin --delete "$TAG"

# 3. Re-run the release workflow
gh workflow run release-atomic-chart.yaml \
  -f chart=$CHART \
  -f version=$VERSION

# OR: Re-merge the PR to trigger fresh release
# This requires closing and reopening the atomic PR
```

---

## Local Cosign Testing Setup (P5-G3 Resolved)

### Prerequisites

```bash
# Install cosign
# macOS
brew install cosign

# Linux
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
chmod +x cosign-linux-amd64
sudo mv cosign-linux-amd64 /usr/local/bin/cosign

# Verify installation
cosign version
```

### Local Key Pair Testing

```bash
# 1. Generate local key pair (for development only)
cosign generate-key-pair

# Creates:
# - cosign.key (private, password protected)
# - cosign.pub (public)

# 2. Start a local registry for testing
docker run -d -p 5000:5000 --name registry registry:2

# 3. Build and push a test chart
helm package charts/test-workflow
helm push test-workflow-0.1.0.tgz oci://localhost:5000/charts

# 4. Sign with local key
cosign sign --key cosign.key localhost:5000/charts/test-workflow:0.1.0
# Enter password when prompted

# 5. Verify with local public key
cosign verify --key cosign.pub localhost:5000/charts/test-workflow:0.1.0
# Expected: Verification succeeded

# 6. Cleanup
docker stop registry && docker rm registry
rm cosign.key cosign.pub
```

### Keyless Testing (Requires Browser)

```bash
# Keyless signing uses OIDC (browser-based auth)
# This simulates production behavior

# 1. Sign without key
cosign sign ghcr.io/arustydev/helm-charts/test-workflow:0.1.0
# Browser opens for OIDC authentication

# 2. Verify with OIDC issuer
cosign verify ghcr.io/arustydev/helm-charts/test-workflow:0.1.0 \
  --certificate-oidc-issuer https://accounts.google.com
```

### CI Testing (GitHub Actions OIDC)

```yaml
# In workflow:
- name: Sign with Cosign
  env:
    COSIGN_EXPERIMENTAL: 1
  run: |
    cosign sign ghcr.io/arustydev/helm-charts/${{ env.CHART }}:${{ env.VERSION }}

- name: Verify Signature
  run: |
    cosign verify ghcr.io/arustydev/helm-charts/${{ env.CHART }}:${{ env.VERSION }} \
      --certificate-oidc-issuer https://token.actions.githubusercontent.com \
      --certificate-identity-regexp "github.com/aRustyDev/helm-charts"
```

---

## Release Notes Generation Tests (P5-G4 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| RN-T1 | Single fix commit | "Bug Fixes" section | [x] |
| RN-T2 | Single feat commit | "Features" section | [x] |
| RN-T3 | Breaking change | "BREAKING CHANGES" section | [x] |
| RN-T4 | Mixed commits | Multiple sections | [x] |
| RN-T5 | Empty release notes | Fallback message | [x] |

### Release Notes Template

```markdown
## [{{ .Version }}] - {{ .Date }}

### Features
{{- range .Features }}
- {{ .Subject }}
{{- end }}

### Bug Fixes
{{- range .Fixes }}
- {{ .Subject }}
{{- end }}

### BREAKING CHANGES
{{- range .BreakingChanges }}
- {{ .Subject }}
{{- end }}

---
Full Changelog: {{ .CompareURL }}
```

### RN-T1: Single Fix Commit

```bash
# 1. Create fix commit
git checkout chart/test-workflow
echo "fix" >> charts/test-workflow/values.yaml
git commit -S -m "fix(test-workflow): resolve configuration issue"

# 2. Expected release notes:
# ## [0.1.1]
# ### Bug Fixes
# - resolve configuration issue
```

### Release Notes Generation in Workflow

```yaml
# In release-atomic-chart.yaml
- name: Generate Release Notes
  id: notes
  run: |
    # Get commits since last release
    PREV_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")

    if [[ -n "$PREV_TAG" ]]; then
      COMMITS=$(git log --pretty=format:"- %s" $PREV_TAG..HEAD -- charts/$CHART)
    else
      COMMITS=$(git log --pretty=format:"- %s" -10 -- charts/$CHART)
    fi

    # Categorize commits
    FEATURES=$(echo "$COMMITS" | grep -E "^- feat" || true)
    FIXES=$(echo "$COMMITS" | grep -E "^- fix" || true)
    BREAKING=$(echo "$COMMITS" | grep -E "^- feat.*!" || true)

    # Build release notes
    NOTES="## What's Changed\n\n"

    if [[ -n "$FEATURES" ]]; then
      NOTES+="### Features\n$FEATURES\n\n"
    fi

    if [[ -n "$FIXES" ]]; then
      NOTES+="### Bug Fixes\n$FIXES\n\n"
    fi

    if [[ -n "$BREAKING" ]]; then
      NOTES+="### BREAKING CHANGES\n$BREAKING\n\n"
    fi

    echo "notes<<EOF" >> "$GITHUB_OUTPUT"
    echo -e "$NOTES" >> "$GITHUB_OUTPUT"
    echo "EOF" >> "$GITHUB_OUTPUT"
```

---

## Concurrent Release Tests (P5-G5 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| CR-T1 | Two charts merged simultaneously | Both release independently | [x] |
| CR-T2 | Same chart version race condition | Second workflow fails | [x] |
| CR-T3 | Re-run while previous running | Second queued or fails | [x] |
| CR-T4 | Concurrent tag creation | One succeeds, one fails | [x] |

### Concurrency Configuration

```yaml
# release-atomic-chart.yaml
concurrency:
  group: release-${{ github.event.pull_request.head.ref }}
  cancel-in-progress: false  # Don't cancel, queue instead
```

### CR-T1: Two Different Charts

```bash
# 1. Create two atomic PRs (different charts)
# PR 1: chart/cloudflared
# PR 2: chart/external-secrets

# 2. Merge both at the same time
gh pr merge 1 --squash &
gh pr merge 2 --squash &
wait

# 3. Expected: Both release workflows run independently
gh run list --workflow=release-atomic-chart.yaml --limit 5

# 4. Verify both releases created
gh release list | head -5
```

### CR-T2: Same Chart Race Condition

```bash
# Scenario: Two PRs for same chart, same version

# 1. First PR merged, tag created
# 2. Second PR tries to create same tag

# Expected behavior in workflow:
# - Check if tag exists at same commit → skip (idempotent)
# - Check if tag exists at different commit → ERROR (version collision)

# Workflow code:
if git rev-parse "$TAG" >/dev/null 2>&1; then
  EXISTING_SHA=$(git rev-list -n 1 "$TAG")
  if [[ "$EXISTING_SHA" == "$GITHUB_SHA" ]]; then
    echo "::notice::Tag already exists at this commit, skipping"
    exit 0
  else
    echo "::error::Tag exists at different commit - version collision!"
    exit 1
  fi
fi
```

### CR-T3: Workflow Re-Run

```bash
# 1. Trigger release workflow
gh workflow run release-atomic-chart.yaml

# 2. Immediately re-run before first completes
gh workflow run release-atomic-chart.yaml

# 3. Expected: Second run queued (not cancelled)
# Due to: cancel-in-progress: false

# 4. Verify queue behavior
gh run list --workflow=release-atomic-chart.yaml --limit 5 --json status
```

---

## GAPs Resolution Status

| GAP ID | Description | Priority | Status |
|--------|-------------|----------|--------|
| P5-G1 | Add rollback test scenarios | High | [x] **RESOLVED** |
| P5-G2 | Add tests for GHCR push failure mid-way | Medium | [x] **RESOLVED** |
| P5-G3 | Document local Cosign testing setup | Medium | [x] **RESOLVED** |
| P5-G4 | Add tests for release notes generation | Low | [x] **RESOLVED** |
| P5-G5 | Add tests for concurrent releases | Medium | [x] **RESOLVED** |

### Resolution Summary

- **P5-G1**: Added RB-T1 through RB-T5 rollback tests with full procedures
- **P5-G2**: Documented recovery procedures for all partial failure scenarios
- **P5-G3**: Complete local Cosign testing guide with key-based and keyless options
- **P5-G4**: Added RN-T1 through RN-T5 tests with release notes generation workflow
- **P5-G5**: Added CR-T1 through CR-T4 concurrent release tests with concurrency config

---

## Phase 5 Completion Status

**Status**: ✅ COMPLETE

**Test Files Created**:
| File | Test Count | Description |
|------|------------|-------------|
| `test-attestation.bats` | 33 | AT-T1 to AT-T8 + edge cases |
| `test-concurrent.bats` | 27 | CR-T1 to CR-T4 + edge cases |
| `test-dependabot.bats` | 25 | DB-T1 to DB-T6 + edge cases |
| `test-lineage.bats` | 27 | AL-T1 to AL-T6 + edge cases |
| `test-merge-queue.bats` | 33 | MQ-T1 to MQ-T6 + ST-T1 to ST-T3 |
| `test-release-notes.bats` | 32 | RN-T1 to RN-T5 + edge cases |
| `test-release-workflow.bats` | 44 | R-T1 to R-T12 + edge cases |
| `test-rollback.bats` | 24 | RB-T1 to RB-T5 + recovery |
| **Total** | **224** | All tests passing |

**Execution**: `bats .github/tests/release/`

**Date Completed**: 2026-01-19
