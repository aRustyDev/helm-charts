# Ingress Rules

Cloudflare Tunnel ingress rules define how traffic is routed from public hostnames to Kubernetes services.

## Rule Structure

Each rule has:
- `hostname` - Public hostname to match (optional, except catch-all)
- `path` - URL path pattern (optional)
- `service` - Target service URL
- `originRequest` - Connection settings (optional)

```yaml
ingress:
  - hostname: app.example.com
    path: /api/*
    service: http://api-service.default.svc.cluster.local:8080
    originRequest:
      connectTimeout: 30s
```

## Hostname Matching

### Exact Match

```yaml
ingress:
  - hostname: app.example.com
    service: http://app.default.svc.cluster.local:80
```

### Wildcard Match

Matches any subdomain:

```yaml
ingress:
  - hostname: "*.example.com"
    service: http://default-backend.default.svc.cluster.local:80
```

**Note:** Requires CNAME record for `*` pointing to tunnel.

### No Hostname (Catch-All)

**Required** as the last rule:

```yaml
ingress:
  - service: http_status:404
```

## Path Matching

### Prefix Match

```yaml
ingress:
  - hostname: api.example.com
    path: /v1/*
    service: http://api-v1.default.svc.cluster.local:8080

  - hostname: api.example.com
    path: /v2/*
    service: http://api-v2.default.svc.cluster.local:8080

  - hostname: api.example.com
    service: http://api-latest.default.svc.cluster.local:8080
```

### Regex Match

```yaml
ingress:
  - hostname: app.example.com
    path: "^/user/[0-9]+$"
    service: http://user-service.default.svc.cluster.local:8080
```

## Service Types

### HTTP/HTTPS Services

```yaml
ingress:
  # HTTP service
  - hostname: app.example.com
    service: http://app.default.svc.cluster.local:80

  # HTTPS service (with TLS verification)
  - hostname: secure.example.com
    service: https://secure-app.default.svc.cluster.local:443

  # HTTPS service (skip TLS verification)
  - hostname: internal.example.com
    service: https://internal-app.default.svc.cluster.local:443
    originRequest:
      noTLSVerify: true
```

### TCP Services

```yaml
ingress:
  - hostname: ssh.example.com
    service: tcp://ssh-bastion.default.svc.cluster.local:22

  - hostname: db.example.com
    service: tcp://postgres.database.svc.cluster.local:5432
```

### Built-in Services

```yaml
ingress:
  # Return HTTP status code
  - service: http_status:404
  - service: http_status:503

  # Hello world test page
  - service: hello_world
```

## Origin Request Settings

Configure connection behavior to origin services:

```yaml
ingress:
  - hostname: app.example.com
    service: https://app.default.svc.cluster.local:443
    originRequest:
      # TLS settings
      noTLSVerify: true              # Skip certificate verification
      originServerName: app.local    # SNI for TLS handshake

      # Timeouts
      connectTimeout: 30s
      tlsTimeout: 10s
      tcpKeepAlive: 30s
      keepAliveTimeout: 90s
      keepAliveConnections: 100

      # HTTP settings
      httpHostHeader: app.example.com
      disableChunkedEncoding: false

      # Proxy settings
      proxyAddress: 127.0.0.1
      proxyPort: 0
      proxyType: ""

      # Access control
      ipRules:
        - prefix: 192.168.1.0/24
          allow: true
```

## Common Patterns

### Single Application

```yaml
ingress:
  - hostname: myapp.example.com
    service: http://myapp.default.svc.cluster.local:8080
  - service: http_status:404
```

### Multiple Applications

```yaml
ingress:
  - hostname: grafana.example.com
    service: http://grafana.monitoring.svc.cluster.local:3000

  - hostname: prometheus.example.com
    service: http://prometheus.monitoring.svc.cluster.local:9090

  - hostname: argocd.example.com
    service: https://argocd-server.argocd.svc.cluster.local:443
    originRequest:
      noTLSVerify: true

  - service: http_status:404
```

### Wildcard with Specific Overrides

```yaml
ingress:
  # Specific hostnames first (higher priority)
  - hostname: api.example.com
    service: http://api.default.svc.cluster.local:8080

  - hostname: admin.example.com
    service: http://admin.default.svc.cluster.local:8080

  # Wildcard catch-all for subdomains
  - hostname: "*.example.com"
    service: http://default-ingress.ingress-nginx.svc.cluster.local:80

  # Final catch-all
  - service: http_status:404
```

### Path-Based Routing

```yaml
ingress:
  - hostname: app.example.com
    path: /api/*
    service: http://api-backend.default.svc.cluster.local:8080

  - hostname: app.example.com
    path: /static/*
    service: http://cdn.default.svc.cluster.local:80

  - hostname: app.example.com
    service: http://frontend.default.svc.cluster.local:3000

  - service: http_status:404
```

## Rule Ordering

Rules are evaluated **top to bottom**. First match wins.

1. Place most specific rules first
2. Place wildcard rules after specific rules
3. Catch-all (`- service: http_status:404`) must be last

## Debugging

Check which rule matches a request:

```bash
# In cloudflared pod
cloudflared tunnel ingress validate
cloudflared tunnel ingress rule https://app.example.com/path
```

View cloudflared logs:

```bash
kubectl logs -n cloudflare -l app.kubernetes.io/name=cloudflared
```
