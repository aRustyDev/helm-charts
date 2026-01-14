# Plan: Enhanced Health Probes

## Overview
Add configurable liveness and readiness probes with sensible defaults.

## Dependencies
- PR #1 (MVP) must be merged first

## Scope
- Configurable liveness probe
- Configurable readiness probe
- Startup probe support
- All probe parameters exposed

## Files to Create/Modify

### Modified Files
- `charts/cloudflared/values.yaml` - Add probes section
- `charts/cloudflared/values.schema.json` - Add schema for probes
- `charts/cloudflared/templates/deployment.yaml` - Add configurable probes
- `charts/cloudflared/README.md` - Document probe configuration

## Values Structure
```yaml
probes:
  liveness:
    enabled: true
    path: "/ready"
    port: 2000
    initialDelaySeconds: 10
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
    successThreshold: 1
  readiness:
    enabled: true
    path: "/ready"
    port: 2000
    initialDelaySeconds: 5
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 3
    successThreshold: 1
  startup:
    enabled: false
    path: "/ready"
    port: 2000
    initialDelaySeconds: 0
    periodSeconds: 5
    timeoutSeconds: 3
    failureThreshold: 30
    successThreshold: 1
```

## Validation
- [ ] `helm lint` passes
- [ ] Probes render with correct defaults
- [ ] Probes can be disabled individually
- [ ] All parameters are configurable

## Notes
- Cloudflared exposes /ready endpoint on metrics port
- Startup probe useful for slow-starting environments
- Consider failureThreshold based on gracePeriod

## SKILL Documentation Updates
After completing this PR, update the Helm chart development SKILL docs at:
`/private/etc/infra/priv/homelab/docs/src/skill-development/helm-chart-*.md`

Document:
- [ ] Health probe configuration patterns
- [ ] Pattern: All probe parameters should be configurable
- [ ] Best practice: Sensible defaults that work out of the box
- [ ] Pattern: Enable/disable individual probes
- [ ] Anti-pattern: Hardcoded probe values that can't be tuned
