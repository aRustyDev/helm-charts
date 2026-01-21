# aRustyDev Helm Charts

Helm charts repository with multiple distribution endpoints.

## Available Charts

| Chart | Description |
|-------|-------------|
| [cloudflared](./charts/cloudflared) | Cloudflare Tunnel client for secure ingress |
| [mdbook-htmx](./charts/mdbook-htmx) | HTMX-enhanced documentation backend for MDBook |
| [olm](./charts/olm) | OLM (Operator Lifecycle Manager) for Kubernetes |

> Version information is available in each chart's `Chart.yaml` or via `helm search`.

## Usage

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

### Option 1: Helm Repository (Traditional)

```bash
# GitHub Pages (primary)
helm repo add arustydev https://arustydev.github.io/helm-charts

# Cloudflare Pages (mirror)
helm repo add arustydev https://charts.arusty.dev

# Update and search
helm repo update
helm search repo arustydev
```

### Option 2: OCI Registry (Modern)

No `helm repo add` required - reference charts directly:

```bash
# Install from GitHub Container Registry
helm install my-tunnel oci://ghcr.io/arustydev/charts/cloudflared
helm install my-docs oci://ghcr.io/arustydev/charts/mdbook-htmx
```

### Install a Chart

```bash
# From Helm repository
helm install my-tunnel arustydev/cloudflared
helm install my-docs arustydev/mdbook-htmx

# From OCI registry (with specific version)
helm install my-tunnel oci://ghcr.io/arustydev/charts/cloudflared --version 0.4.3
```

### Uninstall a Chart

```bash
helm delete my-tunnel
helm delete my-docs
```

## Distribution Endpoints

| Endpoint | URL | Type |
|----------|-----|------|
| GitHub Pages | `https://arustydev.github.io/helm-charts` | Helm repo |
| Cloudflare Pages | `https://charts.arusty.dev` | Helm repo |
| GitHub Container Registry | `oci://ghcr.io/arustydev/charts` | OCI registry |

## Documentation

See [docs/](./docs/) for:
- [Architecture Decision Records](./docs/src/adr/)
- [Chart Usage Guides](./docs/src/charts/)

## Contributing

Charts follow [conventional commits](https://www.conventionalcommits.org/) for automatic versioning:

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix(chart):` | Patch | `fix(holmes): correct service port` |
| `feat(chart):` | Minor | `feat(mdbook-htmx): add HPA support` |
| `feat(chart)!:` | Major | `feat(holmes)!: restructure values schema` |

## License

Apache-2.0