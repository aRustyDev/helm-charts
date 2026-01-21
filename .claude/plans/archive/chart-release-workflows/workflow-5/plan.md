# Workflow 5: Validate & SemVer Bump - Phase Plan

## Overview
**Trigger**: `pull_request` → `main` branch (from `integration/<chart>` branches)
**Purpose**: Verify attestation lineage, bump version, run per-chart checks, generate overall attestation

---

## Relevant Skills

Load these skills before planning, research, or implementation:

| Skill | Path | Relevance |
|-------|------|-----------|
| **CI/CD GitHub Actions** | `~/.claude/skills/cicd-github-actions-dev/SKILL.md` | Attestation actions, matrix builds for K8s testing, gh CLI patterns |
| **Helm Chart Development** | `~/.claude/skills/k8s-helm-charts-dev/SKILL.md` | Chart.yaml versioning, ct install configuration, KinD clusters |
| **GitHub App Development** | `~/.claude/skills/github-app-dev/SKILL.md` | If elevated permissions needed for version bump commits |

**How to load**: Read the SKILL.md files at the start of implementation to access patterns and best practices.

---

### Check Distribution: W5 Is the Per-Chart Gate

W5 is the primary location for **per-chart specific validation** because:
- PRs come from `integration/<chart>` branches with isolated, single-chart changes
- Expensive checks benefit from targeted context
- Security findings are directly actionable for the release candidate
- Attestations generated here are tied to the specific chart version

**Current Checks (Implemented)**:
- Attestation chain verification
- SemVer version bump (via release-please)
- **K8s Compatibility Matrix Testing** (moved from W1 - deploys to KinD clusters)

**Future Checks (Out of Scope for initial implementation)**:
- Security scanning (Trivy, Kubesec)
- SBOM generation (Syft/Anchore)
- License compliance checking
- Chart-specific integration tests (beyond K8s compat)

