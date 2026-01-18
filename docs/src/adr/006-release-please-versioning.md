# ADR-006: Release-Please for Helm Chart Versioning

## Status

**Superseded** by [ADR-003: Semantic Versioning with git-cliff](003-semantic-versioning.md)

*Original Date: 2025-01-14*
*Superseded: 2025-01-17*

## Context

This ADR originally proposed using release-please for automated version management.

## Decision (Superseded)

~~Use release-please to automate version bumps and changelog generation.~~

**Actual Implementation**: We use **git-cliff** for changelog generation and a custom **version-bump.sh** script for semantic version calculation. Version bumping occurs during W5 (PR validation) workflow, not via separate release PRs.

## Why Superseded

Release-please was not implemented. Instead, a simpler approach was chosen:

1. **git-cliff**: Generates per-chart changelogs from conventional commits
2. **version-bump.sh**: Custom script determines semver bump from commit types
3. **W5 Integration**: Version bump happens during PR validation, not as separate PRs

This approach:
- Eliminates extra "release PRs" from release-please
- Keeps version bump atomic with chart changes
- Provides more control over changelog format
- Better fits the atomic chart release workflow

## See Also

- [ADR-003: Semantic Versioning with git-cliff](003-semantic-versioning.md) - The actual implementation
- [ADR-005: CI/CD Workflow Architecture](005-ci-workflows.md) - How version bumping fits in the pipeline
