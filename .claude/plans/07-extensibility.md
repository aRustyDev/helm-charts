# Plan: Extensibility (Extra Volumes/Env/Mounts)

## Overview
Add extensibility options for custom volumes, volume mounts, and environment variables.

## Dependencies
- PR #1 (MVP) must be merged first

## Scope
- Extra environment variables
- Extra volumes
- Extra volume mounts
- Extra init containers (optional)

## Files to Create/Modify

### Modified Files
- `charts/cloudflared/values.yaml` - Add extra* sections
- `charts/cloudflared/values.schema.json` - Add schema for extra* fields
- `charts/cloudflared/templates/deployment.yaml` - Include extra* in template
- `charts/cloudflared/README.md` - Document extensibility options

## Values Structure
```yaml
extraEnv: []
  # - name: TUNNEL_LOGLEVEL
  #   value: "debug"
  # - name: MY_SECRET
  #   valueFrom:
  #     secretKeyRef:
  #       name: my-secret
  #       key: password

extraVolumes: []
  # - name: custom-config
  #   configMap:
  #     name: my-config

extraVolumeMounts: []
  # - name: custom-config
  #   mountPath: /etc/custom
  #   readOnly: true

extraInitContainers: []
  # - name: wait-for-db
  #   image: busybox
  #   command: ['sh', '-c', 'until nc -z db 5432; do sleep 1; done']
```

## Template Changes
```yaml
# In container spec
env:
  - name: TUNNEL_ORIGIN_CERT
    value: ...
  {{- with .Values.extraEnv }}
  {{- toYaml . | nindent 12 }}
  {{- end }}

volumeMounts:
  - name: config
    ...
  {{- with .Values.extraVolumeMounts }}
  {{- toYaml . | nindent 12 }}
  {{- end }}

# In pod spec
volumes:
  - name: config
    ...
  {{- with .Values.extraVolumes }}
  {{- toYaml . | nindent 8 }}
  {{- end }}

{{- with .Values.extraInitContainers }}
initContainers:
  {{- toYaml . | nindent 8 }}
{{- end }}
```

## Validation
- [ ] `helm lint` passes
- [ ] Extra env vars render correctly
- [ ] Extra volumes and mounts render correctly
- [ ] Empty arrays produce no output

## Notes
- Allows customization without forking the chart
- Common use case: mounting additional certs or configs
- Init containers useful for waiting on dependencies

## SKILL Documentation Updates
After completing this PR, update the Helm chart development SKILL docs at:
`/private/etc/infra/priv/homelab/docs/src/skill-development/helm-chart-*.md`

Document:
- [ ] Extensibility patterns (extraEnv, extraVolumes, extraVolumeMounts)
- [ ] Pattern: Use `{{- with .Values.extra* }}` for conditional rendering
- [ ] Best practice: Support both simple values and valueFrom references
- [ ] Pattern: Empty arrays produce no output
- [ ] Anti-pattern: Limiting extensibility by not exposing extra* options
