# Workflow 8: Atomic Release Publishing - Phase Plan

## Overview
**Trigger**: `push` → `release` branch (with changes to `charts/**`)
**Purpose**: Publish charts to GHCR and GitHub Releases with signatures and attestations

---

## Relevant Skills

Load these skills before planning, research, or implementation:

| Skill | Path | Relevance |
|-------|------|-----------|
| **CI/CD GitHub Actions** | `~/.claude/skills/cicd-github-actions-dev/SKILL.md` | GHCR publishing, artifact handling, GitHub Releases API |
| **Helm Chart Development** | `~/.claude/skills/k8s-helm-charts-dev/SKILL.md` | Chart packaging, OCI registry push patterns |

**How to load**: Read the SKILL.md files at the start of implementation to access patterns and best practices.

---

## Prerequisites

### Shared Components Required (Build First)
- [x] `detect_changed_charts` shell function (implemented in attestation-lib.sh)
- [x] `extract_attestation_map` shell function (implemented in attestation-lib.sh)
- [x] `get_source_pr` shell function (implemented in attestation-lib.sh)
- [x] `extract_changelog_for_version` shell function (implemented in attestation-lib.sh)

### Infrastructure Required
- [x] `release-branch-protection` ruleset configured (ID: 11884271)
- [x] GHCR access configured (standard with `packages: write` permission)
- [x] Cosign keyless signing enabled (standard with `id-token: write` permission)
- [x] GitHub App for pushing to protected release branch (via 1Password)

### Upstream Dependencies
- [x] Workflow 7 validates and builds chart packages (triggers this workflow on merge)
- [x] Tags exist for charts being released (created by W6)

### Key Assumptions
- **Single chart per merge**: Each release PR contains exactly ONE chart (enforced by W6/W7)
- **Three distribution channels**:
  1. **GHCR (OCI)**: `helm pull oci://ghcr.io/<owner>/charts/<chart>`
  2. **GitHub Releases**: Assets for direct download
  3. **index.yaml**: Updated on release branch for `helm repo add`

---

## Implementation Phases

### Phase 8.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: None

**Tasks**:
1. Create `.github/workflows/atomic-release-publishing.yaml`
2. Configure trigger for `push` → `release` with path filter `charts/**`
3. Set up permissions (contents: write, packages: write, id-token: write, attestations: write)

**Deliverable**: Workflow triggers on merge to release branch

---

### Phase 8.2: Setup Phase
**Effort**: Low
**Dependencies**: Phase 8.1

**Tasks**:
1. Checkout with full history
2. Set up Helm CLI
3. Install Cosign
4. Login to GHCR

**Code**:
```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0

- uses: azure/setup-helm@v4
  with:
    version: v3.14.0

- uses: sigstore/cosign-installer@v3

- uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}
```

---

### Phase 8.3: Chart Detection
**Effort**: Low
**Dependencies**: Phase 8.1, `get_source_pr`

**Note**: Each merge contains exactly ONE chart (enforced by W6/W7). Extract chart info from the merge commit message.

**Tasks**:
1. Extract chart name and version from merge commit message (format: `release: <chart>-v<version>`)
2. Validate chart exists in `charts/` directory
3. Construct tag name

**Code**:
```bash
# Get merge commit message
COMMIT_MSG=$(git log -1 --format="%s" HEAD)

# Extract from "Merge pull request #X from ... release: <chart>-v<version>"
# Or direct merge commit "release: <chart>-v<version>"
if [[ "$COMMIT_MSG" =~ release:\ ([a-z0-9-]+)-v([0-9]+\.[0-9]+\.[0-9]+.*) ]]; then
  CHART="${BASH_REMATCH[1]}"
  VERSION="${BASH_REMATCH[2]}"
elif [[ "$COMMIT_MSG" =~ Merge\ pull\ request ]]; then
  # Fallback: detect from changed files
  CHART=$(git diff --name-only HEAD~1..HEAD | grep '^charts/' | cut -d'/' -f2 | sort -u | head -1)
  VERSION=$(grep '^version:' "charts/$CHART/Chart.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
fi

TAG="${CHART}-v${VERSION}"

# Validate
if [[ ! -d "charts/$CHART" ]]; then
  echo "::error::Chart directory not found: charts/$CHART"
  exit 1
fi

echo "chart=$CHART" >> "$GITHUB_OUTPUT"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "tag=$TAG" >> "$GITHUB_OUTPUT"
```

