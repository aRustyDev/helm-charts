# Plan: NetworkPolicy Support

## Overview
Add Kubernetes NetworkPolicy for network segmentation and security.

## Dependencies
- PR #1 (MVP) must be merged first

## Scope
- NetworkPolicy template
- Configurable ingress and egress rules
- Default restrictive policy option

## Files to Create/Modify

### New Files
- `charts/cloudflared/templates/networkpolicy.yaml`

### Modified Files
- `charts/cloudflared/values.yaml` - Add networkPolicy section
- `charts/cloudflared/values.schema.json` - Add schema for networkPolicy
- `charts/cloudflared/README.md` - Document NetworkPolicy configuration

## Values Structure
```yaml
networkPolicy:
  enabled: false
  policyTypes:
    - Ingress
    - Egress
  ingress: []
    # - from:
    #     - namespaceSelector:
    #         matchLabels:
    #           kubernetes.io/metadata.name: monitoring
    #   ports:
    #     - protocol: TCP
    #       port: 2000
  egress: []
    # - to:
    #     - namespaceSelector: {}
    #   ports:
    #     - protocol: TCP
    #       port: 80
    #     - protocol: TCP
    #       port: 443
```

## Template Structure
```yaml
{{- if .Values.networkPolicy.enabled }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ include "cloudflared.fullname" . }}
  labels:
    {{- include "cloudflared.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "cloudflared.selectorLabels" . | nindent 6 }}
  policyTypes:
    {{- toYaml .Values.networkPolicy.policyTypes | nindent 4 }}
  {{- with .Values.networkPolicy.ingress }}
  ingress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.networkPolicy.egress }}
  egress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
```

## Validation
- [ ] `helm lint` passes
- [ ] NetworkPolicy renders when enabled
- [ ] NetworkPolicy not rendered when disabled
- [ ] Ingress and egress rules apply correctly

## Notes
- Requires NetworkPolicy-capable CNI (Calico, Cilium, etc.)
- Empty ingress/egress means deny all for that direction
- Consider allowing DNS egress (port 53) if strict egress

## SKILL Documentation Updates
After completing this PR, update the Helm chart development SKILL docs at:
`/private/etc/infra/priv/homelab/docs/src/skill-development/helm-chart-*.md`

Document:
- [ ] NetworkPolicy template patterns
- [ ] Pattern: Use selectorLabels helper for podSelector
- [ ] Best practice: Document CNI requirements in README
- [ ] Pattern: Allow users to define full ingress/egress rules
- [ ] Anti-pattern: Overly restrictive default policies that break functionality
