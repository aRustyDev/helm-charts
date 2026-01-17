# Repository Labels Strategy

This document defines the labeling strategy for the aRustyDev/helm-charts repository.

## Label Categories

### Status Labels
Labels indicating the current state in automated workflows.

| Label | Description | Usage |
|-------|-------------|-------|
| `pending` | Awaiting automation to process | Applied by release-please when PR is created |
| `tagged` | Tagged for release | Applied by release-please after release is tagged |

### Scope Labels
Labels indicating what area of the repository is affected.

| Label | Description | Usage |
|-------|-------------|-------|
| `chart` | Related to Helm chart content or configuration | Chart additions, updates, or fixes |
| `cicd` | CI/CD pipelines and automation infrastructure | Workflow changes, CI configuration |
| `documentation` | Improvements or additions to documentation | README, docs, comments |
| `dependencies` | Dependency updates and management | Dependabot PRs, dependency bumps |

### Kind Labels
Labels indicating the type of change.

| Label | Description | Usage |
|-------|-------------|-------|
| `bug` | Something isn't working as expected | Bug reports and fixes |
| `enhancement` | New feature or request | Feature requests and implementations |
| `security` | Security-related issues or vulnerabilities | Security fixes, CVE responses |
| `question` | Further information is requested | Questions from users |

### Flag Labels
Labels for workflow management and triage.

| Label | Description | Usage |
|-------|-------------|-------|
| `automation` | Automated process or bot-managed work | Bot-created PRs, automated updates |
| `release` | Release process and publishing | Release-related work |
| `good first issue` | Good for newcomers | Issues suitable for new contributors |
| `help wanted` | Extra attention is needed | Issues needing community help |
| `duplicate` | This issue or pull request already exists | Duplicate issues |
| `invalid` | This doesn't seem right | Invalid or off-topic issues |
| `wontfix` | This will not be worked on | Intentionally not addressing |

## Label Combinations

### Common Patterns

- **New chart**: `chart` + `enhancement`
- **Chart bug fix**: `chart` + `bug`
- **CI improvement**: `cicd` + `enhancement`
- **Security fix**: `chart` + `security` or `cicd` + `security`
- **Automated PR**: `automation` + scope label (e.g., `dependencies`)
- **Release PR**: `release` + `pending` or `tagged`

## Migration History

Labels were consolidated on 2026-01-17:

| Old Label | New Label | Reason |
|-----------|-----------|--------|
| `autorelease: pending` | `pending` | Simplified naming |
| `autorelease: tagged` | `tagged` | Simplified naming |
| `chart-update` | `chart` | Merged into single scope label |
| `new-chart` | `chart` | Merged into single scope label |
| `github-actions` | `cicd` | More descriptive name |

## Automation Integration

### Release-Please
- Applies `pending` when creating release PRs
- Applies `tagged` after successful release

### Dependabot
- Applies `dependencies` to dependency update PRs

### W2 Filter Charts (Future)
- Could apply `chart` + `automation` + `release` to promotion PRs
