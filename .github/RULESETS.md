# GitHub Rulesets Configuration

This document describes the GitHub Rulesets configured for this repository.

## Overview

GitHub Rulesets provide branch protection that:
- Cannot be bypassed by administrators (unless explicitly configured)
- Apply to multiple branches via patterns
- Support fine-grained push restrictions

## Active Rulesets

### Ruleset 1: Protected Branches - Linear History

**ID**: 11925113
**Purpose**: Enforce linear history on all protected branches to prevent merge commits that complicate commit validation.

| Setting | Value |
|---------|-------|
| **Ruleset Name** | `protected-branches-linear` |
| **Enforcement** | Active |
| **Bypass list** | None (no bypass allowed) |
| **Target branches** | `refs/heads/main`, `refs/heads/integration`, `refs/heads/release` |

**Rules**:

| Rule | Enabled | Notes |
|------|---------|-------|
| Require linear history | Yes | Forces squash or rebase merge |
| Block force pushes | Yes | Protects history (`non_fast_forward`) |
| Block deletions | Yes | Prevents accidental deletion |

### Ruleset 2: Main Branch - Strict Protection

**ID**: 11925117
**Purpose**: Require PRs with approval and comprehensive status checks for main branch.

| Setting | Value |
|---------|-------|
| **Ruleset Name** | `main-strict` |
| **Enforcement** | Active |
| **Bypass list** | None |
| **Target branches** | `refs/heads/main` |

**Rules**:

| Rule | Enabled | Configuration |
|------|---------|---------------|
| Require pull request | Yes | Required approvals: 1, dismiss stale reviews, require thread resolution |
| Require status checks | Yes | `artifacthub-lint`, `helm-lint`, `k8s-test (v1.32.11)`, `k8s-test (v1.33.7)`, `k8s-test (v1.34.3)` |
| Allowed merge methods | - | Squash, Rebase (no merge commits) |

### Ruleset 3: Integration Branch - PR Required

**ID**: 11925122
**Purpose**: Require PRs for integration branch with validation checks, allow auto-merge.

| Setting | Value |
|---------|-------|
| **Ruleset Name** | `integration-pr-required` |
| **Enforcement** | Active |
| **Bypass list** | Repository Admin (actor_id: 5) |
| **Target branches** | `refs/heads/integration` |

**Rules**:

| Rule | Enabled | Configuration |
|------|---------|---------------|
| Require pull request | Yes | Required approvals: 0 (auto-merge allowed) |
| Require status checks | Yes | `lint`, `artifacthub-lint`, `commit-validation` |
| Allowed merge methods | - | Squash, Rebase (no merge commits) |

**Bypass Note**: The admin bypass allows the `sync-main-to-branches` workflow to push directly when syncing integration with main.

### Ruleset 4: Release Branch - Automation Only

**ID**: 11925124
**Purpose**: Protect release branch for automation workflows.

| Setting | Value |
|---------|-------|
| **Ruleset Name** | `release-automation` |
| **Enforcement** | Active |
| **Bypass list** | None |
| **Target branches** | `refs/heads/release` |

**Rules**:

| Rule | Enabled | Configuration |
|------|---------|---------------|
| Require pull request | Yes | Required approvals: 0 |
| Allowed merge methods | - | Squash, Rebase |

**Note**: Linear history, block force push, and block deletion are inherited from Ruleset 1.

### Ruleset 5: Hotfix Branches - Admin Only

**ID**: 11925126
**Purpose**: Allow admins to create hotfix branches that merge directly to main.

| Setting | Value |
|---------|-------|
| **Ruleset Name** | `hotfix-branches-admin-only` |
| **Enforcement** | Active |
| **Bypass list** | Repository administrators |
| **Target branches** | `refs/heads/hotfix/**` |

**Rules**:

| Rule | Enabled | Configuration |
|------|---------|---------------|
| Restrict creations | Yes | Only admins can create (others blocked) |
| Require linear history | Yes | Keeps history clean |

### Ruleset 6: Tags - Immutable Release Tags

**ID**: 11880166
**Purpose**: Protect release tags from modification or deletion.

| Setting | Value |
|---------|-------|
| **Ruleset Name** | `tags: immutable release tags` |
| **Enforcement** | Active |
| **Bypass list** | None |
| **Target tags** | All tags |

