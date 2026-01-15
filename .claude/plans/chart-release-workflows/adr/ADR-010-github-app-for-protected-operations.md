# ADR-010: GitHub App for Protected Branch and Tag Operations

## Status
Accepted

## Context
The attestation-backed release pipeline requires workflows to perform operations that are blocked by branch protection rules:

| Workflow | Operation | Why Protected |
|----------|-----------|---------------|
| W5 | Push version bump commit to PR branch | Branch protection requires PR review |
| W6 | Create annotated release tags | Tag protection prevents manual creation |
| W6 | Push tags to repository | Tag protection ruleset |

The default `GITHUB_TOKEN` provided to GitHub Actions workflows **cannot bypass** these protections, even when:
- The workflow is triggered by a trusted event
- The repository allows "Allow specified actors to bypass required pull requests"
- The actor is `github-actions[bot]`

### Key Finding
Classic branch protection's "Allow specified actors to bypass required pull requests" setting only allows pushing without a PR, but does **NOT** bypass required status checks. GitHub rulesets with a "Bypass list" are required for complete bypass.

**Error without proper bypass**:
```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: - 3 of 3 required status checks are expected.
```

## Decision
Create a dedicated GitHub App named `helm-charts-release-bot` with minimal permissions, added to ruleset bypass lists for protected operations.

### Required Permissions
| Permission | Access Level | Purpose |
|------------|--------------|---------|
| Contents | Read and write | Push commits, create/push tags |

### Implementation

#### 1. Create GitHub App
- Name: `helm-charts-release-bot`
- Homepage URL: Repository URL
- Webhook: Disabled (not needed)
- Permissions: Contents → Read and write
- Where can this app be installed: Only on this account

#### 2. Install on Repository
- Install the app on the `helm-charts` repository only

#### 3. Store Credentials
```yaml
# Repository variables
RELEASE_BOT_APP_ID: "<app-id>"

# Repository secrets
RELEASE_BOT_PRIVATE_KEY: "<private-key-pem>"
```

#### 4. Configure Ruleset Bypass
Add the GitHub App to the "Bypass list" for:
- `main-protection` ruleset
- `release-tag-protection` ruleset

#### 5. Workflow Usage
```yaml
jobs:
  release:
    # Prevent infinite loops from bot-triggered runs
    if: github.actor != 'helm-charts-release-bot[bot]'
    runs-on: ubuntu-latest
    steps:
      - name: Create GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ vars.RELEASE_BOT_APP_ID }}
          private-key: ${{ secrets.RELEASE_BOT_PRIVATE_KEY }}

      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ steps.app-token.outputs.token }}

      - name: Configure git
        run: |
          git config user.name "helm-charts-release-bot[bot]"
          git config user.email "helm-charts-release-bot[bot]@users.noreply.github.com"

      - name: Push changes
        run: git push origin main --tags
```

### Infinite Loop Prevention
The `if: github.actor != 'helm-charts-release-bot[bot]'` guard is **critical** to prevent:
1. Workflow pushes commit → triggers workflow
2. Workflow runs again → pushes commit → triggers workflow
3. Infinite loop

## Consequences

### Positive
- Clean separation of automated operations from human operations
- Minimal permissions (principle of least privilege)
- Clear audit trail - all bot actions attributed to `helm-charts-release-bot[bot]`
- Easy revocation if compromised - just delete the App
- Works with GitHub rulesets (modern approach)

### Negative
- Additional infrastructure to manage (App credentials)
- Private key must be securely stored
- App must be added to each relevant ruleset

### Mitigations
- Store private key as encrypted repository secret
- Document App setup in migration plan
- Use short-lived tokens via `actions/create-github-app-token`

## Alternatives Considered

### 1. Use existing 1Password-managed GitHub App
The repository already has 1Password integration for secrets.
- **Pros**: No new App to manage
- **Cons**: Shared credentials, less clear audit trail, may have broader permissions
- **Decision**: Create dedicated App for cleaner separation

### 2. Personal Access Token (PAT)
Use a PAT with repo permissions.
- **Rejected**: Tied to individual user, security risk, not recommended by GitHub

### 3. Deploy Keys
Use deploy keys with write access.
- **Rejected**: Cannot bypass branch protection rules, only for push/pull

### 4. Disable branch protection
Remove protection rules for automated operations.
- **Rejected**: Significantly weakens security posture

### 5. Use workflow_dispatch for protected operations
Trigger a separate workflow that runs with elevated permissions.
- **Rejected**: Adds complexity, still needs elevated token

## References
- [Letting GitHub Actions Push to Protected Branches](https://medium.com/ninjaneers/letting-github-actions-push-to-protected-branches-a-how-to-57096876850d) (Dec 2025)
- [GitHub App Best Practices](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/best-practices-for-creating-a-github-app)
- [About Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
