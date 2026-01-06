# ADR-003: Semantic Versioning with Release-Please

## Status

Accepted

## Context

Chart versions need to be managed systematically. Options considered:

1. **Manual versioning**: Developers update `Chart.yaml` version manually
2. **semantic-release**: Automated releases on every merge
3. **release-please**: Creates release PRs for review before publishing

### Considerations

- **Helm charts are a monorepo**: Multiple charts in `charts/` directory
- **Version visibility**: Should version bumps be reviewable?
- **Changelog generation**: Automatic vs. manual
- **Conventional commits**: Required for automation

## Decision

Use **release-please** for semantic versioning with these configurations:

```json
// release-please-config.json
{
  "packages": {
    "charts/olm": { "release-type": "helm" },
    "charts/mdbook-htmx": { "release-type": "helm" }
  },
  "separate-pull-requests": true
}
```

### Why release-please over semantic-release?

| Feature | release-please | semantic-release |
|---------|---------------|------------------|
| Review before release | Yes (creates PR) | No (direct release) |
| Monorepo support | Native | Requires plugins |
| Helm chart support | Built-in `helm` type | Manual configuration |
| Changelog | Generated in PR | Generated at release |

### Commit Convention

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix(chart):` | Patch (0.0.X) | `fix(holmes): correct port` |
| `feat(chart):` | Minor (0.X.0) | `feat(holmes): add HPA` |
| `feat(chart)!:` | Major (X.0.0) | `feat(holmes)!: break values` |
| `chore:` | No bump | `chore: update readme` |

## Consequences

### Positive

- **Reviewable releases**: Team can review version bump and changelog before release
- **Per-chart versioning**: Each chart versioned independently
- **Automated changelogs**: Generated from commit messages
- **Conventional commits enforced**: Clear commit history

### Negative

- **Two-step release**: Merge feature PR, then merge release PR
- **Learning curve**: Team must use conventional commits
- **PR noise**: Release PRs appear in PR list

### Neutral

- Release PRs are auto-generated and auto-updated
- Chart version in `Chart.yaml` is automatically bumped
- Works alongside chart-releaser-action for publishing
