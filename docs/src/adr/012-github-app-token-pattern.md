# ADR-012: GitHub App Token Pattern for Workflows

## Status

Accepted

## Context

GitHub Actions workflows authenticate using `GITHUB_TOKEN` (also `github.token` or `secrets.GITHUB_TOKEN`) by default. This token has several limitations that impact CI/CD automation:

### Limitations of GITHUB_TOKEN

| Limitation | Impact |
|------------|--------|
| Cannot trigger workflows | PRs/pushes made with `GITHUB_TOKEN` won't trigger `on: push` or `on: pull_request` workflows |
| Cannot bypass branch protection | Even with admin bypass configured on rulesets, `GITHUB_TOKEN` cannot utilize bypass privileges |
| Repository-scoped only | Cannot perform cross-repository operations |
| Single identity | All actions appear from `github-actions[bot]`, reducing traceability |

### Specific Problem: W2 Atomization

The W2 atomization workflow (`atomize-integration-pr.yaml`) needs to:
1. Push to atomic branches (`charts/*`, `ci/*`, etc.)
2. Create PRs to main
3. Force-push to reset the integration branch

The integration branch is protected by rulesets that block force pushes. While admin bypass is configured, `GITHUB_TOKEN` cannot utilize this bypass, causing the workflow to fail.

### Available Solutions

1. **Personal Access Token (PAT)**: Works but tied to individual user, security concerns
2. **Deploy Key**: SSH-based, limited to repository access
3. **GitHub App Token**: First-class app identity, configurable permissions, auditable

## Decision

Adopt the **GitHub App Token Pattern** as the standard for workflows requiring elevated permissions.

### Pattern Structure (with 1Password - Preferred)

```yaml
jobs:
  generate-token:
    name: Generate App Token
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.app-token.outputs.token }}
    steps:
      - name: Load secrets from 1Password
        id: op-secrets
        uses: 1password/load-secrets-action@v2
        with:
          export-env: false
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
          X_REPO_AUTH_APP_ID: op://gh-shared/xauth/app/id
          X_REPO_AUTH_PRIVATE_KEY: op://gh-shared/xauth/app/private-key.pem

      - name: Generate GitHub App Token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ steps.op-secrets.outputs.X_REPO_AUTH_APP_ID }}
          private-key: ${{ steps.op-secrets.outputs.X_REPO_AUTH_PRIVATE_KEY }}

  my-job:
    needs: [generate-token]
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ needs.generate-token.outputs.token }}
```

### Required Secrets

**With 1Password (Preferred):**

| Secret | Description |
|--------|-------------|
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password Service Account token |

App credentials stored in 1Password vault at `op://gh-shared/xauth/app/`.

**With GitHub Secrets (Alternative):**

| Secret | Description |
|--------|-------------|
| `APP_ID` | GitHub App ID |
| `APP_PRIVATE_KEY` | GitHub App private key (PEM format) |

### GitHub App: github-app-x-auth

Use the existing [github-app-x-auth](https://github.com/aRustyDev/github-app-x-auth) app for authentication. This app:
- Is installed globally across repositories
- Provides traceability for automated actions
- Has configurable permissions per installation

### Token Scoping

By default, tokens are scoped to the **current repository only**:

```yaml
# Default: single-repo scope (PREFERRED)
- uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

For cross-repository operations (use sparingly):

```yaml
# Explicit multi-repo scope
- uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    repositories: "repo1,repo2"
```

### When to Use This Pattern

Use GitHub App tokens when a workflow needs to:

| Operation | GITHUB_TOKEN | App Token |
|-----------|--------------|-----------|
| Push to protected branches | No | Yes |
| Bypass ruleset rules | No | Yes (if added as bypass actor) |
| Trigger other workflows | No | Yes |
| Custom commit author | No | Yes |
| Cross-repo operations | No | Yes |

### Ruleset Configuration

For the app to bypass branch protection, add it as a bypass actor:

1. Settings > Rules > Rulesets > [Ruleset Name]
2. Bypass list > Add bypass
3. Select the GitHub App
4. Set bypass mode to "Always"

## Consequences

### Positive

- **Bypasses limitations**: App tokens can bypass rulesets, trigger workflows, etc.
- **Traceability**: Actions attributed to specific app, not generic bot
- **Security**: Tokens are short-lived, scoped, and auditable
- **Reusability**: Same app works across all repositories
- **No PAT management**: Eliminates individual PAT security concerns

### Negative

- **Setup complexity**: Requires GitHub App creation and secret management
- **Additional job**: Token generation adds workflow execution time (~5s)
- **Secret management**: Must securely store `APP_PRIVATE_KEY`

### Neutral

- Workflows become slightly more verbose with the generate-token job
- Debugging may require understanding app token vs GITHUB_TOKEN behavior

## Implementation

### Completed

1. **W2 Atomization Workflow**: Updated `atomize-integration-pr.yaml` to use app token pattern
2. **Documentation**: Created `docs/src/ci/github-app-auth.md`
3. **Ruleset Split**: Created `integration-linear-history` without `non_fast_forward` rule

### Required (Manual)

1. Add `APP_ID` and `APP_PRIVATE_KEY` secrets to repository
2. Add GitHub App as bypass actor on `integration-pr-required` ruleset

### Future

Apply this pattern to any new workflows requiring elevated permissions.

## Alternatives Considered

### Personal Access Token (PAT)

```yaml
token: ${{ secrets.PAT }}
```

**Rejected**: Tied to individual user account, security risk if compromised, no fine-grained permissions.

### Deploy Key

```yaml
ssh-key: ${{ secrets.DEPLOY_KEY }}
```

**Rejected**: SSH-based (different auth mechanism), limited to read/write, no API access.

### Fine-Grained PAT

**Rejected**: Still tied to user account, expires, requires user management.

### Keep Using GITHUB_TOKEN with Relaxed Rules

**Rejected**: Would require removing important branch protections, reducing security.

## Related

- [GitHub App Authentication](../ci/github-app-auth.md) - Detailed usage guide
- [ADR-010: Linear History and Rebase Workflow](010-linear-history-rebase.md) - Ruleset context
- [ADR-011: Full Atomization Model](011-full-atomization-model.md) - W2 workflow context
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token) - Official action
- [github-app-x-auth](https://github.com/aRustyDev/github-app-x-auth) - The GitHub App used
