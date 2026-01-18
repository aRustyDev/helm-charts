# Architecture Decision Records

This section documents the key architectural decisions made for this Helm charts repository.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision along with its context and consequences.

## Index

| ADR | Title | Status |
|-----|-------|--------|
| [ADR-001](./001-charts-branch.md) | Release Branch for Artifacts | Accepted |
| [ADR-002](./002-multi-endpoint.md) | Multi-Endpoint Distribution | Accepted |
| [ADR-003](./003-semantic-versioning.md) | Semantic Versioning with git-cliff | Accepted |
| [ADR-004](./004-chart-signing.md) | Helm Chart Signing and Provenance | Accepted |
| [ADR-005](./005-ci-workflows.md) | CI/CD Workflow Architecture | Accepted |
| [ADR-006](./006-release-please-versioning.md) | Release-Please for Helm Chart Versioning | Superseded by ADR-003 |
| [ADR-007](./007-separate-ct-configs.md) | Separate Chart-Testing Configs | Accepted |
| [ADR-008](./008-repository-dispatch-automation.md) | Repository Dispatch for Workflow Automation | Accepted |
| [ADR-009](./009-integration-auto-merge.md) | Trust-Based Auto-Merge | Accepted |

## ADR Template

New ADRs should follow this structure:

```markdown
# ADR-NNN: Title

## Status
Proposed | Accepted | Deprecated | Superseded

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult because of this change?
```
