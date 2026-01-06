# mdbook-htmx Helm Chart

HTMX-enhanced documentation backend for MDBook.

## Installation

```bash
helm repo add arustydev https://charts.arusty.dev
helm install docs arustydev/mdbook-htmx
```

## Configuration

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of replicas | `1` |
| `image.repository` | Image repository | `nginx` |
| `image.tag` | Image tag | `alpine` |
| `htmx.enabled` | Enable HTMX features | `true` |
| `htmx.fragmentRouting` | Enable fragment routing | `true` |
| `auth.enabled` | Enable authentication | `false` |
| `search.enabled` | Enable search | `false` |
| `ingress.enabled` | Enable ingress | `false` |
| `autoscaling.enabled` | Enable HPA | `false` |

## Phases

This chart grows with mdbook-htmx implementation:

| Phase | Features |
|-------|----------|
| 1. Core | Static serving, health checks |
| 2. HTMX | Fragment routing, OOB swaps |
| 3. Auth | OAuth2 proxy sidecar |
| 4. Search | Meilisearch deployment |
| 5. Polish | HPA, PDB, metrics |

## Examples

### Basic Installation

```bash
helm install docs arustydev/mdbook-htmx \
  --set ingress.enabled=true \
  --set ingress.hosts[0].host=docs.example.com
```

### With Authentication

```bash
helm install docs arustydev/mdbook-htmx \
  --set auth.enabled=true \
  --set auth.oauth2Proxy.enabled=true \
  --set auth.oauth2Proxy.provider=github
```

### With Search

```bash
helm install docs arustydev/mdbook-htmx \
  --set search.enabled=true \
  --set search.meilisearch.enabled=true
```