---

### Phase 8.4: Attestation Lineage Retrieval
**Effort**: Medium
**Dependencies**: Phase 8.3, `extract_attestation_map`, `get_source_pr`

**Note**: Single chart - extract attestation map from the merged PR or tag annotation.

**Tasks**:
1. Find the PR that was merged (from merge commit)
2. Extract attestation map from PR description (W7 added it)
3. Also extract from tag annotation (W6 added it)
4. Store combined lineage for release assets

**Code**:
```bash
source .github/scripts/attestation-lib.sh

TAG="${{ steps.detect-chart.outputs.tag }}"

# Get PR number from merge commit
PR_NUMBER=$(get_source_pr HEAD)

ATTESTATION_MAP="{}"
if [[ -n "$PR_NUMBER" ]]; then
  # Extract from PR description (includes W7 build attestation)
  ATTESTATION_MAP=$(extract_attestation_map "$PR_NUMBER")
fi

# Also get attestation lineage from tag annotation (upstream attestations from W5)
TAG_ANNOTATION=$(git tag -l --format='%(contents)' "$TAG")
TAG_ATTESTATIONS=$(echo "$TAG_ANNOTATION" | sed -n '/^Attestation Lineage:/,/^$/p' | grep '^- ' || true)

echo "attestation_map=$ATTESTATION_MAP" >> "$GITHUB_OUTPUT"
echo "tag_attestations<<EOF" >> "$GITHUB_OUTPUT"
echo "$TAG_ATTESTATIONS" >> "$GITHUB_OUTPUT"
echo "EOF" >> "$GITHUB_OUTPUT"
```

---

### Phase 8.5: Build Chart Package
**Effort**: Low
**Dependencies**: Phase 8.3

**Note**: Single chart - rebuild package for consistency (simpler than downloading W7 artifacts).

**Tasks**:
1. Build chart package with `helm package`
2. Calculate SHA256 digest
3. Store in `.cr-release-packages/`

**Code**:
```bash
CHART="${{ steps.detect-chart.outputs.chart }}"
VERSION="${{ steps.detect-chart.outputs.version }}"

mkdir -p .cr-release-packages

helm package "charts/$CHART" -d .cr-release-packages/

PACKAGE_FILE=".cr-release-packages/${CHART}-${VERSION}.tgz"
DIGEST=$(sha256sum "$PACKAGE_FILE" | cut -d' ' -f1)

echo "package=$PACKAGE_FILE" >> "$GITHUB_OUTPUT"
echo "digest=sha256:$DIGEST" >> "$GITHUB_OUTPUT"
echo "package_name=${CHART}-${VERSION}.tgz" >> "$GITHUB_OUTPUT"
```

---

### Phase 8.6: Publish to GHCR
**Effort**: High
**Dependencies**: Phase 8.2, Phase 8.5

**Note**: Single chart - push to GHCR OCI registry and sign with Cosign keyless.

**Tasks**:
1. Push chart package to GHCR OCI registry
2. Capture digest from push output
3. Sign package with Cosign (keyless)
4. Handle push failures with retry (3 attempts)