**Rules**:

| Rule | Enabled | Notes |
|------|---------|-------|
| Block deletions | Yes | Released tags cannot be deleted |
| Block updates | Yes | Released tags cannot be force-updated |

## Hotfix Workflow

When a critical fix is needed that cannot wait for the normal integration flow:

1. **Create Issue**: Document the hotfix need in a GitHub issue
2. **Label Issue**: Add the `hotfix` label (admin only)
3. **Workflow Creates Branch**: Automatically creates `hotfix/<issue-number>` from `main`
4. **Make Fix**: Commit changes with conventional commit format
   ```bash
   git fetch origin
   git checkout hotfix/123
   git commit -S -m "fix(chart): critical security patch

   Fixes #123"
   git push origin hotfix/123
   ```
5. **Create PR**: Open PR from `hotfix/123` to `main`
   ```bash
   gh pr create --base main --title "fix: hotfix for #123"
   ```
6. **Review & Merge**: Get approval (required by `main-strict`) and squash merge
7. **Sync**: The sync workflow automatically updates integration with main changes

## Branch Flow Diagram

```
                                    hotfix/* ──────────┐
                                        │              │
                                        │ (direct PR)  │
                                        ▼              │
   feature/* ──► integration ──► charts/* ──► main ◄──┘
                     │                          │
                     │                          ▼
                     │                      release
                     │                          │
                     └───────◄──── sync ◄───────┘
```

## Verification Commands

After configuration, verify the rulesets are working:

```bash
# List active rulesets
gh ruleset list

# View ruleset details
gh ruleset view <ruleset-id> --web

# Check what rules apply to a branch
gh ruleset check main
gh ruleset check integration

# Attempt direct push to main (should fail)
git checkout main
echo "test" >> README.md
git commit -m "test: direct push"
git push origin main
# Expected: remote: error: GH013: Repository rule violations found

# Verify linear history is enforced
git checkout -b test-merge
git merge integration  # Creates merge commit locally
# When attempting to push PR with merge commit:
# Expected: Merge will fail due to linear history requirement

# Attempt to create hotfix branch (non-admin should fail)
git checkout -b hotfix/999
git push origin hotfix/999
# Expected for non-admin: remote: error: GH013: Repository rule violations found
```

## API Management

Rulesets can be managed via the GitHub API:

```bash
# List all rulesets
gh api repos/aRustyDev/helm-charts/rulesets

# View specific ruleset
gh api repos/aRustyDev/helm-charts/rulesets/<ruleset-id>

# Create ruleset (example)
gh api repos/aRustyDev/helm-charts/rulesets --method POST --input ruleset.json

# Update ruleset
gh api repos/aRustyDev/helm-charts/rulesets/<ruleset-id> --method PUT --input ruleset.json

# Delete ruleset
gh api repos/aRustyDev/helm-charts/rulesets/<ruleset-id> --method DELETE
```

## Sync Workflow Configuration

The `sync-main-to-branches` workflow automatically syncs main to configured branches after each push. Configuration is managed via a repository variable.

**Variable**: `SYNC_BRANCH_CONFIG`
**Format**: `pattern1:strategy,pattern2:strategy,...`
**Current Value**: `integration:rebase,hotfix/*:ff-only,charts/*:ff-only,docs/*:ff-only`

| Pattern | Strategy | Behavior |
|---------|----------|----------|
| `integration` | `rebase` | Rebases integration onto main, preserving unique commits |
| `hotfix/*` | `ff-only` | Fast-forward only, skips if diverged |
| `charts/*` | `ff-only` | Fast-forward only, skips if diverged |
| `docs/*` | `ff-only` | Fast-forward only, skips if diverged |

To modify:
```bash
gh variable set SYNC_BRANCH_CONFIG --body "integration:rebase,hotfix/*:ff-only"
```

## References

- [GitHub Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets)
- [ADR-010: Linear History and Rebase Workflow](../docs/src/adr/010-linear-history-rebase.md)
- [Sync Workflow](workflows/sync-main-to-branches.yaml)
- [Hotfix Workflow](workflows/create-hotfix-branch.yaml)
