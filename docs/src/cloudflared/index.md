# Cloudflared Helm Chart

A Helm chart for deploying [cloudflared](https://github.com/cloudflare/cloudflared) tunnel connectors to Kubernetes.

## Overview

Cloudflared creates secure tunnels between your Kubernetes cluster and Cloudflare's edge network, enabling:
- Zero-trust access to internal services
- Secure exposure of services without public IPs
- Protection against DDoS and other attacks

## Quick Start

```bash
helm repo add arustydev https://arustydev.github.io/helm-charts
helm install cloudflared arustydev/cloudflared \
  --set tunnelConfig.name=my-tunnel \
  --set tunnelSecrets.base64EncodedConfigJsonFile=<your-credentials>
```

## Prerequisites

1. A Cloudflare account with Zero Trust enabled
2. A configured Cloudflare Tunnel with credentials
3. Kubernetes cluster 1.21+

## Configuration

See the chart's [values.yaml](https://github.com/aRustyDev/helm-charts/blob/main/charts/cloudflared/values.yaml) for all available options.

### Required Values

| Parameter | Description |
|-----------|-------------|
| `tunnelConfig.name` | Name of your Cloudflare tunnel |
| `tunnelSecrets.base64EncodedConfigJsonFile` | Base64-encoded tunnel credentials JSON |

## Source

This chart is based on the [community-charts/cloudflared](https://github.com/community-charts/helm-charts/tree/main/charts/cloudflared) chart with modifications for this repository's CI/CD pipeline.
