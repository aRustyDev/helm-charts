# Plan: Prometheus Metrics Integration

## Overview
Add Prometheus monitoring support with ServiceMonitor and PodMonitor resources.

## Dependencies
- PR #1 (MVP) must be merged first

## Scope
- Metrics Service for scraping
- ServiceMonitor for Prometheus Operator (Deployment mode)
- PodMonitor for Prometheus Operator (DaemonSet mode)
- Configurable metrics port and path

## Files to Create/Modify

### New Files
- `charts/cloudflared/templates/service.yaml` - Metrics service
- `charts/cloudflared/templates/servicemonitor.yaml` - ServiceMonitor CRD
- `charts/cloudflared/templates/podmonitor.yaml` - PodMonitor CRD

### Modified Files
- `charts/cloudflared/values.yaml` - Add metrics section
- `charts/cloudflared/values.schema.json` - Add schema for metrics
- `charts/cloudflared/templates/deployment.yaml` - Add named port for metrics
- `charts/cloudflared/README.md` - Document Prometheus setup

## Values Structure
```yaml
metrics:
  enabled: true
  port: 2000
  path: "/metrics"
  service:
    enabled: true
    type: ClusterIP
    labels: {}
  serviceMonitor:
    enabled: false
    namespace: ""
    interval: "30s"
    scrapeTimeout: "10s"
    labels: {}
    metricRelabelings: []
    relabelings: []
  podMonitor:
    enabled: false
    namespace: ""
    interval: "30s"
    scrapeTimeout: "10s"
    labels: {}
    metricRelabelings: []
    relabelings: []
```

## Validation
- [ ] `helm lint` passes
- [ ] Service renders when metrics.service.enabled=true
- [ ] ServiceMonitor renders when metrics.serviceMonitor.enabled=true
- [ ] PodMonitor renders when metrics.podMonitor.enabled=true
- [ ] Resources not rendered when disabled

## Notes
- Cloudflared exposes metrics on port 2000 by default
- PodMonitor is preferred for DaemonSet deployments
- ServiceMonitor is preferred for Deployment mode

## SKILL Documentation Updates
After completing this PR, update the Helm chart development SKILL docs at:
`/private/etc/infra/priv/homelab/docs/src/skill-development/helm-chart-*.md`

Document:
- [ ] ServiceMonitor vs PodMonitor: when to use each
- [ ] Named ports pattern for service discovery
- [ ] Pattern: Separate Service for metrics (not mixing with app traffic)
- [ ] Best practice: Include metricRelabelings and relabelings options
- [ ] Anti-pattern: Hardcoding scrape intervals without making them configurable
