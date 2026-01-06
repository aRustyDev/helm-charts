# Release Charts Workflow

**File:** `.github/workflows/release-please.yaml` (release-charts job)

**Trigger:** When Release Please creates a release (`releases_created == 'true'`)

## Overview

This job runs after Release Please creates a GitHub release. It:
1. Packages charts using chart-releaser
2. Updates the Helm repository index
3. Pushes OCI artifacts to GHCR
4. Signs artifacts with Cosign
5. Generates build attestations

## Publishing Targets

### GitHub Pages (Helm Repository)

Charts are published to the `charts` branch and served via GitHub Pages:

```bash
helm repo add arustydev https://arustydev.github.io/helm-charts
helm repo update
helm install my-release arustydev/<chart>
```

### GHCR (OCI Registry)

Charts are also pushed as OCI artifacts:

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

All OCI artifacts are signed using Sigstore keyless signing:

```bash
cosign verify ghcr.io/arustydev/charts/<chart>:<version> \
  --certificate-identity-regexp="https://github.com/aRustyDev/helm-charts/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
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
  contents: write      # Push to charts branch
  packages: write      # Push to GHCR
  id-token: write      # Sigstore OIDC
  attestations: write  # GitHub attestations
```
