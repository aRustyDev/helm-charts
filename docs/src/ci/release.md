# Release Charts Workflow

**File:** `.github/workflows/release-please.yaml` (release-charts job)

**Trigger:** When Release Please merges a release PR (`releases_created == 'true'`)

## Overview

This job runs after Release Please creates a GitHub release. It publishes charts to all distribution channels with signing:

1. **GitHub Releases** - Chart `.tgz` packages with `.sig` signatures
2. **Charts Branch** - Helm repository index for GitHub/Cloudflare Pages
3. **GHCR** - OCI artifacts signed with Cosign
4. **Build Attestations** - SLSA provenance for all packages

## Publishing Targets

### GitHub Releases

Each chart version gets a GitHub Release with:
- `<chart>-<version>.tgz` - The packaged chart
- `<chart>-<version>.tgz.sig` - Cosign blob signature

### Helm Repository (GitHub Pages)

Charts are published to the `charts` branch and served via GitHub Pages:

```bash
helm repo add arustydev https://arustydev.github.io/helm-charts
helm repo update
helm install my-release arustydev/<chart>
```

### GHCR (OCI Registry)

Charts are pushed as OCI artifacts to GitHub Container Registry:

```bash
helm pull oci://ghcr.io/arustydev/charts/<chart> --version <version>
helm install my-release oci://ghcr.io/arustydev/charts/<chart> --version <version>
```

### Cloudflare Pages (Mirror)

The `charts` branch is also deployed to Cloudflare Pages:

```bash
helm repo add arustydev https://charts.arusty.dev
```

## Security

### Cosign Signing

**All releases are signed:**

| Target | Signature Type | Verification |
|--------|---------------|--------------|
| GitHub Release `.tgz` | Blob signature (`.sig` file) | `cosign verify-blob` |
| GHCR OCI artifact | Container signature | `cosign verify` |

### Verify GHCR Signature

```bash
cosign verify ghcr.io/arustydev/charts/<chart>:<version> \
  --certificate-identity-regexp="https://github.com/aRustyDev/helm-charts/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

### Verify GitHub Release Signature

```bash
# Download chart and signature
gh release download <chart>-<version> -p "*.tgz" -p "*.sig"

# Verify
cosign verify-blob \
  --signature <chart>-<version>.tgz.sig \
  --certificate-identity-regexp="https://github.com/aRustyDev/helm-charts/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  <chart>-<version>.tgz
```

### Build Attestations

SLSA provenance attestations are generated for all chart packages:

```bash
gh attestation verify <chart>-<version>.tgz --owner aRustyDev
```

See [Chart Verification](../security/verification.md) for detailed instructions.

## Permissions Required

```yaml
permissions:
  contents: write      # GitHub Releases, charts branch
  packages: write      # Push to GHCR
  id-token: write      # Sigstore OIDC keyless signing
  attestations: write  # GitHub attestations
```

## Manual Republish

To manually republish charts to GHCR (e.g., after fixing a signing issue):

```bash
gh workflow run publish-ghcr.yaml -f charts=all -f sign=true
```
