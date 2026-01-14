# cloudflared

Helm chart for deploying Cloudflare Tunnel (cloudflared) in Kubernetes.

## Overview

Cloudflare Tunnel provides a secure way to expose Kubernetes services to the internet without opening inbound ports or configuring firewalls. Traffic flows through Cloudflare's network, providing DDoS protection, WAF, and access controls.

## Available Helm Charts

| Chart | Source | Approach | Maintained |
|-------|--------|----------|------------|
| `community-charts/cloudflared` | [Artifact Hub](https://artifacthub.io/packages/helm/community-charts/cloudflared) | Locally-managed tunnel | Yes (v2.2.4) |
| Official Cloudflare | — | Raw manifests only | N/A |

**Note:** Cloudflare does not provide an official Helm chart. They recommend deploying via raw Kubernetes manifests with a tunnel token. The community chart provides a more Helm-native approach with locally-managed tunnels.

## Chart Comparison: Community vs Official Manifests

| Feature | Community Helm Chart | Official Manifests |
|---------|---------------------|-------------------|
| Config management | `values.yaml` (GitOps friendly) | Cloudflare Dashboard |
| Tunnel type | Locally-managed | Remotely-managed |
| Credentials | cert.pem + credentials.json | Token only |
| Route configuration | In-cluster (ingress rules) | Dashboard UI |
| Deployment type | DaemonSet or Deployment | Deployment |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Internet                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Cloudflare Network                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   DNS       │  │    WAF      │  │   DDoS      │             │
│  │  (CNAME)    │  │ Protection  │  │ Mitigation  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Encrypted tunnel (QUIC/HTTP2)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                           │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              cloudflared (DaemonSet/Deployment)          │   │
│  │  - Maintains outbound connection to Cloudflare           │   │
│  │  - Routes traffic based on ingress rules                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│              ┌───────────────┼───────────────┐                 │
│              ▼               ▼               ▼                 │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐      │
│  │   Service A   │  │   Service B   │  │   Service C   │      │
│  │  (internal)   │  │  (internal)   │  │  (internal)   │      │
│  └───────────────┘  └───────────────┘  └───────────────┘      │
└─────────────────────────────────────────────────────────────────┘
```

## Quick Start

See [Tunnel Setup](./tunnel-setup.md) for creating the tunnel, then [Configuration](./configuration.md) for Helm values.

```bash
# 1. Create tunnel (one-time)
cloudflared tunnel create my-tunnel

# 2. Install chart
helm install cloudflared ./charts/cloudflared \
  --namespace cloudflare --create-namespace \
  --set tunnelConfig.name=my-tunnel \
  --set tunnelSecrets.base64EncodedPemFile=$(base64 -i ~/.cloudflared/cert.pem) \
  --set tunnelSecrets.base64EncodedConfigJsonFile=$(base64 -i ~/.cloudflared/*.json)
```

## Documentation

- [Tunnel Setup](./tunnel-setup.md) - Creating and configuring a Cloudflare Tunnel
- [Configuration](./configuration.md) - Helm values reference
- [Ingress Rules](./ingress-rules.md) - Routing traffic to services

## Links

- [Cloudflare Tunnel Docs](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [Community Chart Source](https://github.com/community-charts/helm-charts)
- [Chart on Artifact Hub](https://artifacthub.io/packages/helm/community-charts/cloudflared)
