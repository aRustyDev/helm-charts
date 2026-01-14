# ADR-006: Release-Please for Helm Chart Versioning

**Status:** Accepted
**Date:** 2025-01-14

## Context

This repository needs a consistent approach to version management for Helm charts. Options include:
1. Manual version bumps by developers
2. Automated versioning via release-please
3. CI-enforced version checks with manual bumps

## Decision

Use [release-please](https://github.com/googleapis/release-please) to automate version bumps and changelog generation. Disable `check-version-increment` in chart-testing configuration.

## Rationale

1. **Single Source of Truth**: Release-please is the authoritative system for version management. Manual version bumps would conflict with automated versioning.

2. **Workflow Consistency**: When release-please creates a release PR, it bumps the version in `Chart.yaml`. If `check-version-increment` were enabled, developers would need to manually bump versions in their PRs, leading to merge conflicts and duplicate version increments.

3. **Conventional Commits**: Version bumps are derived from commit message prefixes:
   - `fix:` -> patch version (0.0.X)
   - `feat:` -> minor version (0.X.0)
   - `feat!:` or `BREAKING CHANGE:` -> major version (X.0.0)

## Configuration

```yaml
# ct.yaml and ct-install.yaml
check-version-increment: false  # release-please handles versioning
```

**Related Files:**
- `release-please-config.json` - Package configuration for each chart
- `.release-please-manifest.json` - Current versions for each chart
- `.github/workflows/release.yaml` - Release-please workflow

## Consequences

### Positive
- No manual version management required
- Consistent changelog generation
- Version semantics tied to commit messages

### Negative
- Developers must use conventional commit messages
- Cannot manually force specific version numbers without intervention

## Alternatives Considered

### Manual versioning with check-version-increment enabled
Rejected because it requires developers to remember version bumps and leads to merge conflicts when multiple PRs are open.

### Semantic-release
Similar to release-please but less native support for monorepos with Helm charts.
