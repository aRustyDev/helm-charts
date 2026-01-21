# CI Known Issues

This document tracks known issues and gaps in the CI/CD workflows.

## W2 Atomization Workflow - GitHub App Token Required

**Status**: Resolved (requires secrets configuration)
**Severity**: Medium
**Affected Workflow**: `atomize-integration-pr.yaml`

### Description

The W2 atomization workflow requires a GitHub App token with elevated permissions to reset the integration branch after atomization completes.

### Resolution Applied

1. **Ruleset reconfiguration**: Split `protected-branches-linear` ruleset:
   - `protected-branches-linear`: Covers main/release with `non_fast_forward` rule
   - `integration-linear-history` (NEW): Covers integration without `non_fast_forward` rule

2. **Workflow updated**: Now uses GitHub App token via `actions/create-github-app-token@v1`

### Required Secrets

The workflow uses 1Password for secret management:

| Secret | Description |
|--------|-------------|
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password Service Account token |

App credentials are stored in 1Password at `op://gh-shared/xauth/app/`.

### GitHub App Permissions

The GitHub App must have:
- **Repository permissions**:
  - Contents: Read and write
  - Pull requests: Read and write
  - Issues: Read and write
- **Bypass actor**: Added to `integration-pr-required` ruleset via GitHub UI

### Setup Steps

1. Ensure `github-app-x-auth` is installed on the repository
2. Ensure `OP_SERVICE_ACCOUNT_TOKEN` secret is configured
3. Add the GitHub App as bypass actor on `integration-pr-required` ruleset via UI:
   - Go to: Settings > Rules > Rulesets > `integration-pr-required`
   - Bypass list > Add bypass > Select `github-app-x-auth`

### Related

- Rulesets: `protected-branches-linear`, `integration-linear-history`, `integration-pr-required`
- Workflow: `.github/workflows/atomize-integration-pr.yaml`
- ADR: [ADR-011: Full Atomization Model](../adr/011-full-atomization-model.md)