See [W2 Plan: Check Distribution Strategy](../workflow-2/plan.md#architectural-note-check-distribution-strategy) for the full breakdown.

---

## Prerequisites

### Shared Components Required (Build First)
- [x] `extract_attestation_map` shell function (implemented in attestation-lib.sh)
- [x] `verify_attestation_chain` shell function (implemented in attestation-lib.sh)
- [x] `update_attestation_map` shell function (implemented in attestation-lib.sh)

### Infrastructure Required
- [ ] `main-protection` ruleset configured
- [ ] release-please configuration files
- [ ] GitHub App token for pushing version bump

### Upstream Dependencies
- [x] Workflow 2 creates the PRs this workflow validates (W2 pushes to `integration/<chart>` and creates PR to main)

---

## Implementation Phases

### Phase 5.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: None

**Tasks**:
1. Create `.github/workflows/validate-semver-bump.yaml`
2. Configure trigger for `pull_request` → `main` with path filter `charts/**`
3. Set up permissions (contents: write, pull-requests: write, id-token: write, attestations: write)
4. Add concurrency control to prevent race conditions on same PR
5. Add source branch validation (must be `integration/<chart>`)

**Code**:
```yaml
name: W5 - Validate & SemVer Bump

on:
  pull_request:
    branches:
      - main
    paths:
      - 'charts/**'

permissions:
  contents: write
  pull-requests: write
  id-token: write
  attestations: write

concurrency:
  group: w5-validate-${{ github.event.pull_request.number }}
  cancel-in-progress: false
```

**Source Branch Validation** (add to first job):
```bash
# Validate PR comes from integration/<chart> branch
HEAD_REF="${{ github.head_ref }}"
if [[ ! "$HEAD_REF" =~ ^integration/[a-z0-9-]+$ ]]; then
  echo "::error::PR must come from integration/<chart> branch, got: $HEAD_REF"
  exit 1
fi
CHART="${HEAD_REF#integration/}"
echo "chart=$CHART" >> "$GITHUB_OUTPUT"
```

**Deliverable**: Workflow triggers on PR to main with chart changes, validates source branch

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

### Phase 5.3a: K8s Compatibility Matrix Testing (Moved from W1)
**Effort**: Medium
**Dependencies**: Phase 5.1, Phase 5.5 (Chart Detection)
**Status**: Moved from W1 to provide per-chart targeted testing

**Rationale for Move**:
- **Expensive operation**: Deploys to actual KinD clusters (slow)
- **Per-chart focus**: W5 validates a single chart, making tests more targeted
- **Resource efficiency**: Only test the specific chart being released, not all changed charts
- **Clearer failure attribution**: Failures are directly tied to the release candidate

**Architecture Decision**: W1 keeps `ct lint` (fast, broad), W5 gets `ct install` (slow, targeted).

**Tasks**:
1. Set up matrix strategy for K8s versions
2. Create KinD cluster for each version
3. Run `ct install` for the specific chart
4. Generate attestation for each K8s version test
5. Update attestation map

**Code**:
```yaml
k8s-install-test:
  name: k8s-install (${{ matrix.k8s_version }})
  needs: [detect-chart]
  runs-on: ubuntu-latest
  strategy:
    matrix:
      include:
        - k8s_version: v1.32.11
          node_image: kindest/node:v1.32.11@sha256:5fc52d52a7b9574015299724bd68f183702956aa4a2116ae75a63cb574b35af8
        - k8s_version: v1.33.7
          node_image: kindest/node:v1.33.7@sha256:d26ef333bdb2cbe9862a0f7c3803ecc7b4303d8cea8e814b481b09949d353040
        - k8s_version: v1.34.3
          node_image: kindest/node:v1.34.3@sha256:08497ee19eace7b4b5348db5c6a1591d7752b164530a36f855cb0f2bdcbadd48
    fail-fast: false
  steps:
    - name: Checkout
      uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Set up Helm
      uses: azure/setup-helm@v4
      with:
        version: v3.14.0

    - name: Set up chart-testing
      uses: helm/chart-testing-action@v2.8.0

    - name: Create KinD cluster
      uses: helm/kind-action@v1.13.0
      with:
        node_image: ${{ matrix.node_image }}

    - name: Run chart-testing (install)
      run: |
        # Install only the specific chart for this release
        # Note: Charts requiring external services are excluded via ct-install.yaml
        ct install \
          --config ct-install.yaml \
          --charts "charts/${{ needs.detect-chart.outputs.chart }}"

    - name: Generate test digest
      id: digest
      run: |
        # Create a digest of the test results for attestation
        DIGEST=$(echo -n "${{ matrix.k8s_version }}-${{ github.sha }}" | sha256sum | cut -d' ' -f1)
        echo "digest=sha256:$DIGEST" >> "$GITHUB_OUTPUT"

    - name: Generate attestation
      id: attestation
      uses: actions/attest-build-provenance@v2
      with:
        subject-name: "w5-k8s-install-${{ matrix.k8s_version }}"
        subject-digest: ${{ steps.digest.outputs.digest }}
        push-to-registry: false

    - name: Update attestation map
      env:
        GH_TOKEN: ${{ github.token }}
        PR_NUMBER: ${{ github.event.pull_request.number }}
      run: |
        source .github/scripts/attestation-lib.sh
        update_attestation_map \
          "k8s-install-${{ matrix.k8s_version }}" \
          "${{ steps.attestation.outputs.attestation-id }}"
```

**Attestations Generated**:
| Check | Subject Name | Notes |
|-------|--------------|-------|
| K8s Install (1.32) | `w5-k8s-install-v1.32.11` | Deployment test on K8s 1.32 |
| K8s Install (1.33) | `w5-k8s-install-v1.33.7` | Deployment test on K8s 1.33 |
| K8s Install (1.34) | `w5-k8s-install-v1.34.3` | Deployment test on K8s 1.34 |

---

### Phase 5.4: Per-Chart Security Checks (FUTURE - OUT OF SCOPE)
**Status**: Placeholder for future implementation
**Effort**: N/A for initial implementation
**Dependencies**: Phase 5.1

**Architectural Decision**: This is where per-chart security checks belong. NOT in W1.

**Rationale**:
1. **Isolated context**: Single chart per PR means targeted scanning
2. **Release candidate focus**: Security attestations tied to specific version
3. **Actionable findings**: Reviewer can address issues before merge to main
4. **SBOM accuracy**: Bill of materials reflects exact chart content

**Future Implementation**:
```yaml
# Phase 5.4a: Security Scanning
- name: Run Trivy vulnerability scan
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'config'
    scan-ref: 'charts/${{ env.CHART }}'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy results
  uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: 'trivy-results.sarif'

# Phase 5.4b: Kubesec Analysis
- name: Run Kubesec scan
  run: |
    helm template charts/${{ env.CHART }} | kubesec scan - > kubesec-results.json
    # Fail if critical issues found
    if jq -e '.[] | select(.score < 0)' kubesec-results.json; then
      echo "::error::Critical security issues found"
      exit 1
    fi

# Phase 5.4c: SBOM Generation
- name: Generate SBOM
  uses: anchore/sbom-action@v0
  with:
    path: 'charts/${{ env.CHART }}'
    format: 'spdx-json'
    output-file: 'sbom.spdx.json'

- name: Attest SBOM
  uses: actions/attest-sbom@v2
  with:
    subject-path: 'charts/${{ env.CHART }}'
    sbom-path: 'sbom.spdx.json'

# Phase 5.4d: License Compliance
- name: Check license compliance
  run: |
    # Scan for license issues in chart dependencies
    # Implementation depends on chosen tool (e.g., FOSSA, Snyk, etc.)
    echo "::notice::License compliance check placeholder"
```

**Attestations Generated** (future):
| Check | Subject Name | Notes |
|-------|--------------|-------|
| Trivy scan | `w5-trivy-<chart>` | Vulnerability scan results |
| Kubesec scan | `w5-kubesec-<chart>` | K8s security best practices |
| SBOM | `w5-sbom-<chart>` | Software bill of materials |
| License | `w5-license-<chart>` | License compliance |

---

### Phase 5.5: Chart Detection
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

### Phase 5.6: Version Bump Determination
**Effort**: Medium
**Dependencies**: Phase 5.5, release-please config

**Existing Release-Please Configuration**:

This repo already has release-please manifest mode configured:

```
release-please-config.json    # Per-chart package definitions
.release-please-manifest.json # Version tracking per chart
```

Config structure:
```json
{
  "packages": {
    "charts/<chart-name>": {
      "release-type": "helm",
      "package-name": "<chart-name>",
      "changelog-path": "CHANGELOG.md",
      "bump-minor-pre-major": true
    }
  },
  "separate-pull-requests": true
}
```

**Integration Approach**:

Since release-please is designed to run on the default branch (main) and create its own PRs, W5 uses a **hybrid approach**:

1. **Primary**: Parse conventional commits in the PR to determine bump type
2. **Fallback**: Default to patch bump if no conventional commit markers found

**Tasks**:
1. Analyze commits in PR for conventional commit patterns
2. Determine bump type: major (breaking), minor (feat), patch (fix/chore)
3. Calculate new version based on current version + bump type
4. Validate new version doesn't already exist (idempotent)

**Code**:
```bash
# Get current version
CURRENT_VERSION=$(grep '^version:' "charts/$CHART/Chart.yaml" | awk '{print $2}')

# Analyze commits for bump type
COMMITS=$(git log origin/main..HEAD --pretty=format:"%s")

# Determine bump type from conventional commits
if echo "$COMMITS" | grep -qE '^[a-z]+(\([^)]+\))?!:'; then
  BUMP_TYPE="major"
elif echo "$COMMITS" | grep -qE '^feat(\([^)]+\))?:'; then
  BUMP_TYPE="minor"
else
  BUMP_TYPE="patch"
fi

# Calculate new version (semver increment)
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"
case "$BUMP_TYPE" in
  major) NEW_VERSION="$((major + 1)).0.0" ;;
  minor) NEW_VERSION="${major}.$((minor + 1)).0" ;;
  patch) NEW_VERSION="${major}.${minor}.$((patch + 1))" ;;
esac

echo "Bump: $BUMP_TYPE ($CURRENT_VERSION → $NEW_VERSION)"
```

**Note**: This approach keeps W5 decoupled from release-please's PR creation flow while maintaining compatibility with the manifest tracking. When W5 bumps the version, release-please will recognize it's already released and skip that chart.

**Answered Questions**:
- [x] Can release-please run on a non-default branch? → No, it's designed for default branch only
- [x] How to get version bump without creating PR? → Use conventional commit parsing directly
- [x] What if no bump needed? → Always bump patch minimum (chart changes = new version)

---

### Phase 5.7: Apply Version Bump
**Effort**: Medium
**Dependencies**: Phase 5.6, GitHub App token

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

### Phase 5.8: Generate Attestations
**Effort**: High
**Dependencies**: Phase 5.3, Phase 5.7

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

### Phase 5.9: Status Check Registration
**Effort**: Low
**Dependencies**: Phase 5.8

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
│ Workflow 2 creates   │
│ PR to main (from     │
│ integration/<chart>) │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 5.1: Base      │
│ Workflow + Source    │
│ Branch Validation    │
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
│Phase 5.3│ │Phase 5.5    │
│Verify   │ │Chart        │
│Chain    │ │Detection    │
└────┬────┘ └──────┬──────┘
     │             │
     │             ▼
     │      ┌─────────────┐
     │      │Phase 5.3a   │
     │      │K8s Compat   │
     │      │Matrix Test  │
     │      └──────┬──────┘
     │             │
     └──────┬──────┘
            ▼
┌──────────────────────┐
│ Phase 5.6: Version   │
│ Bump Determination   │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ Phase 5.7: Apply     │
│ Version Bump         │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ Phase 5.8: Generate  │
│ Attestations         │
└──────────┬───────────┘
           ▼
┌──────────────────────┐
│ Phase 5.9: Status    │
│ Check Registration   │
└──────────────────────┘
```

**Note**: Phase 5.4 (Security Checks) is marked as FUTURE and not included in the initial implementation flow.

---

## Open Questions

### Answered

1. **Attestation Verification**: What does `gh attestation verify` actually check?
   > **Answer**: `gh attestation verify` checks SLSA provenance signatures against Sigstore's public transparency log (Rekor). It verifies:
   > - The attestation was signed by GitHub Actions
   > - The signature is valid and not tampered
   > - The subject (artifact) matches the attestation
   > - The attestation was created in the expected repository

2. **Token Permissions**: Can GITHUB_TOKEN push to PR branches?
   > **Answer**: Yes, if the PR is from the same repository (not a fork) and the workflow has `contents: write` permission. For PRs from forks, elevated permissions via GitHub App token are required.

3. **release-please Integration**: How to get version without creating PR?
   > **Answer**: Release-please is designed for default branch only. W5 uses conventional commit parsing directly to determine the version bump type, then calculates the new version manually. See Phase 5.6.

4. **Concurrent Runs**: How to handle multiple workflow runs on same PR?
   > **Answer**: Concurrency control is configured in Phase 5.1 with `group: w5-validate-${{ github.event.pull_request.number }}` and `cancel-in-progress: false` to queue runs rather than cancel them.

5. **No Bump Needed**: What if release-please determines no version change?
   > **Answer**: Chart changes always require a version bump (minimum patch). This is enforced by W5 - if a chart is modified, it gets versioned.

6. **Failed Verification**: What happens if attestation verification fails?
   > **Answer**: Failure blocks merge entirely for security. If attestation verification fails, the workflow exits with error and the PR cannot be merged until the issue is resolved.

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
