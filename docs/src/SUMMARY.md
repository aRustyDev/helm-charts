# Summary

[Introduction](./introduction.md)

# User Guide

- [Getting Started](./getting-started.md)
- [Installation Methods](./installation.md)

# Charts

- [cloudflared](./cloudflared/index.md)
- [holmes (OLM)](./charts/holmes.md)
- [mdbook-htmx](./charts/mdbook-htmx.md)

# CI/CD

- [Workflow Overview](./ci/index.md)
  - [GitHub App Authentication](./ci/github-app-auth.md)
  - [Lint and Test](./ci/lint-test.md)
  - [Release Please](./ci/release-please.md)
  - [Release Charts](./ci/release.md)
  - [Documentation](./ci/docs.md)
  - [Cleanup Branches](./ci/cleanup.md)
  - [Auto Assign](./ci/auto-assign.md)
  - [Dependabot Issues](./ci/dependabot-issue.md)

# Architecture

- [ADR Index](./adr/index.md)
  - [ADR-001: Charts Branch for Artifacts](./adr/001-charts-branch.md)
  - [ADR-002: Multi-Endpoint Distribution](./adr/002-multi-endpoint.md)
  - [ADR-003: Semantic Versioning with Release-Please](./adr/003-semantic-versioning.md)
  - [ADR-004: Helm Chart Signing and Provenance](./adr/004-chart-signing.md)
  - [ADR-005: CI/CD Workflow Architecture](./adr/005-ci-workflows.md)
  - [ADR-006: Release-Please for Helm Chart Versioning](./adr/006-release-please-versioning.md)
  - [ADR-007: Separate Chart-Testing Configs](./adr/007-separate-ct-configs.md)
  - [ADR-010: Linear History and Rebase Workflow](./adr/010-linear-history-rebase.md)
  - [ADR-011: Full Atomization Model](./adr/011-full-atomization-model.md)
  - [ADR-012: GitHub App Token Pattern](./adr/012-github-app-token-pattern.md)

# Security

- [Chart Verification](./security/verification.md)
- [Attestation & Provenance](./attestation/index.md)
  - [Verification Methods](./attestation/verification.md)
  - [Lineage Tracing](./attestation/lineage.md)
  - [Limitations](./attestation/limitations.md)

# Troubleshooting

- [Commitlint Conflicts](./troubleshooting/commitlint-conflicts.md)
- [CI Known Issues](./troubleshooting/ci-known-issues.md)

# Contributing

- [Development Guide](./contributing/development.md)
- [Creating a New Chart](./contributing/new-chart.md)
