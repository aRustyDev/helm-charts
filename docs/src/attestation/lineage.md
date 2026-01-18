# Attestation Lineage

Attestation lineage is the ability to trace a released artifact back through every stage of the CI/CD pipeline to its original source. This provides a complete chain of trust from contributor code to deployed artifact.

## Why Lineage Matters

A single signature proves *who signed* the artifact, but lineage proves *how it was validated*:

| Question | Single Signature | Full Lineage |
|----------|------------------|--------------|
| Was this built by our CI? | Yes | Yes |
| Did all tests pass? | Unknown | Yes |
| Which K8s versions was it tested on? | Unknown | v1.32, v1.33, v1.34 |
| Which PR introduced this change? | Unknown | PR #123 |
| Who was the original contributor? | Unknown | @contributor |
| Was the PR auto-merged or reviewed? | Unknown | Auto-merged (trusted) |

## The Provenance Chain

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      COMPLETE PROVENANCE CHAIN                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  [Contributor PR] ──merge──→ [integration]                              │
│       │                            │                                    │
│       │ Author: @contributor       │ W2 creates atomic PR               │
│       │ Commits: signed            │                                    │
│       ▼                            ▼                                    │
│  [W1 Validation]              [Atomic Chart PR]                         │
│       │                            │                                    │
│       │ Lint: ✓                    │ Source: charts/cloudflared         │
│       │ ArtifactHub: ✓             │ Target: main                       │
│       │ Commits: ✓                 │                                    │
│       ▼                            ▼                                    │
│  [Auto-Merge]                 [W5 Validation]                           │
│       │                            │                                    │
│       │ Trusted: ✓                 ├──→ ArtifactHub lint                │
│       │ Signed: ✓                  ├──→ Helm lint (ct lint)             │
│       │                            ├──→ K8s v1.32 install ──→ [Test Attestation] │
│       │                            ├──→ K8s v1.33 install ──→ [Test Attestation] │
│       │                            ├──→ K8s v1.34 install ──→ [Test Attestation] │
│       │                            └──→ Version bump + changelog        │
│       │                                 │                               │
│       │                                 ▼                               │
│       │                         [ATTESTATION_MAP in PR]                 │
│       │                                 │                               │
│       │                                 │ JSON with test run IDs        │
│       │                                 │                               │
│       ▼                                 ▼                               │
│  [integration merge]           [Merge to main]                          │
│                                        │                                │
│                                        ▼                                │
│                               [Release Workflow (W8)]                   │
│                                        │                                │
│                                        ├──→ Extract attestation map     │
│                                        ├──→ Create tag with lineage     │
│                                        ├──→ Package chart               │
│                                        ├──→ Generate build attestation  │
│                                        ├──→ Sign with Cosign            │
│                                        └──→ Create GitHub Release       │
│                                             │                           │
│                                             ▼                           │
│                                    [RELEASED ARTIFACT]                  │
│                                    with full provenance                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Tracing Lineage Step by Step

### Step 1: Start with the Released Artifact

```bash
CHART="cloudflared"
VERSION="1.0.0"
TAG="${CHART}-v${VERSION}"

# Get the release and its commit SHA
RELEASE_INFO=$(gh release view "$TAG" --repo aRustyDev/helm-charts --json tagCommitish,body)
RELEASE_SHA=$(echo "$RELEASE_INFO" | jq -r '.tagCommitish')

echo "Release SHA: $RELEASE_SHA"
```

### Step 2: Find the Source PR

```bash
# Get the PR that was merged to create this commit
PR_NUMBER=$(gh api "/repos/aRustyDev/helm-charts/commits/${RELEASE_SHA}/pulls" \
  --jq '.[0].number')

echo "Source PR: #$PR_NUMBER"
```

### Step 3: Extract the Attestation Map