**Code**:
```bash
CHART="${{ steps.detect-chart.outputs.chart }}"
VERSION="${{ steps.detect-chart.outputs.version }}"
PACKAGE="${{ steps.build-package.outputs.package }}"
REGISTRY="ghcr.io/${{ github.repository_owner }}/charts"

# Convert to lowercase (GHCR requirement)
REGISTRY="${REGISTRY,,}"

MAX_RETRIES=3
RETRY_DELAY=5

for ((attempt=1; attempt<=MAX_RETRIES; attempt++)); do
  echo "::group::Pushing to GHCR (attempt $attempt/$MAX_RETRIES)"

  if PUSH_OUTPUT=$(helm push "$PACKAGE" "oci://$REGISTRY" 2>&1); then
    echo "$PUSH_OUTPUT"
    OCI_DIGEST=$(echo "$PUSH_OUTPUT" | grep -oP 'Digest: \Ksha256:[a-f0-9]+' || true)

    if [[ -n "$OCI_DIGEST" ]]; then
      echo "::notice::Pushed $CHART:$VERSION to GHCR"
      echo "::notice::OCI Digest: $OCI_DIGEST"
      break
    fi
  fi

  echo "::warning::Push attempt $attempt failed"
  echo "$PUSH_OUTPUT"

  if [[ $attempt -lt $MAX_RETRIES ]]; then
    echo "Retrying in ${RETRY_DELAY}s..."
    sleep $RETRY_DELAY
    RETRY_DELAY=$((RETRY_DELAY * 2))
  else
    echo "::error::Failed to push to GHCR after $MAX_RETRIES attempts"
    exit 1
  fi
  echo "::endgroup::"
done

# Sign with Cosign (keyless via OIDC)
echo "::group::Signing with Cosign"
cosign sign --yes "$REGISTRY/$CHART@$OCI_DIGEST"
echo "::notice::Signed $CHART@$OCI_DIGEST"
echo "::endgroup::"

echo "oci_digest=$OCI_DIGEST" >> "$GITHUB_OUTPUT"
echo "oci_url=$REGISTRY/$CHART:$VERSION" >> "$GITHUB_OUTPUT"
```

**Resolved Questions**:
- ✅ **Verify push succeeded**: Check exit code and presence of digest in output
- ✅ **Retry strategy**: 3 retries with exponential backoff (5s, 10s, 20s)
- ✅ **Existing versions**: `helm push` fails if version exists - this is correct (immutable versions)

---

### Phase 8.7: Create GitHub Release
**Effort**: High
**Dependencies**: Phase 8.4, Phase 8.5, Phase 8.6

**Note**: Single chart - create one release with all assets.

**Tasks**:
1. Check if release exists (by tag) - skip if already exists (idempotent)
2. Sign package blob for file signature (.tgz.sig)
3. Create attestation lineage JSON file
4. Create GitHub Release with assets:
   - Chart package (.tgz)
   - Package signature (.tgz.sig)
   - Attestation lineage JSON
   - CHANGELOG.md (if exists)
   - README.md (if exists)

**Code**:
```bash
CHART="${{ steps.detect-chart.outputs.chart }}"
VERSION="${{ steps.detect-chart.outputs.version }}"
TAG="${{ steps.detect-chart.outputs.tag }}"
PACKAGE="${{ steps.build-package.outputs.package }}"
DIGEST="${{ steps.build-package.outputs.digest }}"
OCI_DIGEST="${{ steps.publish-ghcr.outputs.oci_digest }}"
ATTESTATION_MAP='${{ steps.attestation-lineage.outputs.attestation_map }}'

# Check if release already exists
if gh release view "$TAG" >/dev/null 2>&1; then
  echo "::notice::Release $TAG already exists, skipping creation"
  echo "release_url=$(gh release view "$TAG" --json url -q '.url')" >> "$GITHUB_OUTPUT"
  exit 0
fi

# Sign package blob
echo "::group::Signing package blob"
cosign sign-blob --yes --output-signature "${PACKAGE}.sig" "$PACKAGE"
echo "::endgroup::"

# Create attestation lineage file
cat > "${CHART}-attestation-lineage.json" <<EOF
{
  "chart": "$CHART",
  "version": "$VERSION",
  "tag": "$TAG",
  "package_digest": "$DIGEST",
  "oci_digest": "$OCI_DIGEST",
  "attestations": $ATTESTATION_MAP,
  "published_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Collect assets
ASSETS=("$PACKAGE" "${PACKAGE}.sig" "${CHART}-attestation-lineage.json")

# Add optional assets if they exist
[[ -f "charts/$CHART/CHANGELOG.md" ]] && ASSETS+=("charts/$CHART/CHANGELOG.md")
[[ -f "charts/$CHART/README.md" ]] && ASSETS+=("charts/$CHART/README.md")

# Generate release notes
RELEASE_NOTES=$(generate_release_notes "$CHART" "$VERSION" "$TAG" "$OCI_DIGEST")

# Create release
gh release create "$TAG" \
  --title "$CHART v$VERSION" \
  --notes "$RELEASE_NOTES" \
  "${ASSETS[@]}"

echo "::notice::Created release: $TAG"
echo "release_url=$(gh release view "$TAG" --json url -q '.url')" >> "$GITHUB_OUTPUT"
```

