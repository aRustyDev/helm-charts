# ADR 004: Helm Chart Signing and Provenance

## Status

Accepted

## Date

2026-01-06

## Context

Supply chain security is critical for Helm charts distributed via public registries. Users need to verify that charts:
1. Were built by the expected CI/CD pipeline
2. Haven't been tampered with since publication
3. Come from a trusted source

Traditional approaches use GPG keys, which require key management overhead. Modern approaches use keyless signing with OIDC identity providers.

## Decision

We will implement **Sigstore Cosign keyless signing** combined with **GitHub Artifact Attestations** for SLSA provenance.

### Why Cosign Keyless?

- **No key management**: Uses OIDC identity from GitHub Actions
- **Transparency**: Signatures recorded in Rekor transparency log
- **Verifiable identity**: Tied to GitHub workflow identity, not a potentially compromised key
- **Industry standard**: Used by Kubernetes, Sigstore, and major CNCF projects

### Why GitHub Attestations?

- **SLSA provenance**: Provides build provenance metadata
- **Native integration**: Built into GitHub Actions
- **Sigstore-backed**: Uses same Sigstore infrastructure
- **Verifiable**: Can be verified with `gh attestation verify`

## Implementation

### Signed Artifacts

| Artifact | Location | Signing Method |
|----------|----------|----------------|
| OCI Chart | `ghcr.io/arustydev/charts/<name>:<version>` | Cosign keyless |
| Chart Package | GitHub Release `.tgz` | GitHub Attestation |

### Workflow Changes

```yaml
permissions:
  contents: write
  packages: write
  id-token: write      # For Sigstore OIDC
  attestations: write  # For GitHub attestations
```

### Verification Commands

```bash
# Verify OCI chart signature
cosign verify ghcr.io/arustydev/charts/holmes:0.1.0 \
  --certificate-identity-regexp="https://github.com/aRustyDev/helm-charts/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"

# Verify GitHub attestation
gh attestation verify holmes-0.1.0.tgz --owner aRustyDev
```

## Consequences

### Positive

- Users can cryptographically verify chart authenticity
- No secrets to manage or rotate
- Audit trail via Rekor transparency log
- Aligns with SLSA framework requirements

### Negative

- Requires users to install `cosign` for OCI verification
- Slightly longer CI pipeline (signing step)
- Dependency on Sigstore infrastructure availability

### Neutral

- Traditional GPG `.prov` files not generated (superseded by Cosign)
- Users must trust GitHub's OIDC identity claims

## References

- [Sigstore Cosign](https://github.com/sigstore/cosign)
- [GitHub Artifact Attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds)
- [SLSA Framework](https://slsa.dev/)
- [Helm Chart Keyless Signing](https://tech.aabouzaid.com/2023/08/helm-chart-keyless-signing-with-sigstore-cosign.html)
