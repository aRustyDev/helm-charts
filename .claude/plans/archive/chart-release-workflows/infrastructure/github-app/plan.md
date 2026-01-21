# GitHub App Implementation Plan

## Overview

This plan covers the setup of the `helm-charts-release-bot` GitHub App required for protected branch and tag operations in W5 (Validate & SemVer Bump) and W6 (Atomic Tagging) workflows.

## Related Documents

- [ADR-010: GitHub App for Protected Branch and Tag Operations](../../adr/ADR-010-github-app-for-protected-operations.md)
- [Research Plan: Token Permissions](../../05-research-plan.md#1-token-permissions-research)
- [Components Index: GitHub App Requirements](../../components-index.md#16-github-app-required)

---

## Prerequisites

Before starting:
- [ ] Repository admin access
- [ ] Organization owner or admin access (to create GitHub Apps)
- [ ] Access to create repository secrets

---

## Phase 0.1: Create GitHub App

**Estimated Steps**: 8

### Step 1: Navigate to GitHub App Creation
1. Go to GitHub → Settings → Developer settings → GitHub Apps
2. Click "New GitHub App"

### Step 2: Configure Basic Settings
| Setting | Value |
|---------|-------|
| GitHub App name | `helm-charts-release-bot` |
| Description | Automated release bot for helm-charts repository. Pushes version bumps and creates release tags. |
| Homepage URL | `https://github.com/aRustyDev/helm-charts` |

### Step 3: Configure Webhook Settings
| Setting | Value |
|---------|-------|
| Active | **Unchecked** (webhook not needed) |

### Step 4: Configure Permissions
| Permission Category | Permission | Access Level | Purpose |
|---------------------|------------|--------------|---------|
| Repository | Contents | Read and write | Push commits, create/push tags |

**Important**: Do NOT grant additional permissions. Principle of least privilege.

### Step 5: Configure Installation Options
| Setting | Value |
|---------|-------|
| Where can this GitHub App be installed? | Only on this account |

### Step 6: Create the App
Click "Create GitHub App"

### Step 7: Note the App ID
After creation, note the **App ID** displayed at the top of the App settings page.
```
App ID: <note this value>
```

### Step 8: Generate Private Key
1. Scroll to "Private keys" section
2. Click "Generate a private key"
3. Download the `.pem` file
4. Store securely (will be added to repository secrets)

---

## Phase 0.2: Install App on Repository

### Step 1: Navigate to Installation
1. From the App settings page, click "Install App" in the left sidebar
2. Select your account

### Step 2: Configure Repository Access
| Setting | Value |
|---------|-------|
| Repository access | Only select repositories |
| Selected repositories | `helm-charts` |

### Step 3: Complete Installation
Click "Install"

---

## Phase 0.3: Store Credentials

### Step 1: Create Repository Variable
1. Navigate to Repository → Settings → Secrets and variables → Actions
2. Click "Variables" tab
3. Click "New repository variable"

| Field | Value |
|-------|-------|
| Name | `RELEASE_BOT_APP_ID` |
| Value | `<App ID from Phase 0.1 Step 7>` |

### Step 2: Create Repository Secret
1. Click "Secrets" tab
2. Click "New repository secret"

| Field | Value |
|-------|-------|
| Name | `RELEASE_BOT_PRIVATE_KEY` |
| Value | `<contents of .pem file from Phase 0.1 Step 8>` |

### Step 3: Verify Storage
Confirm both are listed:
- Variables: `RELEASE_BOT_APP_ID`
- Secrets: `RELEASE_BOT_PRIVATE_KEY`

### Step 4: Secure Cleanup
Delete the downloaded `.pem` file from local machine after storing in secrets.

---

## Phase 0.4: Configure Ruleset Bypass

### Step 1: Navigate to Rulesets
1. Repository → Settings → Rules → Rulesets

### Step 2: Update Main Branch Protection Ruleset
1. Click on the `main-protection` ruleset (or create if doesn't exist)
2. Scroll to "Bypass list"
3. Click "Add bypass"
4. Search for `helm-charts-release-bot`
5. Select the App
6. Set bypass mode: "Always"
7. Save changes

### Step 3: Update Tag Protection Ruleset
1. Click on the `release-tag-protection` ruleset (or create if doesn't exist)
2. Scroll to "Bypass list"
3. Click "Add bypass"
4. Search for `helm-charts-release-bot`
5. Select the App
6. Set bypass mode: "Always"
7. Save changes

### Step 4: Verify Bypass Configuration
Both rulesets should show `helm-charts-release-bot` in their bypass lists.

---

## Phase 0.5: Validation Testing

### Step 1: Create Test Workflow
Create `.github/workflows/test-release-bot.yml`:

```yaml
name: Test Release Bot

on:
  workflow_dispatch:

jobs:
  test-token:
    runs-on: ubuntu-latest
    steps:
      - name: Create GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ vars.RELEASE_BOT_APP_ID }}
          private-key: ${{ secrets.RELEASE_BOT_PRIVATE_KEY }}

      - name: Checkout with App token
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ steps.app-token.outputs.token }}

      - name: Configure git
        run: |
          git config user.name "helm-charts-release-bot[bot]"
          git config user.email "helm-charts-release-bot[bot]@users.noreply.github.com"

      - name: Test - Create and push test branch
        run: |
          BRANCH="test/release-bot-$(date +%s)"
          git checkout -b "$BRANCH"
          echo "Test: $(date)" > .test-release-bot
          git add .test-release-bot
          git commit -m "test: verify release bot permissions"
          git push origin "$BRANCH"
          echo "Successfully pushed to $BRANCH"

          # Cleanup
          git push origin --delete "$BRANCH"
          echo "Cleaned up test branch"

      - name: Test - Create and push test tag
        run: |
          TAG="test-release-bot-$(date +%s)"
          git tag -a "$TAG" -m "Test tag for release bot verification"
          git push origin "$TAG"
          echo "Successfully pushed tag $TAG"

          # Cleanup
          git push origin --delete "$TAG"
          echo "Cleaned up test tag"
```

### Step 2: Run Validation
1. Navigate to Actions tab
2. Select "Test Release Bot" workflow
3. Click "Run workflow"
4. Verify successful completion

### Step 3: Verify Audit Trail
1. Check repository → Insights → Pulse → Contributors
2. Verify `helm-charts-release-bot[bot]` appears in activity

### Step 4: Cleanup Test Workflow
After successful validation:
```bash
git rm .github/workflows/test-release-bot.yml
git commit -m "chore: remove release bot test workflow"
git push
```

---

## Implementation Checklist

### Phase 0.1: Create GitHub App
- [ ] Navigate to GitHub App creation page
- [ ] Configure basic settings (name, description, homepage)
- [ ] Disable webhook
- [ ] Set Contents permission to Read and write
- [ ] Restrict installation to this account only
- [ ] Create the App
- [ ] Note App ID
- [ ] Generate and download private key

### Phase 0.2: Install on Repository
- [ ] Navigate to Install App
- [ ] Select only `helm-charts` repository
- [ ] Complete installation

### Phase 0.3: Store Credentials
- [ ] Create `RELEASE_BOT_APP_ID` variable
- [ ] Create `RELEASE_BOT_PRIVATE_KEY` secret
- [ ] Delete local .pem file

### Phase 0.4: Configure Ruleset Bypass
- [ ] Add App to main branch protection bypass list
- [ ] Add App to tag protection bypass list

### Phase 0.5: Validation Testing
- [ ] Create test workflow
- [ ] Run and verify branch push
- [ ] Run and verify tag push
- [ ] Verify audit trail
- [ ] Remove test workflow

---

## Workflow Usage Template

After setup, use this pattern in W5 and W6 workflows:

```yaml
jobs:
  release:
    # CRITICAL: Prevent infinite loops from bot-triggered runs
    if: github.actor != 'helm-charts-release-bot[bot]'
    runs-on: ubuntu-latest

    steps:
      - name: Create GitHub App token
        id: app-token
        uses: actions/create-github-app-token@v2
        with:
          app-id: ${{ vars.RELEASE_BOT_APP_ID }}
          private-key: ${{ secrets.RELEASE_BOT_PRIVATE_KEY }}

      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ steps.app-token.outputs.token }}

      - name: Configure git identity
        run: |
          git config user.name "helm-charts-release-bot[bot]"
          git config user.email "helm-charts-release-bot[bot]@users.noreply.github.com"

      # ... rest of workflow ...

      - name: Push changes
        run: |
          git push origin HEAD
          # Or for tags:
          # git push origin --tags
```

---

## Security Considerations

### Token Lifetime
- Tokens from `actions/create-github-app-token` are short-lived (1 hour)
- Tokens are automatically scoped to the repository

### Private Key Security
- Private key stored as encrypted repository secret
- Never logged or exposed in workflow outputs
- Only accessible to workflows in this repository

### Audit Trail
- All operations appear as `helm-charts-release-bot[bot]`
- Easy to filter in commit history and activity logs

### Revocation
If compromised:
1. Navigate to App settings
2. Click "Revoke all user tokens"
3. Generate new private key
4. Update `RELEASE_BOT_PRIVATE_KEY` secret

---

## Troubleshooting

### Error: "Resource not accessible by integration"
- **Cause**: App lacks required permissions
- **Fix**: Verify Contents permission is set to "Read and write"

### Error: "Protected branch update failed"
- **Cause**: App not in ruleset bypass list
- **Fix**: Add App to ruleset's Bypass list (Phase 0.4)

### Error: "Could not create app token"
- **Cause**: Invalid App ID or private key
- **Fix**: Verify `RELEASE_BOT_APP_ID` variable and `RELEASE_BOT_PRIVATE_KEY` secret

### Error: "App installation not found"
- **Cause**: App not installed on repository
- **Fix**: Complete Phase 0.2 installation steps

---

## Dependencies

This infrastructure must be completed before:
- **W5: Validate & SemVer Bump** - Pushes version bump commits to PR branches
- **W6: Atomic Tagging** - Creates and pushes release tags

---

## References

- [GitHub Apps Documentation](https://docs.github.com/en/apps)
- [Creating a GitHub App](https://docs.github.com/en/apps/creating-github-apps)
- [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
- [About Rulesets](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