---

### Phase 8.8: Generate Release Notes
**Effort**: Medium
**Dependencies**: Phase 8.4, `extract_changelog_for_version`

**Note**: Generate comprehensive release notes with installation and verification instructions.

**Tasks**:
1. Extract changelog from chart's CHANGELOG.md
2. Include attestation lineage summary
3. Include installation instructions (GHCR OCI + helm repo)
4. Include verification commands (Cosign + gh attestation)

**Code**:
```bash
generate_release_notes() {
  local chart="$1"
  local version="$2"
  local tag="$3"
  local oci_digest="$4"

  source .github/scripts/attestation-lib.sh

  # Get changelog
  local changelog
  changelog=$(extract_changelog_for_version "$chart" "$version")

  cat <<EOF
## $chart v$version

### Changelog

$changelog

### Installation

\`\`\`bash
# Option 1: From GHCR (OCI) - Recommended
helm install $chart oci://ghcr.io/${{ github.repository_owner }}/charts/$chart --version $version

# Option 2: From Helm Repository
helm repo add arustydev https://charts.arusty.dev
helm repo update
helm install $chart arustydev/$chart --version $version
\`\`\`

### Verification

\`\`\`bash
# Verify OCI signature with Cosign
cosign verify ghcr.io/${{ github.repository_owner }}/charts/$chart@$oci_digest

# Verify attestations
gh attestation verify oci://ghcr.io/${{ github.repository_owner }}/charts/$chart:$version --repo ${{ github.repository }}
\`\`\`

### Attestation Lineage

See \`$chart-attestation-lineage.json\` in release assets for full attestation chain.

---
*Released by W8: Atomic Release Publishing*
EOF
}
```

---

### Phase 8.9: Update Helm Repository Index
**Effort**: Medium
**Dependencies**: Phase 8.7

**Note**: This is CRITICAL for GitHub Pages distribution via charts.arusty.dev.

**Tasks**:
1. Checkout release branch
2. Copy package to release branch root (or use GitHub Releases URL)
3. Update index.yaml with `helm repo index`
4. Commit and push to release branch (requires GitHub App token)

**Code**:
```bash
CHART="${{ steps.detect-chart.outputs.chart }}"
VERSION="${{ steps.detect-chart.outputs.version }}"
TAG="${{ steps.detect-chart.outputs.tag }}"
PACKAGE="${{ steps.build-package.outputs.package }}"
PACKAGE_NAME="${{ steps.build-package.outputs.package_name }}"

# Configure git with App token for push
git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

# Fetch release branch
git fetch origin release

# Create temporary worktree for release branch
git worktree add ../release-branch origin/release

cd ../release-branch

# Copy package (or we can rely on GitHub Releases URL)
# The index.yaml already points to GitHub Releases URLs, so we just need to update the index

# Update index.yaml using helm repo index
# --url points to GitHub Releases download URL
# --merge merges with existing index
helm repo index . \
  --url "https://github.com/${{ github.repository }}/releases/download" \
  --merge index.yaml

# Commit and push
git add index.yaml
git commit -m "chore(release): update index.yaml for $CHART v$VERSION

Tag: $TAG
Release: https://github.com/${{ github.repository }}/releases/tag/$TAG"

git push origin HEAD:release

# Cleanup worktree
cd ..
git worktree remove release-branch

echo "::notice::Updated index.yaml on release branch"
```

