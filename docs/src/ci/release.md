# Release Charts Workflow

**File:** `.github/workflows/release-please.yaml` (release-charts job)

**Trigger:** When Release Please creates a release (`releases_created == 'true'`)

## Overview

This job runs after Release Please creates a GitHub release. It publishes charts to multiple targets with comprehensive signing:

1. **GitHub Releases + Charts Branch** - via chart-releaser
2. **Sign GitHub Release assets** - Cosign blob signatures uploaded to releases
3. **GHCR / GitHub Packages** - OCI artifacts pushed to container registry
4. **Sign GHCR artifacts** - Cosign keyless signing for OCI images
5. **Build attestations** - SLSA provenance for all packages

## Publishing Targets

### GitHub Releases

Each chart version gets a GitHub Release with:
- Packaged chart (`.tgz` file)
- Cosign signature (`.tgz.sig` file)

```bash
# Download from GitHub Release
gh release download <chart>-<version> --repo aRustyDev/helm-charts
```

### GitHub Pages (Helm Repository)

Charts are published to the `charts` branch and served via GitHub Pages:

```bash
helm repo add arustydev https://arustydev.github.io/helm-charts
helm repo update
helm install my-release arustydev/<chart>
```

### GHCR / GitHub Packages (OCI Registry)

Charts are pushed as OCI artifacts with Cosign signatures:

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

**All artifacts are signed** using Sigstore keyless signing:

#### Verify GHCR OCI Artifacts

```bash
cosign verify ghcr.io/arustydev/charts/<chart>:<version> \
  --certificate-identity-regexp="https://github.com/aRustyDev/helm-charts/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

#### Verify GitHub Release Assets

```bash
# Download chart and signature
gh release download <chart>-<version> --repo aRustyDev/helm-charts

# Verify signature
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
  contents: write      # Push to charts branch, create releases
  packages: write      # Push to GHCR
  id-token: write      # Sigstore OIDC keyless signing
  attestations: write  # GitHub build attestations
```

## Workflow Summary

After each release, the workflow generates a summary table showing:

| Chart | Version | GitHub Release | GHCR | Signed |
|-------|---------|----------------|------|--------|
| chart-name | x.y.z | Link | Link | ✅ |

This confirms all publishing targets were updated and signed.
