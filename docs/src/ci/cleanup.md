# Cleanup Branches Workflow

**File:** `.github/workflows/cleanup-branches.yaml`

**Triggers:**
- Weekly schedule (Sundays at midnight UTC)
- Manual dispatch

## Overview

Automatically detects and removes orphan branches that no longer have associated pull requests. This primarily targets:

- `release-please--*` branches (created by Release Please)
- `dependabot/*` branches (created by Dependabot)

## How It Works

1. **Scan Branches** - Lists all remote branches
2. **Filter by Pattern** - Only considers branches matching cleanup patterns
3. **Check for Open PRs** - Skips branches with open pull requests
4. **Check Age** - Only deletes branches older than 7 days
5. **Delete** - Removes orphan branches (unless dry run)

## Protected Branches

The following branches are never deleted:
- `main`
- `charts`

## Manual Usage

### Dry Run (Default)

```bash
gh workflow run cleanup-branches.yaml
```

Lists orphan branches without deleting them.

### Actually Delete

```bash
gh workflow run cleanup-branches.yaml -f dry_run=false
```

## Why This Is Needed

### Release Please Branches

Release Please creates branches like:
```
release-please--branches--main--components--mdbook-htmx
```

These branches remain after:
- Release Please determines no release is needed
- A release PR is closed without merging
- Manual intervention interrupts the release process

### Dependabot Branches

Dependabot creates branches like:
```
dependabot/github_actions/actions/checkout-6
```

These may remain after:
- PRs are closed without merging
- Dependabot recreates updates on a new branch

## Configuration

| Setting | Value | Notes |
|---------|-------|-------|
| Cleanup patterns | `release-please--`, `dependabot/` | Branches starting with these |
| Minimum age | 7 days | Won't delete recent branches |
| Schedule | Weekly (Sunday 00:00 UTC) | Cron: `0 0 * * 0` |
