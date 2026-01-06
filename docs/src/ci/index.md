# CI/CD Workflows

This repository uses GitHub Actions for continuous integration and deployment. All workflows are located in `.github/workflows/`.

## Workflow Overview

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| [Lint and Test](./lint-test.md) | PR, manual | Validate charts with helm lint, chart-testing, and ArtifactHub |
| [Release Please](./release-please.md) | Push to main | Semantic versioning and changelog generation |
| [Release Charts](./release.md) | On release | Publish charts to GitHub Pages and GHCR |
| [Documentation](./docs.md) | PR (docs/), push to main | Build and deploy mdBook documentation |
| [Cleanup Branches](./cleanup.md) | Weekly, manual | Remove orphan release-please/dependabot branches |
| [Auto Assign](./auto-assign.md) | PR opened | Auto-assign PR author |
| [Dependabot Issues](./dependabot-issue.md) | Dependabot PR | Create tracking issues for dependency updates |

## Required Status Checks

PRs to `main` must pass:
- `lint-test (v1.28.15)` - Kubernetes 1.28 compatibility
- `lint-test (v1.29.12)` - Kubernetes 1.29 compatibility
- `lint-test (v1.30.8)` - Kubernetes 1.30 compatibility
- `artifacthub-lint` - ArtifactHub metadata validation

## Branch Protection

| Branch | Deletion | Direct Push | Status Checks |
|--------|----------|-------------|---------------|
| `main` | Protected | Require PR (admin bypass) | Required |
| `charts` | Protected | Require PR (admin bypass) | N/A (CI managed) |

## Secrets Required

| Secret | Purpose | Required By |
|--------|---------|-------------|
| `GITHUB_TOKEN` | Default token | All workflows |

No additional secrets are required - the repository uses GitHub's built-in OIDC for Sigstore signing.
