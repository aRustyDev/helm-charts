# Tunnel Setup

This guide covers creating a Cloudflare Tunnel for use with the Helm chart.

## Prerequisites

1. **Cloudflare Account** with a domain added
2. **cloudflared CLI** installed locally

```bash
# macOS
brew install cloudflared

# Linux
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/
```

## Step 1: Authenticate

Login to your Cloudflare account:

```bash
cloudflared tunnel login
```

This opens a browser to authorize the CLI. After authorization, a certificate is saved to `~/.cloudflared/cert.pem`.

## Step 2: Create Tunnel

```bash
cloudflared tunnel create <tunnel-name>
```

Example:
```bash
cloudflared tunnel create homelab-tunnel
```

This creates:
- `~/.cloudflared/<tunnel-id>.json` - Tunnel credentials
- Tunnel entry in Cloudflare dashboard

**Save the tunnel ID** - you'll need it for DNS records.

## Step 3: Create DNS Records

For each hostname you want to route through the tunnel, create a CNAME record:

```bash
# Single hostname
cloudflared tunnel route dns <tunnel-name> app.example.com

# Wildcard (requires Cloudflare Pro or higher for wildcard DNS)
cloudflared tunnel route dns <tunnel-name> "*.example.com"
```

Or manually in Cloudflare Dashboard:
- Type: `CNAME`
- Name: `app` (or `*` for wildcard)
- Target: `<tunnel-id>.cfargotunnel.com`
- Proxy status: Proxied (orange cloud)

## Step 4: Prepare Credentials for Kubernetes

The Helm chart needs two files as base64-encoded secrets:

### Option A: Inline in values.yaml

```bash
# Get base64-encoded credentials
base64 -i ~/.cloudflared/*.json

# Get base64-encoded certificate
base64 -i ~/.cloudflared/cert.pem
```

Then set in values:
```yaml
tunnelSecrets:
  base64EncodedConfigJsonFile: "<base64-encoded-json>"
  base64EncodedPemFile: "<base64-encoded-pem>"
```

### Option B: Kubernetes Secrets (Recommended)

```bash
# Create namespace
kubectl create namespace cloudflare

# Create secrets from files
kubectl create secret generic cloudflared-credentials \
  -n cloudflare \
  --from-file=credentials.json=$HOME/.cloudflared/*.json

kubectl create secret generic cloudflared-cert \
  -n cloudflare \
  --from-file=cert.pem=$HOME/.cloudflared/cert.pem
```

Then reference in values:
```yaml
tunnelSecrets:
  existingConfigJsonFileSecret:
    name: cloudflared-credentials
    key: credentials.json
  existingPemFileSecret:
    name: cloudflared-cert
    key: cert.pem
```

## Step 5: Verify Tunnel

List your tunnels:
```bash
cloudflared tunnel list
```

Check tunnel details:
```bash
cloudflared tunnel info <tunnel-name>
```

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| `cert.pem` | `~/.cloudflared/cert.pem` | Account certificate (from `tunnel login`) |
| `<tunnel-id>.json` | `~/.cloudflared/<tunnel-id>.json` | Tunnel credentials (from `tunnel create`) |

## Troubleshooting

### "failed to fetch token" error

Re-authenticate:
```bash
cloudflared tunnel login
```

### Tunnel not connecting

Check tunnel status in Cloudflare One dashboard:
1. Go to [Cloudflare One](https://one.dash.cloudflare.com/)
2. Navigate to Networks > Tunnels
3. Verify tunnel shows as "Healthy"

### DNS not resolving

Verify CNAME record points to `<tunnel-id>.cfargotunnel.com`:
```bash
dig app.example.com CNAME
```

## Next Steps

- [Configuration Reference](./configuration.md) - Helm values
- [Ingress Rules](./ingress-rules.md) - Route traffic to services