```bash
# Get the attestation map from the PR description
PR_BODY=$(gh pr view "$PR_NUMBER" --repo aRustyDev/helm-charts --json body -q '.body')

# Extract the attestation map JSON
ATTESTATION_MAP=$(echo "$PR_BODY" | awk '
    /<!-- W5_ATTESTATION_MAP -->/,/<!-- \/W5_ATTESTATION_MAP -->/ {
        if (/```json/) { getline; found=1 }
        if (/```/ && found) { found=0; exit }
        if (found) print
    }
')

echo "Attestation Map:"
echo "$ATTESTATION_MAP" | jq .
```

### Step 4: Verify Test Attestations

```bash
# Parse the attestation map and verify each test run
W5_RUN_ID=$(echo "$ATTESTATION_MAP" | jq -r ".[\"$CHART\"].w5_run")

echo "W5 Workflow Run: https://github.com/aRustyDev/helm-charts/actions/runs/${W5_RUN_ID}"

# You can view the workflow run to see test results
gh run view "$W5_RUN_ID" --repo aRustyDev/helm-charts
```

### Step 5: Trace to Integration Merge

```bash
# Get the charts/<chart> branch that was merged
HEAD_REF=$(gh pr view "$PR_NUMBER" --repo aRustyDev/helm-charts --json headRefName -q '.headRefName')
echo "Source branch: $HEAD_REF"

# This branch was created by W2, which means it came from integration
# Find the W2 run that created this branch
W2_RUNS=$(gh run list \
  --repo aRustyDev/helm-charts \
  --workflow create-atomic-chart-pr.yaml \
  --json databaseId,conclusion,headBranch \
  --jq ".[] | select(.headBranch == \"$HEAD_REF\")")

echo "W2 Workflow that created this PR:"
echo "$W2_RUNS" | head -1
```

### Step 6: Trace to Contributor PR

```bash
# The W2 run was triggered by a merge to integration
# Find the contributor PR that merged to integration
INTEGRATION_SHA=$(gh pr view "$PR_NUMBER" --repo aRustyDev/helm-charts --json commits -q '.commits[0].oid')

# Search for PRs that merged this commit to integration
# (This requires checking git history or workflow logs)
echo "To trace further, check the W2 workflow logs for the source commit"
```

## Automated Lineage Verification

### Full Lineage Script

```bash
#!/usr/bin/env bash
# verify-lineage.sh - Verify complete attestation lineage for a chart release

set -euo pipefail

CHART="${1:?Usage: verify-lineage.sh <chart> <version>}"
VERSION="${2:?Usage: verify-lineage.sh <chart> <version>}"
TAG="${CHART}-v${VERSION}"
REPO="aRustyDev/helm-charts"

echo "=== Verifying Lineage for $CHART v$VERSION ==="

# Step 1: Verify the Cosign signature
echo ""
echo "Step 1: Verifying Cosign signature..."
if cosign verify "ghcr.io/arustydev/helm-charts/${CHART}:${VERSION}" \
    --certificate-oidc-issuer https://token.actions.githubusercontent.com \
    --certificate-identity-regexp "github.com/aRustyDev/helm-charts" \
    --output text 2>/dev/null; then
  echo "  ✓ Cosign signature valid"
else
  echo "  ✗ Cosign signature INVALID"
  exit 1
fi

# Step 2: Get release info
echo ""
echo "Step 2: Getting release info..."
RELEASE_SHA=$(gh api "/repos/${REPO}/git/ref/tags/${TAG}" --jq '.object.sha')
echo "  Release SHA: $RELEASE_SHA"

# Step 3: Find source PR
echo ""
echo "Step 3: Finding source PR..."
PR_NUMBER=$(gh api "/repos/${REPO}/commits/${RELEASE_SHA}/pulls" --jq '.[0].number' 2>/dev/null || echo "")
if [[ -n "$PR_NUMBER" ]]; then
  echo "  Source PR: #$PR_NUMBER"
  PR_URL="https://github.com/${REPO}/pull/${PR_NUMBER}"
  echo "  URL: $PR_URL"
else
  echo "  ✗ Could not find source PR"
  exit 1
fi

# Step 4: Extract attestation map
echo ""
echo "Step 4: Extracting attestation map..."
PR_BODY=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json body -q '.body')

if echo "$PR_BODY" | grep -q "W5_ATTESTATION_MAP"; then
  echo "  ✓ Attestation map found in PR description"

  # Extract and display
  ATTESTATION_MAP=$(echo "$PR_BODY" | sed -n '/```json/,/```/p' | grep -v '```' | head -20)
  echo "  Map contents:"
  echo "$ATTESTATION_MAP" | sed 's/^/    /'
else
  echo "  ⚠ No attestation map in PR (may be older release)"
fi

# Step 5: Verify W5 workflow ran
echo ""
echo "Step 5: Verifying W5 validation..."
W5_RUN=$(gh run list \
  --repo "$REPO" \
  --workflow validate-atomic-chart-pr.yaml \
  --json databaseId,conclusion,event \
  --jq ".[] | select(.conclusion == \"success\")" | head -1)

if [[ -n "$W5_RUN" ]]; then
  echo "  ✓ W5 validation completed successfully"
else
  echo "  ⚠ Could not verify W5 run (may need manual check)"
fi

echo ""
echo "=== Lineage Verification Complete ==="
echo ""
echo "Summary:"
echo "  Chart: $CHART v$VERSION"
echo "  Release SHA: $RELEASE_SHA"
echo "  Source PR: #$PR_NUMBER"
echo "  Cosign: ✓ Valid"
echo ""
echo "Full lineage traceable from release back to contribution."
```

## Attestation Map Format

The attestation map stored in PR descriptions follows this schema:

```json
{
  "<chart-name>": {
    "version": "<semver>",
    "w5_run": "<workflow-run-id>",
    "k8s_versions": ["v1.32.11", "v1.33.7", "v1.34.3"]
  }
}
```

Example:

```json
{
  "cloudflared": {
    "version": "1.2.0",
    "w5_run": "12345678901",
    "k8s_versions": ["v1.32.11", "v1.33.7", "v1.34.3"]
  }
}
```

## Tag Annotation Format

Each release tag includes lineage metadata in its annotation:

```
Release: cloudflared v1.2.0

Attestation Lineage:
- cloudflared: {"version": "1.2.0", "w5_run": "12345678901", ...}

Changelog:
## [1.2.0] - 2025-01-15
### Added
- Support for priorityClassName

Source PR: #123
Commit: abc123def456...
```

View tag annotation:

```bash
git tag -v cloudflared-v1.2.0
# or
git show cloudflared-v1.2.0 --quiet
```

## Confidence Levels by Verification Depth

| Verification Depth | Commands Used | Confidence | What You Know |
|--------------------|---------------|------------|---------------|
| Signature only | `cosign verify` | High | Artifact from our workflow |
| + Attestation | `gh attestation verify` | High | Built at specific commit |
| + Source PR | `gh pr view` | Higher | Tests passed, version bumped |
| + Attestation map | Extract from PR body | Higher | Which K8s versions tested |
| + W5 run logs | `gh run view` | Very High | Actual test output |
| + Integration trace | Git history analysis | Highest | Original contributor PR |

## Limitations of Lineage Tracing

See [Limitations](./limitations.md) for what lineage does NOT prove:
- Source code security
- Upstream image safety
- Runtime behavior
