# Chart Verification

All charts published from this repository are cryptographically signed using [Sigstore Cosign](https://github.com/sigstore/cosign) keyless signing and include [GitHub Artifact Attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds) for SLSA provenance.

## Prerequisites

Install the verification tools:

```bash
# Install Cosign
brew install cosign
# or
go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# GitHub CLI (for attestation verification)
brew install gh
```

## Verify OCI Registry Charts

Charts pushed to GHCR (`oci://ghcr.io/arustydev/charts`) are signed with Cosign.

### Verify Signature

```bash
cosign verify ghcr.io/arustydev/charts/holmes:0.1.0 \
  --certificate-identity-regexp="https://github.com/aRustyDev/helm-charts/.github/workflows/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

### Expected Output

```
Verification for ghcr.io/arustydev/charts/holmes:0.1.0 --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The code-signing certificate was verified using trusted certificate authority certificates

[{"critical":{"identity":{"docker-reference":"ghcr.io/arustydev/charts/holmes"},...}]
```

### Verify with Policy

For stricter verification, check the exact workflow:

```bash
cosign verify ghcr.io/arustydev/charts/holmes:0.1.0 \
  --certificate-identity="https://github.com/aRustyDev/helm-charts/.github/workflows/release-please.yaml@refs/heads/main" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com"
```

## Verify GitHub Release Artifacts

Chart packages (`.tgz` files) attached to GitHub Releases have attestations.

### Download and Verify

```bash
# Download the chart package
gh release download holmes-v0.1.0 \
  --repo aRustyDev/helm-charts \
  --pattern "holmes-0.1.0.tgz"

# Verify attestation
gh attestation verify holmes-0.1.0.tgz --owner aRustyDev
```

### Expected Output

```
Loaded digest sha256:abc123... for file://holmes-0.1.0.tgz
Loaded 1 attestation from GitHub API
Verification succeeded!
```

## Verification in CI/CD

### GitHub Actions Example

```yaml
- name: Verify Chart Before Deploy
  run: |
    cosign verify ghcr.io/arustydev/charts/${{ env.CHART_NAME }}:${{ env.CHART_VERSION }} \
      --certificate-identity-regexp="https://github.com/aRustyDev/helm-charts/.github/workflows/.*" \
      --certificate-oidc-issuer="https://token.actions.githubusercontent.com"

    helm pull oci://ghcr.io/arustydev/charts/${{ env.CHART_NAME }} --version ${{ env.CHART_VERSION }}
```

### Kubernetes Admission Controller

For cluster-level enforcement, consider:
- [Kyverno](https://kyverno.io/) with Sigstore integration
- [Connaisseur](https://github.com/sse-secure-systems/connaisseur)
- [Sigstore Policy Controller](https://docs.sigstore.dev/policy-controller/overview/)

## Transparency Log

All signatures are recorded in the [Rekor](https://rekor.sigstore.dev/) transparency log. You can search for entries:

```bash
rekor-cli search --email "github-actions@github.com" \
  --artifact ghcr.io/arustydev/charts/holmes:0.1.0
```

## Troubleshooting

### "no matching signatures" Error

Ensure you're using the correct version tag and the chart was signed:

```bash
# List available tags
crane ls ghcr.io/arustydev/charts/holmes

# Check if signature exists
cosign tree ghcr.io/arustydev/charts/holmes:0.1.0
```

### Certificate Identity Mismatch

The workflow path in `--certificate-identity` must exactly match the workflow that signed the artifact. Check the signature details:

```bash
cosign verify ghcr.io/arustydev/charts/holmes:0.1.0 \
  --certificate-identity-regexp=".*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  -o json | jq '.[] | .optional'
```

## Security Considerations

- Signatures prove the artifact was built by our GitHub Actions workflows
- They do NOT prove the source code is free of vulnerabilities
- Always review chart contents and scan for CVEs before deployment
- Use tools like `trivy`, `grype`, or `snyk` for vulnerability scanning
