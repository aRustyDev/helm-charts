# Plan: Linkerd Service Mesh Integration

## Overview
Add Linkerd service mesh support for automatic mTLS between cloudflared and origin services.

## Dependencies
- PR #1 (MVP) must be merged first

## Scope
- Linkerd proxy injection annotation
- Configurable Linkerd-specific annotations
- Documentation for Linkerd setup

## Files to Create/Modify

### Modified Files
- `charts/cloudflared/values.yaml` - Add linkerd section
- `charts/cloudflared/values.schema.json` - Add schema for linkerd
- `charts/cloudflared/templates/deployment.yaml` - Add Linkerd annotations to pod
- `charts/cloudflared/README.md` - Document Linkerd integration

## Values Structure
```yaml
linkerd:
  enabled: false
  annotations: {}
    # config.linkerd.io/proxy-cpu-request: "100m"
    # config.linkerd.io/proxy-memory-request: "128Mi"
    # config.linkerd.io/skip-outbound-ports: "443"
```

## Template Changes
```yaml
# In deployment.yaml pod template metadata
{{- if .Values.linkerd.enabled }}
annotations:
  linkerd.io/inject: enabled
  {{- with .Values.linkerd.annotations }}
  {{- toYaml . | nindent 8 }}
  {{- end }}
{{- end }}
```

## Validation
- [ ] `helm lint` passes
- [ ] Linkerd annotations render when linkerd.enabled=true
- [ ] No Linkerd annotations when disabled
- [ ] Custom annotations merge correctly

## Notes
- Linkerd must be installed in the cluster
- Namespace must be annotated or pod injection enabled
- Consider skip-outbound-ports for external Cloudflare connections

## SKILL Documentation Updates
After completing this PR, update the Helm chart development SKILL docs at:
`/private/etc/infra/priv/homelab/docs/src/skill-development/helm-chart-*.md`

Document:
- [ ] Service mesh annotation patterns (Linkerd, Istio)
- [ ] Pattern: Merge user annotations with chart-managed annotations
- [ ] Best practice: Document skip-outbound-ports for external connections
- [ ] Pattern: Configurable annotations map with `{{- toYaml . | nindent }}`
- [ ] Anti-pattern: Overwriting user-provided podAnnotations
