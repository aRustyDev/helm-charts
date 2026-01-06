# ADR 005: CI/CD Workflow Architecture

## Status

Accepted

## Date

2026-01-06

## Context

A Helm chart repository requires multiple CI/CD workflows for:
- Validation (linting, testing)
- Release management (versioning, publishing)
- Documentation (building, deploying)
- Maintenance (branch cleanup, automation)

These workflows must work together without conflicts, minimize redundant runs, and provide clear feedback to contributors.

## Decision

We will implement a **multi-workflow architecture** with clear separation of concerns:

### Validation Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `lint-test.yaml` | PR, manual | Chart validation with matrix testing |
| `docs.yaml` | PR (docs/), push | Documentation validation and deployment |

### Release Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `release-please.yaml` | Push to main | Version management and changelog |
| (same file) `release-charts` job | Release created | Publish to GHCR and Pages |

### Maintenance Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `cleanup-branches.yaml` | Weekly, manual | Remove orphan branches |
| `auto-assign.yml` | PR opened | Assign PR author |
| `dependabot-issue.yml` | Dependabot PR | Create tracking issues |

### Design Principles

1. **Single Responsibility** - Each workflow does one thing well
2. **Event-Driven** - Workflows respond to specific events
3. **Path Filtering** - Only run when relevant files change
4. **Matrix Testing** - Test across multiple Kubernetes versions
5. **Concurrency Control** - Prevent duplicate runs

## Implementation

### Path Filtering Example

```yaml
on:
  pull_request:
    paths:
      - 'docs/**'
      - 'book.toml'
```

### Concurrency Example

```yaml
concurrency:
  group: docs-${{ github.ref }}
  cancel-in-progress: true
```

### Matrix Testing

```yaml
strategy:
  matrix:
    k8s-version: [v1.28.15, v1.29.12, v1.30.8]
  fail-fast: false
```

## Consequences

### Positive

- Clear workflow ownership and debugging
- Efficient CI (only runs what's needed)
- Easy to add new workflows without conflicts
- Kubernetes compatibility assured through matrix testing

### Negative

- More files to maintain
- Some duplication of setup steps
- Complex event/trigger understanding required

### Neutral

- Requires understanding of GitHub Actions event model
- Branch protection rules must match workflow names

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Chart Testing Action](https://github.com/helm/chart-testing-action)
- [Release Please Action](https://github.com/googleapis/release-please-action)
