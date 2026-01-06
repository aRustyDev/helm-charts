# Development Guide

## Prerequisites

- [Helm](https://helm.sh) 3.14+
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [kind](https://kind.sigs.k8s.io/) or [minikube](https://minikube.sigs.k8s.io/)
- [chart-testing (ct)](https://github.com/helm/chart-testing)

## Repository Structure

```
helm-charts/
├── charts/                    # Chart source code
│   ├── olm/
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── templates/
│   │   └── crds/
│   └── mdbook-htmx/
├── docs/                      # Documentation (mdbook)
│   ├── book.toml
│   └── src/
├── .github/workflows/         # CI/CD pipelines
├── ct.yaml                    # chart-testing config
└── release-please-config.json # Versioning config
```

## Local Development

### Linting Charts

```bash
# Lint all charts
ct lint --all

# Lint specific chart
helm lint charts/my-chart
```

### Testing Charts

```bash
# Create local cluster
kind create cluster

# Test chart installation
ct install --all

# Or manually
helm install test charts/my-chart --dry-run
helm install test charts/my-chart
helm test test
helm uninstall test
```

### Template Rendering

```bash
# Render templates without installing
helm template my-release charts/my-chart

# With custom values
helm template my-release charts/my-chart -f values-test.yaml

# Show only specific template
helm template my-release charts/my-chart -s templates/deployment.yaml
```

## Commit Convention

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

| Type | Description | Version Bump |
|------|-------------|--------------|
| `feat` | New feature | Minor |
| `fix` | Bug fix | Patch |
| `docs` | Documentation | None |
| `style` | Formatting | None |
| `refactor` | Code restructure | None |
| `test` | Tests | None |
| `chore` | Maintenance | None |

### Scope

Use the chart name as scope:

```bash
feat(holmes): add horizontal pod autoscaler
fix(mdbook-htmx): correct service port
docs(holmes): update installation guide
```

### Breaking Changes

Add `!` after type or `BREAKING CHANGE:` in footer:

```bash
feat(holmes)!: restructure values schema

BREAKING CHANGE: `olmOperator` renamed to `olm.operator`
```

## Pull Request Workflow

1. **Create feature branch**
   ```bash
   git checkout -b feat/my-feature
   ```

2. **Make changes and commit**
   ```bash
   git add .
   git commit -m "feat(chart): add feature"
   ```

3. **Push and create PR**
   ```bash
   git push -u origin feat/my-feature
   gh pr create
   ```

4. **CI runs automatically**
   - Linting with chart-testing
   - Installation tests on Kind cluster
   - Matrix testing: K8s 1.28, 1.29, 1.30

5. **After merge, release-please creates release PR**

6. **Merge release PR to publish charts**

## Code Review Checklist

- [ ] Chart version bumped appropriately
- [ ] Values documented in values.yaml comments
- [ ] README updated if needed
- [ ] Templates follow Helm best practices
- [ ] Security contexts applied
- [ ] Resource limits defined
- [ ] Health probes configured
- [ ] Tests pass locally
