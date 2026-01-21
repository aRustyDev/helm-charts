# GitHub App Authentication in Workflows

This document describes the standard pattern for authenticating GitHub Actions workflows using a GitHub App token instead of `GITHUB_TOKEN`.

## Why Use a GitHub App Token?

The default `GITHUB_TOKEN` (also `github.token` or `secrets.GITHUB_TOKEN`) has limitations:

| Limitation | Impact |
|------------|--------|
| Cannot trigger other workflows | PRs/pushes made with `GITHUB_TOKEN` won't trigger `on: push` or `on: pull_request` workflows |
| Cannot bypass branch protection | Even with admin bypass configured on rulesets, `GITHUB_TOKEN` cannot utilize it |
| Limited to current repository | Cannot perform cross-repo operations |
| Associated with `github-actions[bot]` | All actions appear from the same bot account |

A GitHub App token solves these issues by acting as a first-class GitHub App with configurable permissions.

## Standard Pattern

There are two approaches to providing the GitHub App credentials:

### Option A: 1Password Integration (Preferred)

Use 1Password to securely store and retrieve the App credentials:

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
```

**Advantages of 1Password:**
- Centralized secret management across repositories
- Automatic secret rotation support
- Audit trail for secret access
- No need to duplicate secrets per repository

### Option B: GitHub Secrets (Simple)

Store credentials directly in GitHub repository secrets:

```yaml
jobs:
  generate-token:
    name: Generate App Token
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.app-token.outputs.token }}
    steps:
      - name: Generate GitHub App Token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

### 2. Consume Token in Dependent Jobs

Jobs that need elevated permissions should:
1. Depend on `generate-token`
2. Use the token from outputs

```yaml
  my-job:
    needs: [generate-token]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: ${{ needs.generate-token.outputs.token }}

      - name: Use gh CLI
        env:
          GH_TOKEN: ${{ needs.generate-token.outputs.token }}
        run: |
          gh pr create --title "My PR" --body "Created with app token"
```

### 3. Authenticated Git Push

For pushing to protected branches:

```yaml
      - name: Push with App Token
        env:
          GH_TOKEN: ${{ needs.generate-token.outputs.token }}
        run: |
          git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${{ github.repository }}.git"
          git push origin my-branch --force-with-lease
```

## Required Secrets

### With 1Password (Preferred)

| Secret | Description |
|--------|-------------|
| `OP_SERVICE_ACCOUNT_TOKEN` | 1Password Service Account token |

The App ID and private key are stored in 1Password at:
- `op://gh-shared/xauth/app/id` - GitHub App ID
- `op://gh-shared/xauth/app/private-key.pem` - Private key (PEM format)

### With GitHub Secrets

| Secret | Description | How to Obtain |
|--------|-------------|---------------|
| `APP_ID` | GitHub App ID | App settings page > App ID |
| `APP_PRIVATE_KEY` | Private key in PEM format | App settings > Private keys > Generate |

## Token Scoping

By default, tokens are scoped to the **current repository only**, even if the app is installed globally.

```yaml
# Default: scoped to current repo
- uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
```

To access other repositories (use sparingly):

```yaml
# Explicit multi-repo scope
- uses: actions/create-github-app-token@v1
  with:
    app-id: ${{ secrets.APP_ID }}
    private-key: ${{ secrets.APP_PRIVATE_KEY }}
    repositories: "repo1,repo2"
```

## GitHub App Requirements

### Minimum Permissions

Configure these in your GitHub App settings:

| Permission | Access | Common Use Cases |
|------------|--------|------------------|
| Contents | Read & Write | Push commits, create branches |
| Pull requests | Read & Write | Create/update PRs |
| Issues | Read & Write | Create issues |
| Metadata | Read | Required for all apps |

### Ruleset Bypass

If the workflow needs to bypass branch protection rules:

1. Go to: **Settings > Rules > Rulesets > [Your Ruleset]**
2. Scroll to **Bypass list**
3. Click **Add bypass**
4. Select your GitHub App
5. Set bypass mode to **Always**

## Complete Example

### With 1Password (Preferred)

```yaml
name: Example Workflow with App Token (1Password)

on:
  push:
    branches: [main]

permissions:
  contents: read  # Minimal permissions for GITHUB_TOKEN

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

  create-pr:
    name: Create PR
    needs: [generate-token]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: ${{ needs.generate-token.outputs.token }}

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Make changes and create PR
        env:
          GH_TOKEN: ${{ needs.generate-token.outputs.token }}
        run: |
          git checkout -b automated-changes
          echo "change" >> file.txt
          git add .
          git commit -m "chore: automated change"
          git push origin automated-changes
          gh pr create --title "Automated PR" --body "Created by workflow"
```

### With GitHub Secrets

```yaml
name: Example Workflow with App Token (GitHub Secrets)

on:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  generate-token:
    name: Generate App Token
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.app-token.outputs.token }}
    steps:
      - name: Generate GitHub App Token
        id: app-token
        uses: actions/create-github-app-token@v1
        with:
          app-id: ${{ secrets.APP_ID }}
          private-key: ${{ secrets.APP_PRIVATE_KEY }}

  create-pr:
    name: Create PR
    needs: [generate-token]
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          token: ${{ needs.generate-token.outputs.token }}

      - name: Make changes and create PR
        env:
          GH_TOKEN: ${{ needs.generate-token.outputs.token }}
        run: |
          gh pr create --title "Automated PR" --body "Created by workflow"
```

## When to Use This Pattern

Use GitHub App tokens when your workflow needs to:

- Push to protected branches
- Bypass branch protection rules
- Create PRs that should trigger other workflows
- Create commits with a custom author (not `github-actions[bot]`)
- Perform operations that `GITHUB_TOKEN` cannot

## Security Considerations

1. **Principle of least privilege**: Only request permissions the app actually needs
2. **Repository scoping**: Keep default single-repo scope unless cross-repo access is required
3. **Secret management**: Store `APP_PRIVATE_KEY` securely (1Password, etc.)
4. **Audit trail**: Actions taken with the app token are attributed to the app, providing traceability

## Related

- [ADR-012: GitHub App Token Pattern](../adr/012-github-app-token-pattern.md)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [GitHub Apps documentation](https://docs.github.com/en/apps)