**Important**: This requires the GitHub App token to push to the protected release branch.

---

### Phase 8.10: Summary Generation
**Effort**: Low
**Dependencies**: All previous phases

**Tasks**:
1. Generate GitHub Step Summary
2. Include chart details and links
3. Include GHCR URL and GitHub Release URL
4. Include verification commands

---

## File Structure

```
.github/
├── workflows/
│   └── atomic-release-publishing.yaml    # Main workflow
└── scripts/
    └── attestation-lib.sh                # Shared functions
```

---

## Dependencies Graph

```
┌──────────────────────┐
│ W7 merges PR to      │
│ release branch       │
└──────────┬───────────┘
           │ (triggers push event)
           ▼
┌──────────────────────┐
│ Phase 8.1: Base      │
│ Workflow             │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 8.2: Setup     │
│ (Helm, Cosign, GHCR) │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 8.3: Chart     │
│ Detection (single)   │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌──────────┐ ┌──────────┐
│ 8.4      │ │ 8.5      │
│ Attest   │ │ Build    │
│ Lineage  │ │ Package  │
└────┬─────┘ └────┬─────┘
     │            │
     └──────┬─────┘
            ▼
┌──────────────────────┐
│ Phase 8.6: Publish   │
│ to GHCR + Cosign     │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 8.7: Create    │
│ GitHub Release       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 8.9: Update    │
│ index.yaml           │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 8.10: Summary  │
└──────────────────────┘
```

---

## Open Questions

1. ✅ **GHCR Overwrite**: What if version already exists in GHCR?
   - **Resolved**: `helm push` fails if version exists - this is correct behavior (immutable versions)
   - If this happens, it indicates a workflow error (version should only be published once)

2. ✅ **Release Exists**: Update existing release or fail?
   - **Resolved**: Skip creation if release exists (idempotent behavior)
   - Log notice and output existing release URL

3. ✅ **Missing Assets**: What if CHANGELOG or README missing?
   - **Resolved**: These are optional - only include if they exist
   - Core assets (package, signature, attestation JSON) are always included

4. ✅ **Retry Strategy**: How many retries for GHCR push?
   - **Resolved**: 3 retries with exponential backoff (5s, 10s, 20s)

5. ✅ **Cosign Keyless**: Any additional configuration needed?
   - **Resolved**: Works out of the box with `id-token: write` permission
   - Uses GitHub Actions OIDC for keyless signing

6. ✅ **Package Source**: Rebuild or use W7 artifacts?
   - **Resolved**: Rebuild in W8 for simplicity and reliability
   - W7 artifacts have 30-day retention and may not be available

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| GHCR push fails | High | 3 retries with exponential backoff |
| Cosign signing fails | High | Workflow fails - signing is required |
| Release creation fails | Medium | Check for existing first (idempotent) |
| index.yaml push fails | High | GitHub App token for protected branch |
| Version already in GHCR | Medium | Expected failure - indicates duplicate release attempt |
| Network timeouts | Medium | Retry logic, reasonable timeouts |

---

## Success Criteria

- [ ] Workflow triggers on push to release branch (merge from main)
- [ ] Detects single chart from merge commit
- [ ] Retrieves attestation lineage from merged PR and tag
- [ ] Builds chart package successfully
- [ ] Pushes to GHCR OCI registry
- [ ] Signs OCI artifact with Cosign (keyless)
- [ ] Creates GitHub Release with assets:
  - [ ] Chart package (.tgz)
  - [ ] Package signature (.tgz.sig)
  - [ ] Attestation lineage JSON
  - [ ] CHANGELOG.md (if exists)
  - [ ] README.md (if exists)
- [ ] Release notes include installation and verification instructions
- [ ] Updates index.yaml on release branch
- [ ] Summary shows chart details and links
- [ ] Workflow completes in < 10 minutes (single chart)
