# Configuration Reference

Complete reference for cloudflared Helm chart values.

## Installation

```bash
helm install cloudflared ./charts/cloudflared \
  -n cloudflare --create-namespace \
  -f values.yaml
```

## Core Configuration

### Tunnel Secrets

```yaml
tunnelSecrets:
  # Option 1: Base64-encoded inline
  base64EncodedPemFile: ""        # base64 -i ~/.cloudflared/cert.pem
  base64EncodedConfigJsonFile: "" # base64 -i ~/.cloudflared/*.json

  # Option 2: Existing Kubernetes secrets (recommended)
  existingPemFileSecret:
    name: "cloudflared-cert"
    key: "cert.pem"
  existingConfigJsonFileSecret:
    name: "cloudflared-credentials"
    key: "credentials.json"
```

### Tunnel Configuration

```yaml
tunnelConfig:
  name: ""                      # Required: tunnel name from `cloudflared tunnel create`
  protocol: auto                # auto, http2, h2mux, quic
  logLevel: info                # debug, info, warn, error
  transportLogLevel: warn
  connectTimeout: 30s
  gracePeriod: 30s
  retries: 5
  noAutoUpdate: true
  autoUpdateFrequency: 24h
  metricsUpdateFrequency: 5s
  warpRouting: false            # Enable WARP client routing
```

## Ingress Rules

Route traffic from hostnames to Kubernetes services:

```yaml
ingress:
  # Route specific hostname to service
  - hostname: app.example.com
    service: http://app-service.default.svc.cluster.local:80

  # Route with path matching
  - hostname: api.example.com
    path: /v1/*
    service: http://api-v1.default.svc.cluster.local:8080

  - hostname: api.example.com
    path: /v2/*
    service: http://api-v2.default.svc.cluster.local:8080

  # Wildcard hostname
  - hostname: "*.example.com"
    service: http://default-backend.default.svc.cluster.local:80

  # Catch-all (required - must be last)
  - service: http_status:404
```

## Deployment Configuration

### Replica Mode

```yaml
replica:
  allNodes: true   # DaemonSet - one pod per node
  count: 1         # If allNodes=false, use Deployment with this replica count
```

### Resources

```yaml
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi
```

### Tolerations

Default allows scheduling on all nodes:

```yaml
tolerations:
  - effect: NoSchedule
    operator: Exists
```

For control-plane nodes only:

```yaml
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
```

### Node Selector

```yaml
nodeSelector:
  kubernetes.io/os: linux
  # Add custom labels
  node-type: edge
```

### Affinity

```yaml
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: cloudflared
          topologyKey: kubernetes.io/hostname
```

## Security Configuration

### Pod Security Context

```yaml
podSecurityContext:
  fsGroup: 65532
  fsGroupChangePolicy: "OnRootMismatch"
  sysctls:
    - name: net.ipv4.ping_group_range
      value: "0 2147483647"
```

### Container Security Context

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  privileged: false
  runAsUser: 65532
  runAsGroup: 65532
```

## Service Account

```yaml
serviceAccount:
  create: true
  automount: true
  annotations: {}
  name: ""  # Auto-generated if empty
```

## Full Example

```yaml
tunnelSecrets:
  existingConfigJsonFileSecret:
    name: cloudflared-credentials
    key: credentials.json
  existingPemFileSecret:
    name: cloudflared-cert
    key: cert.pem

tunnelConfig:
  name: homelab-tunnel
  protocol: quic
  logLevel: info

ingress:
  - hostname: grafana.example.com
    service: http://grafana.monitoring.svc.cluster.local:3000

  - hostname: argocd.example.com
    service: https://argocd-server.argocd.svc.cluster.local:443
    originRequest:
      noTLSVerify: true

  - hostname: "*.example.com"
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80

  - service: http_status:404

replica:
  allNodes: false
  count: 2

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

tolerations:
  - operator: Exists
```

## Values Reference

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replica.allNodes` | Deploy as DaemonSet | `true` |
| `replica.count` | Replicas if not DaemonSet | `1` |
| `image.repository` | Container image | `cloudflare/cloudflared` |
| `image.tag` | Image tag | Chart appVersion |
| `tunnelConfig.name` | Tunnel name | `""` (required) |
| `tunnelConfig.protocol` | Connection protocol | `auto` |
| `tunnelConfig.logLevel` | Log verbosity | `info` |
| `tunnelConfig.warpRouting` | Enable WARP routing | `false` |
| `ingress` | Routing rules | See example |
| `tolerations` | Pod tolerations | `[{effect: NoSchedule, operator: Exists}]` |
