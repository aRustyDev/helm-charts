# aRustyDev Helm Charts

Helm charts repository with multiple distribution endpoints.

## Available Charts

| Chart | Description | Version |
|-------|-------------|---------|
| [holmes](./charts/olm) | OLM (Operator Lifecycle Manager) for Kubernetes | 0.1.0 |
| [mdbook-htmx](./charts/mdbook-htmx) | HTMX-enhanced documentation backend for MDBook | 0.1.0 |

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
helm install my-olm oci://ghcr.io/arustydev/charts/holmes --version 0.1.0
helm install my-docs oci://ghcr.io/arustydev/charts/mdbook-htmx --version 0.1.0
```

### Install a Chart

```bash
# From Helm repository
helm install my-olm arustydev/holmes
helm install my-docs arustydev/mdbook-htmx

# From OCI registry
helm install my-olm oci://ghcr.io/arustydev/charts/holmes
```

### Uninstall a Chart

```bash
helm delete my-olm
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