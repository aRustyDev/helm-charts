# Installation Methods

Charts are distributed via multiple endpoints for redundancy and flexibility.

## Method 1: GitHub Pages (Primary)

The traditional Helm repository hosted on GitHub Pages.

```bash
helm repo add arustydev https://arustydev.github.io/helm-charts
helm repo update
helm install my-release arustydev/<chart-name>
```

**Pros:**
- Standard Helm workflow
- `helm search` support
- Familiar to most users

**Cons:**
- Requires `helm repo add` setup
- Repository must be updated manually

## Method 2: Cloudflare Pages (Mirror)

Identical content hosted on Cloudflare's edge network.

```bash
helm repo add arustydev https://charts.arusty.dev
helm repo update
helm install my-release arustydev/<chart-name>
```

**Pros:**
- Global CDN distribution
- Faster in some regions
- Redundancy if GitHub is down

**Cons:**
- Same workflow as GitHub Pages

## Method 3: OCI Registry (Modern)

Direct installation from GitHub Container Registry using OCI artifacts.

```bash
# No repo add required
helm install my-release oci://ghcr.io/arustydev/charts/<chart-name>

# With specific version
helm install my-release oci://ghcr.io/arustydev/charts/<chart-name> --version 1.0.0

# Pull chart locally
helm pull oci://ghcr.io/arustydev/charts/<chart-name> --version 1.0.0
```

**Pros:**
- No repository setup
- Immutable versions
- Better caching
- Native container registry integration

**Cons:**
- Requires Helm 3.8+
- No `helm search` (must know chart name)
- Different syntax

## Choosing a Method

| Use Case | Recommended Method |
|----------|-------------------|
| Standard Kubernetes cluster | GitHub Pages |
| Air-gapped environment | OCI (pull and push to internal registry) |
| GitOps (ArgoCD, Flux) | OCI or GitHub Pages |
| CI/CD pipelines | OCI (simpler, no repo setup) |
| Browsing available charts | GitHub Pages (supports search) |

## Version Pinning

Always pin versions in production:

```bash
# Helm repository
helm install my-release arustydev/<chart-name> --version 1.0.0

# OCI registry
helm install my-release oci://ghcr.io/arustydev/charts/<chart-name> --version 1.0.0
```
