# mdbook-htmx

Helm chart for deploying an HTMX-enhanced documentation backend for MDBook.

## Overview

This chart deploys a documentation server optimized for MDBook content with HTMX enhancements for dynamic navigation and search capabilities.

## Installation

```bash
# From Helm repository
helm install docs arustydev/mdbook-htmx

# From OCI registry
helm install docs oci://ghcr.io/arustydev/charts/mdbook-htmx

# With custom values
helm install docs arustydev/mdbook-htmx -f values.yaml
```

## Prerequisites

- Kubernetes 1.19+
- Helm 3.8+

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Container image | `nginx` |
| `image.tag` | Image tag | `alpine` |
| `service.type` | Service type | `ClusterIP` |
| `service.port` | Service port | `80` |
| `ingress.enabled` | Enable ingress | `false` |

### Security Context

The chart runs with security best practices by default:

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 101
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

### Example values.yaml

```yaml
replicaCount: 2

image:
  repository: nginx
  tag: alpine
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: docs.example.com
      paths:
        - path: /
          pathType: Prefix

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi
```

## Features

### Phase-Based Implementation

This chart is designed for progressive enhancement:

| Phase | Feature | Default |
|-------|---------|---------|
| 1 | Basic deployment | Enabled |
| 2 | HTMX fragment routing | Enabled |
| 3 | OAuth2 Proxy sidecar | Disabled |
| 4 | Meilisearch integration | Disabled |
| 5 | HPA, PDB, metrics | Disabled |

### Enabling Optional Features

```yaml
# Phase 3: Authentication
auth:
  enabled: true
  oauth2Proxy:
    provider: github

# Phase 4: Search
search:
  enabled: true
  meilisearch:
    persistence:
      enabled: true
      size: 1Gi

# Phase 5: Production hardening
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10

podDisruptionBudget:
  enabled: true
  minAvailable: 1
```

## Content Management

### Using ConfigMap for Book Content

```yaml
configMap:
  enabled: true
  data:
    index.html: |
      <!DOCTYPE html>
      <html>...</html>
```

### Using Persistent Volume

```yaml
persistence:
  enabled: true
  size: 1Gi
  storageClass: standard
```

## Health Checks

The chart configures health probes on `/health`:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 10

readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
```

## Uninstallation

```bash
helm uninstall docs
```

## Links

- [MDBook Documentation](https://rust-lang.github.io/mdBook/)
- [HTMX Documentation](https://htmx.org/)
- [Chart Source](https://github.com/aRustyDev/helm-charts/tree/main/charts/mdbook-htmx)
