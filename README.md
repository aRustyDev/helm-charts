# aRustyDev Helm Charts

Helm charts repository with dual distribution endpoints.

## Available Charts

| Chart | Description | Version |
|-------|-------------|---------|
| [holmes](./charts/olm) | OLM (Operator Lifecycle Manager) for Kubernetes | 0.1.0 |
| [mdbook-htmx](./charts/mdbook-htmx) | HTMX-enhanced documentation backend for MDBook | 0.1.0 |

## Usage

[Helm](https://helm.sh) must be installed to use the charts. Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

### Add Repository

Choose either endpoint (both serve identical content):

```bash
# GitHub Pages (primary)
helm repo add arustydev https://arustydev.github.io/helm-charts

# Cloudflare Pages (mirror)
helm repo add arustydev https://charts.arusty.dev
```

### Update Repository

```bash
helm repo update
```

### Search Charts

```bash
helm search repo arustydev
```

### Install a Chart

```bash
# Install holmes (OLM)
helm install my-olm arustydev/holmes

# Install mdbook-htmx
helm install my-docs arustydev/mdbook-htmx
```

### Uninstall a Chart

```bash
helm delete my-olm
helm delete my-docs
```

## Contributing

Charts follow [conventional commits](https://www.conventionalcommits.org/) for automatic versioning:

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix(chart):` | Patch | `fix(holmes): correct service port` |
| `feat(chart):` | Minor | `feat(mdbook-htmx): add HPA support` |
| `feat(chart)!:` | Major | `feat(holmes)!: restructure values schema` |

## License

Apache-2.0