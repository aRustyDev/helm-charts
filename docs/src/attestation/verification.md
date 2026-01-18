# Verification Methods

This page documents how to verify Helm charts from each distribution channel.

## Prerequisites

Install verification tools:

```bash
# Cosign (for OCI signature verification)
brew install cosign
# or: go install github.com/sigstore/cosign/v2/cmd/cosign@latest

# GitHub CLI (for attestation verification)
brew install gh
gh auth login
```

## Verification by Distribution Channel

### GHCR (OCI Registry) - Recommended

Charts at `oci://ghcr.io/arustydev/helm-charts/<chart>` have both Cosign signatures and build attestations.

#### Quick Verify

```bash
CHART="cloudflared"
VERSION="1.0.0"

cosign verify "ghcr.io/arustydev/helm-charts/${CHART}:${VERSION}" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "github.com/aRustyDev/helm-charts"
```

#### Strict Verify (Specific Workflow)

```bash
cosign verify "ghcr.io/arustydev/helm-charts/${CHART}:${VERSION}" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity "https://github.com/aRustyDev/helm-charts/.github/workflows/release-atomic-chart.yaml@refs/heads/main"
```

#### View Signature Details

```bash
# See the signature tree (signatures, attestations, SBOMs)
cosign tree "ghcr.io/arustydev/helm-charts/${CHART}:${VERSION}"

# Extract detailed claims
cosign verify "ghcr.io/arustydev/helm-charts/${CHART}:${VERSION}" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp ".*" \
  -o json | jq '.[].optional'
```

#### What GHCR Verification Proves

| Check | Confidence | Details |
|-------|------------|---------|
| Signature valid | High | Cryptographic proof artifact matches signer |
| OIDC issuer matches | High | Signed by GitHub Actions (not local machine) |
| Certificate identity matches | High | Signed by our specific workflow |
| Rekor transparency log | High | Signature recorded publicly, auditable |

### GitHub Releases

Packages attached to GitHub Releases (`<chart>-<version>.tgz`) have build attestations.

#### Quick Verify

```bash
CHART="cloudflared"
VERSION="1.0.0"
TAG="${CHART}-v${VERSION}"

# Download package
gh release download "$TAG" \
  --repo aRustyDev/helm-charts \
  --pattern "${CHART}-${VERSION}.tgz"

# Verify attestation
gh attestation verify "${CHART}-${VERSION}.tgz" \
  --repo aRustyDev/helm-charts
```

#### Detailed Verification with JSON Output

```bash
gh attestation verify "${CHART}-${VERSION}.tgz" \
  --repo aRustyDev/helm-charts \
  --format json | jq '.attestations[].verificationResult'
```

#### Verify Blob Signature

Each release also includes a Cosign blob signature (`.sig` file):

```bash
# Download signature
gh release download "$TAG" \
  --repo aRustyDev/helm-charts \
  --pattern "${CHART}-${VERSION}.tgz.sig"

# Verify using Cosign
cosign verify-blob "${CHART}-${VERSION}.tgz" \
  --signature "${CHART}-${VERSION}.tgz.sig" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "github.com/aRustyDev/helm-charts"
```

#### What GitHub Release Verification Proves

| Check | Confidence | Details |
|-------|------------|---------|
| Attestation valid | High | Package matches attested digest |
| Repository matches | High | Built in this repository |
| Workflow recorded | High | Built by release-atomic-chart.yaml |
| Commit SHA recorded | High | Can trace to exact source |

### charts.arusty.dev (Helm Repository)

The Helm repository at `https://charts.arusty.dev` serves an `index.yaml` that points to GitHub Releases.

**Important**: The Helm repository itself does not provide attestations. Verification happens after download.

#### Install and Verify

```bash
CHART="cloudflared"
VERSION="1.0.0"

# Add repo
helm repo add arustydev https://charts.arusty.dev
helm repo update

# Pull chart (downloads .tgz)
helm pull arustydev/${CHART} --version ${VERSION}

# Verify the downloaded package against GitHub attestations
gh attestation verify "${CHART}-${VERSION}.tgz" \
  --repo aRustyDev/helm-charts
```

#### What charts.arusty.dev Verification Proves

| Check | Confidence | Details |
|-------|------------|---------|
| Package matches index | Medium | SHA in index.yaml matches downloaded file |
| After gh attestation verify | High | Same as GitHub Release verification |

**Note**: The `index.yaml` file is served from the `release` branch and is not cryptographically signed. Trust comes from the GitHub Release attestation, not the Helm repository index.

## Verification Comparison Table

| Channel | Attestation Available | Verification Method | Confidence |
|---------|----------------------|---------------------|------------|
| GHCR (OCI) | Cosign + Build Provenance | `cosign verify` | Highest |
| GitHub Release | Build Provenance + .sig | `gh attestation verify` | High |
| charts.arusty.dev | None (via GH Release) | Download, then `gh attestation verify` | High* |

*Requires extra step to download and verify

## Automated Verification

### CI/CD Pipeline Example

```yaml
- name: Verify and Install Chart
  run: |
    CHART="cloudflared"
    VERSION="1.0.0"

    # Verify before install
    cosign verify "ghcr.io/arustydev/helm-charts/${CHART}:${VERSION}" \
      --certificate-oidc-issuer https://token.actions.githubusercontent.com \
      --certificate-identity-regexp "github.com/aRustyDev/helm-charts"

    # Install from verified OCI registry
    helm install my-release "oci://ghcr.io/arustydev/helm-charts/${CHART}" \
      --version "${VERSION}"
```

### Kubernetes Admission Policy (Kyverno)

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-helm-charts
spec:
  validationFailureAction: Enforce
  background: false
  rules:
    - name: verify-signature
      match:
        any:
          - resources:
              kinds:
                - Pod
      verifyImages:
        - imageReferences:
            - "ghcr.io/arustydev/helm-charts/*"
          attestors:
            - entries:
                - keyless:
                    issuer: "https://token.actions.githubusercontent.com"
                    subjectRegExp: ".*github.com/aRustyDev/helm-charts.*"
```

## Troubleshooting

### "no matching signatures" Error

```bash
# Check if signatures exist
cosign tree ghcr.io/arustydev/helm-charts/cloudflared:1.0.0

# Verify with relaxed identity (for debugging)
cosign verify ghcr.io/arustydev/helm-charts/cloudflared:1.0.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp ".*"
```

### Attestation Not Found

```bash
# List available attestations
gh api "/repos/aRustyDev/helm-charts/attestations" \
  --jq '.attestations | map(.bundle.dsseEnvelope.payloadType)'

# Check release assets
gh release view cloudflared-v1.0.0 --repo aRustyDev/helm-charts
```

### Wrong Version Tag

```bash
# List available tags in GHCR
crane ls ghcr.io/arustydev/helm-charts/cloudflared

# List GitHub releases
gh release list --repo aRustyDev/helm-charts
```

## Next Steps

- [Lineage Tracing](./lineage.md) - Trace complete provenance chain
- [Limitations](./limitations.md) - Understand what attestations don't prove
