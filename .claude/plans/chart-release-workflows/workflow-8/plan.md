# Workflow 8: Atomic Release Publishing - Phase Plan

## Overview
**Trigger**: `push` → `release` branch (with changes to `charts/**`)
**Purpose**: Publish charts to GHCR and GitHub Releases with signatures and attestations

---

## Prerequisites

### Shared Components Required (Build First)
- [ ] `detect_changed_charts` shell function
- [ ] `extract_attestation_map` shell function

### Infrastructure Required
- [ ] `release-protection` ruleset configured
- [ ] GHCR access configured
- [ ] Cosign keyless signing enabled

### Upstream Dependencies
- [ ] Workflow 7 must have merged the PR (triggers this workflow)
- [ ] Tags must exist for charts being released

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
**Dependencies**: Phase 8.1, `detect_changed_charts`

**Tasks**:
1. Detect charts changed in this merge
2. Get version for each chart
3. Construct tag names

---

### Phase 8.4: Attestation Lineage Retrieval
**Effort**: Medium
**Dependencies**: Phase 8.3, `extract_attestation_map`

**Tasks**:
1. Find the PR that was merged
2. Extract full attestation map
3. Store for release assets

---

### Phase 8.5: Build Chart Packages
**Effort**: Low
**Dependencies**: Phase 8.3

**Tasks**:
1. Build/rebuild chart packages
2. Calculate digests
3. Store in temporary directory

**Note**: May use artifacts from W7 or rebuild for consistency

---

### Phase 8.6: Publish to GHCR
**Effort**: High
**Dependencies**: Phase 8.2, Phase 8.5

**Tasks**:
1. For each chart:
   - Run `helm push` to GHCR OCI registry
   - Capture digest from output
   - Sign package with Cosign (keyless)
2. Handle push failures with retry

**Code**:
```bash
REGISTRY="ghcr.io/${GITHUB_REPOSITORY_OWNER,,}/charts"

for chart in $CHARTS; do
  VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
  TGZ=".cr-release-packages/${chart}-${VERSION}.tgz"

  # Push to GHCR
  PUSH_OUTPUT=$(helm push "$TGZ" oci://$REGISTRY 2>&1)
  DIGEST=$(echo "$PUSH_OUTPUT" | grep -oP 'Digest: \Ksha256:[a-f0-9]+')

  # Sign by digest
  cosign sign --yes "$REGISTRY/${chart}@${DIGEST}"
done
```

**Questions**:
- [ ] How to verify push succeeded?
- [ ] Retry strategy for transient failures?
- [ ] How to handle existing versions in registry?

---

### Phase 8.7: Create GitHub Releases
**Effort**: High
**Dependencies**: Phase 8.4, Phase 8.5, Phase 8.6

**Tasks**:
1. For each chart:
   - Check if release exists (by tag)
   - If not, create release
   - Upload assets:
     - Chart package (.tgz)
     - Package signature (.tgz.sig)
     - Attestation lineage JSON
     - CHANGELOG.md
     - README.md
     - LICENSE

**Code**:
```bash
for chart in $CHARTS; do
  VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
  TAG="${chart}-v${VERSION}"
  TGZ=".cr-release-packages/${chart}-${VERSION}.tgz"

  # Sign blob for file signature
  cosign sign-blob --yes --output-signature "${TGZ}.sig" "$TGZ"

  # Create attestation lineage file
  cat > "${chart}-attestation-lineage.json" <<EOF
  {
    "chart": "$chart",
    "version": "$VERSION",
    "tag": "$TAG",
    "digest": "$DIGEST",
    "attestations": $ATTESTATION_MAP
  }
  EOF

  # Create release
  gh release create "$TAG" \
    --title "$chart: v$VERSION" \
    --notes "$(generate_release_notes)" \
    "$TGZ" \
    "${TGZ}.sig" \
    "${chart}-attestation-lineage.json" \
    "charts/$chart/CHANGELOG.md" \
    "charts/$chart/README.md" \
    "charts/$chart/LICENSE"
done
```

---

### Phase 8.8: Generate Release Notes
**Effort**: Medium
**Dependencies**: Phase 8.4

**Tasks**:
1. Extract changelog from tag annotation or file
2. Include attestation verification commands
3. Include installation instructions

**Release Notes Template**:
```markdown
## <chart> v<version>

### Changelog
<changelog content>

### Attestation Lineage
<attestation IDs>

### Installation

```bash
# From GHCR (OCI)
helm install <chart> oci://ghcr.io/<owner>/charts/<chart> --version <version>

# Verify signature
cosign verify ghcr.io/<owner>/charts/<chart>:<version>
```

### Verification
```bash
# Verify attestations
gh attestation verify ghcr.io/<owner>/charts/<chart>@<digest>
```
```

---

### Phase 8.9: Summary Generation
**Effort**: Low
**Dependencies**: All previous phases

**Tasks**:
1. Generate GitHub Step Summary
2. Include table of released charts
3. Include links to GHCR and releases
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
│ Workflow 7 merges    │
│ PR to release        │
└──────────┬───────────┘
           │
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
     ┌─────┼─────┐
     ▼     ▼     ▼
┌──────┐ ┌──────┐ ┌──────────┐
│8.3   │ │8.4   │ │8.5       │
│Chart │ │Attest│ │Build     │
│Detect│ │Lineage│ │Packages  │
└──┬───┘ └──┬───┘ └────┬─────┘
   │        │          │
   └────────┼──────────┘
            ▼
┌──────────────────────┐
│ Phase 8.6: Publish   │
│ to GHCR              │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 8.7: Create    │
│ GitHub Releases      │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 8.9: Summary   │
└──────────────────────┘
```

---

## Open Questions

1. **GHCR Overwrite**: What if version already exists in GHCR?
2. **Release Exists**: Update existing release or fail?
3. **Missing Assets**: What if CHANGELOG or README missing?
4. **Retry Strategy**: How many retries for GHCR push?
5. **Cosign Keyless**: Any additional configuration needed?
6. **Package Source**: Rebuild or use W7 artifacts?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| GHCR push fails | High | Retry logic, clear errors |
| Cosign signing fails | High | Fallback to unsigned warning |
| Release creation fails | Medium | Check for existing first |
| Large package size | Low | Monitor package sizes |
| Network timeouts | Medium | Longer timeouts, retry |

---

## Success Criteria

- [ ] Workflow triggers on merge to release
- [ ] Charts are pushed to GHCR successfully
- [ ] Charts are signed with Cosign
- [ ] GitHub Releases are created with all assets
- [ ] Release notes include changelog and installation instructions
- [ ] Attestation lineage JSON is included in release
- [ ] Summary shows all released charts
- [ ] Workflow completes in < 15 minutes
