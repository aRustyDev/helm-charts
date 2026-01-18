# ADR-002: Multi-Endpoint Distribution

## Status

Accepted (Updated 2025-01-17)

## Context

Helm charts need to be accessible to users. We need to decide on distribution strategy:

1. **Single endpoint**: One hosting location (e.g., GitHub Releases only)
2. **Multiple endpoints**: Redundant hosting across platforms
3. **OCI-only**: Modern approach using container registries

### Considerations

- **Availability**: Single point of failure vs. redundancy
- **Performance**: CDN distribution for global users
- **Compatibility**: Traditional Helm repos vs. OCI registries
- **Maintenance**: More endpoints = more complexity

## Decision

Distribute charts via three channels:

| Channel | URL | Purpose |
|---------|-----|---------|
| GitHub Container Registry | `oci://ghcr.io/arustydev/helm-charts/<chart>` | Primary, OCI-native distribution |
| Helm Repository | `https://charts.arusty.dev` | Traditional Helm repo (CDN-backed) |
| GitHub Releases | `https://github.com/.../releases` | Direct download with signatures |

### Implementation

The `release-atomic-chart.yaml` workflow publishes to all channels:

```yaml
# Phase 3: Publish to all distribution channels
publish-releases:
  steps:
    # 1. Push to GHCR with Cosign signing
    - name: Publish to GHCR
      run: |
        helm push "$PACKAGE" "oci://$REGISTRY"
        cosign sign --yes "$REGISTRY/$CHART@$OCI_DIGEST"

    # 2. Create GitHub Release with .tgz and signature
    - name: Create GitHub Release
      run: |
        cosign sign-blob --yes --output-signature "${PACKAGE}.sig" "$PACKAGE"
        gh release create "$TAG" "$PACKAGE" "${PACKAGE}.sig"

# Phase 4: Update release branch (serves Helm repo via Cloudflare)
update-release-branch:
  steps:
    - run: |
        helm repo index . --merge index.yaml
        git push origin release
```

### Channel Details

**GHCR (OCI Registry)**
- Recommended for Helm 3.8+
- Cosign keyless signing for verification
- Native GitHub integration

**Helm Repository (`charts.arusty.dev`)**
- Served from `release` branch via Cloudflare Pages
- CDN for global performance
- Traditional `helm repo add` workflow

**GitHub Releases**
- Direct `.tgz` download
- Includes `.sig` signature file
- Attestation lineage JSON for provenance

## Consequences

### Positive

- **Redundancy**: If one channel is down, others remain available
- **Flexibility**: Users choose their preferred method (OCI vs traditional)
- **Performance**: Cloudflare CDN for faster global access
- **Modern support**: OCI for Helm 3.8+ users and GitOps tools
- **Verifiable**: All channels support signature verification

### Negative

- **Complexity**: Three channels to maintain and keep in sync
- **Documentation**: Users need to understand options

### Neutral

- All channels serve identical chart versions
- No additional cost (all services have free tiers)
- Single workflow handles all publishing automatically

## Usage Examples

```bash
# Option 1: OCI (Recommended)
helm install myrelease oci://ghcr.io/arustydev/helm-charts/cloudflared --version 0.4.2

# Option 2: Traditional Helm Repo
helm repo add arustydev https://charts.arusty.dev
helm repo update
helm install myrelease arustydev/cloudflared --version 0.4.2

# Verification
cosign verify ghcr.io/arustydev/helm-charts/cloudflared@sha256:...
gh attestation verify oci://ghcr.io/arustydev/helm-charts/cloudflared:0.4.2
```
