# Plan: External Secrets Integration

## Overview
Add External Secrets Operator integration to manage tunnel credentials from external secret stores.

## Dependencies
- PR #1 (MVP) must be merged first

## Scope
- ExternalSecret CRD template
- Values configuration for secret store reference
- Support for credentials.json and cert.pem from external stores
- Update deployment to use ExternalSecret-created secrets

## Files to Create/Modify

### New Files
- `charts/cloudflared/templates/externalsecret.yaml`

### Modified Files
- `charts/cloudflared/values.yaml` - Add externalSecrets section
- `charts/cloudflared/values.schema.json` - Add schema for externalSecrets
- `charts/cloudflared/templates/deployment.yaml` - Support projected volumes from ExternalSecret
- `charts/cloudflared/README.md` - Document External Secrets usage

## Values Structure
```yaml
externalSecrets:
  enabled: false
  refreshInterval: "1h"
  secretStoreRef:
    name: ""
    kind: "SecretStore"  # or ClusterSecretStore
  target:
    name: ""  # defaults to <fullname>-credentials
    creationPolicy: "Owner"
  data:
    credentials:
      remoteRef:
        key: ""
        property: ""
      secretKey: "credentials.json"
    certificate:
      remoteRef:
        key: ""
        property: ""
      secretKey: "cert.pem"
```

## Validation
- [ ] `helm lint` passes
- [ ] `helm template --set externalSecrets.enabled=true` renders ExternalSecret
- [ ] ExternalSecret not rendered when disabled
- [ ] Deployment correctly references the created secret

## Notes
- Uses external-secrets.io/v1 API version
- Mutually exclusive with inline base64 secrets

## SKILL Documentation Updates
After completing this PR, update the Helm chart development SKILL docs at:
`/private/etc/infra/priv/homelab/docs/src/skill-development/helm-chart-*.md`

Document:
- [ ] ExternalSecret CRD template patterns
- [ ] Projected volume pattern for multiple secret sources
- [ ] Best practice: Make integrations opt-in with `enabled: false` default
- [ ] Pattern: Conditional template rendering with `{{- if .Values.feature.enabled }}`
- [ ] Anti-pattern: Hardcoding secret names instead of using templates
