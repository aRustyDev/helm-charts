# aRustyDev Helm Charts

Welcome to the documentation for aRustyDev's Helm chart repository.

## Available Charts

| Chart | Description |
|-------|-------------|
| [holmes](./charts/holmes.md) | OLM (Operator Lifecycle Manager) for Kubernetes |
| [mdbook-htmx](./charts/mdbook-htmx.md) | HTMX-enhanced documentation backend for MDBook |

## Distribution Endpoints

Charts are available via three endpoints:

| Endpoint | URL | Type |
|----------|-----|------|
| GitHub Pages | `https://arustydev.github.io/helm-charts` | Helm repository |
| Cloudflare Pages | `https://charts.arusty.dev` | Helm repository |
| GitHub Container Registry | `oci://ghcr.io/arustydev/charts` | OCI registry |

## Quick Start

```bash
# Option 1: Traditional Helm repository
helm repo add arustydev https://arustydev.github.io/helm-charts
helm install my-release arustydev/<chart-name>

# Option 2: OCI registry (Helm 3.8+)
helm install my-release oci://ghcr.io/arustydev/charts/<chart-name>
```

## Source Code

- **Repository**: [github.com/aRustyDev/helm-charts](https://github.com/aRustyDev/helm-charts)
- **Charts**: Located in `charts/` directory on `main` branch
- **Packages**: Published to `charts` branch and GHCR on release
