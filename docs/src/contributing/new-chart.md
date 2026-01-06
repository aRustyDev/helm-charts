# Creating a New Chart

This guide covers the process of adding a new Helm chart to the repository.

## Quick Start (Claude Code)

If using Claude Code, run the slash command:

```
/create-helm-chart
```

This will guide you through progressive chart development using git worktrees.

## Manual Process

### Step 1: Create Chart Scaffold

```bash
# Create from scratch
helm create charts/my-chart

# Or copy an existing chart as template
cp -r charts/mdbook-htmx charts/my-chart
```

### Step 2: Update Chart.yaml

```yaml
apiVersion: v2
name: my-chart
description: A brief description of my chart
type: application
version: 0.1.0
appVersion: "1.0.0"
home: https://github.com/aRustyDev/helm-charts
maintainers:
  - name: aRustyDev
    email: arustydev@proton.me
```

### Step 3: Configure values.yaml

Follow these conventions:

```yaml
# Replica count
replicaCount: 1

# Image configuration
image:
  repository: nginx
  tag: ""  # Defaults to appVersion
  pullPolicy: IfNotPresent

# Service configuration
service:
  type: ClusterIP
  port: 80

# Ingress (disabled by default)
ingress:
  enabled: false

# Resources (always define)
resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi

# Security context (always include)
securityContext:
  runAsNonRoot: true
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

### Step 4: Create Templates

Minimum required templates:

```
templates/
├── _helpers.tpl      # Template helpers
├── deployment.yaml   # Main workload
├── service.yaml      # Service exposure
└── serviceaccount.yaml
```

### Step 5: Add to Release-Please

Update `release-please-config.json`:

```json
{
  "packages": {
    "charts/my-chart": {
      "release-type": "helm",
      "package-name": "my-chart",
      "changelog-path": "CHANGELOG.md",
      "bump-minor-pre-major": true
    }
  }
}
```

Update `.release-please-manifest.json`:

```json
{
  "charts/my-chart": "0.1.0"
}
```

### Step 6: Test Locally

```bash
# Lint
helm lint charts/my-chart

# Render templates
helm template test charts/my-chart

# Install in test cluster
kind create cluster --name test
helm install test charts/my-chart
helm test test

# Cleanup
helm uninstall test
kind delete cluster --name test
```

### Step 7: Create PR

```bash
git checkout -b feat/chart-my-chart
git add charts/my-chart release-please-config.json .release-please-manifest.json
git commit -m "feat(my-chart): add initial helm chart"
git push -u origin feat/chart-my-chart
gh pr create
```

## Progressive Development

For complex charts, develop in stages:

| Stage | Scope | PR Title |
|-------|-------|----------|
| 1 | MVP: Deployment + Service | `feat(my-chart): add MVP helm chart` |
| 2 | ConfigMap/Secrets | `feat(my-chart): add configuration support` |
| 3 | Ingress | `feat(my-chart): add ingress support` |
| 4 | Probes | `feat(my-chart): add health probes` |
| 5 | Resources | `feat(my-chart): add resource limits` |
| 6 | Security | `feat(my-chart): add security context` |
| 7 | HPA | `feat(my-chart): add autoscaling` |
| 8 | PDB | `feat(my-chart): add pod disruption budget` |

## From Docker Compose

If migrating from docker-compose:

| Compose | Helm |
|---------|------|
| `image` | `values.yaml: image.repository/tag` |
| `ports` | `values.yaml: service.port` |
| `environment` | `values.yaml: env[]` or ConfigMap |
| `volumes` (config) | ConfigMap |
| `volumes` (data) | PVC |
| `healthcheck` | `livenessProbe/readinessProbe` |
| `deploy.replicas` | `values.yaml: replicaCount` |

## Chart Documentation

Every chart should have:

1. **README.md** in chart directory
2. **values.yaml** with inline comments
3. **Entry in docs/** for detailed usage

## Checklist

Before submitting PR:

- [ ] `helm lint` passes
- [ ] `helm template` renders correctly
- [ ] Chart installs in Kind cluster
- [ ] Values documented with comments
- [ ] Security context configured
- [ ] Resource limits defined
- [ ] Release-please config updated
- [ ] Documentation added to `docs/src/charts/`
