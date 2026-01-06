# ADR-002: Multi-Endpoint Distribution

## Status

Accepted

## Context

Helm charts need to be accessible to users. We need to decide on distribution strategy:

1. **Single endpoint**: One hosting location (e.g., GitHub Pages only)
2. **Multiple endpoints**: Redundant hosting across platforms
3. **OCI-only**: Modern approach using container registries

### Considerations

- **Availability**: Single point of failure vs. redundancy
- **Performance**: CDN distribution for global users
- **Compatibility**: Traditional Helm repos vs. OCI registries
- **Maintenance**: More endpoints = more complexity

## Decision

Distribute charts via three endpoints:

| Endpoint | URL | Purpose |
|----------|-----|---------|
| GitHub Pages | `https://arustydev.github.io/helm-charts` | Primary, traditional Helm repo |
| Cloudflare Pages | `https://charts.arusty.dev` | CDN mirror, custom domain |
| GitHub Container Registry | `oci://ghcr.io/arustydev/charts` | Modern OCI distribution |

### Implementation

1. **GitHub Pages**: Automatic via chart-releaser-action pushing to `charts` branch
2. **Cloudflare Pages**: GitHub App deploys from `charts` branch
3. **GHCR**: CI pushes OCI artifacts on release

```yaml
# Release workflow pushes to all endpoints
- name: Run chart-releaser  # → GitHub Pages
- name: Push to GHCR        # → OCI registry
# Cloudflare GitHub App auto-deploys from 'charts' branch
```

## Consequences

### Positive

- **Redundancy**: If one endpoint is down, others remain available
- **Flexibility**: Users choose their preferred method
- **Performance**: Cloudflare CDN for faster global access
- **Modern support**: OCI for Helm 3.8+ users and GitOps tools
- **Custom domain**: `charts.arusty.dev` is memorable and branded

### Negative

- **Complexity**: Three endpoints to maintain
- **Consistency**: Must ensure all endpoints have same content
- **Documentation**: Users need to understand options

### Neutral

- All endpoints serve identical content (same chart versions)
- No additional cost (all services have free tiers)
- GitHub Actions handles all publishing automatically
