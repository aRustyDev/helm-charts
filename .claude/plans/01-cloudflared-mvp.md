# Plan: Cloudflared MVP Chart

## Overview
Add the base cloudflared Helm chart with minimal modifications from the upstream community-charts version.

## Scope
- Base cloudflared chart from community-charts/cloudflared
- Release-please configuration for version management
- No additional integrations

## Files to Create/Modify

### New Files
- `charts/cloudflared/` - Base chart directory
  - `Chart.yaml` - Chart metadata (version: 0.1.0)
  - `values.yaml` - Default values
  - `values.schema.json` - JSON schema for values validation
  - `templates/` - Kubernetes resource templates
  - `CHANGELOG.md` - For release-please
  - `LICENSE` - Apache 2.0
  - `README.md` - Chart documentation

### Modified Files
- `release-please-config.json` - Add cloudflared package
- `.release-please-manifest.json` - Add cloudflared with version 0.1.0

## Validation
- [ ] `helm lint charts/cloudflared` passes
- [ ] `helm template charts/cloudflared` renders correctly
- [ ] CI pipeline passes (chart-testing lint)
- [ ] CI pipeline passes (chart-testing install with ci/test-values.yaml)

## Notes
- Remove Chart.lock since there are no dependencies
- Update version from upstream 2.2.4 to 0.1.0 for fresh start
- Keep all original upstream functionality intact
- Charts with required values need ci/test-values.yaml for install tests

## SKILL Documentation Updates
After completing this PR, update the Helm chart development SKILL docs at:
`/private/etc/infra/priv/homelab/docs/src/skill-development/helm-chart-*.md`

Document:
- [ ] Chart.lock handling when no dependencies exist
- [ ] Release-please configuration patterns for Helm charts
- [ ] CI lint requirements (yamllint rules, chart-testing)
- [ ] CI install testing with ci/test-values.yaml for charts with required values
- [ ] Best practice: Start with upstream chart, minimal modifications
- [ ] Anti-pattern: Including stale Chart.lock files
