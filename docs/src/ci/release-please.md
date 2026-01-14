# Release Please Workflow

**File:** `.github/workflows/release-please.yaml`

**Trigger:** Push to `main` branch, or manual `workflow_dispatch`

## Overview

[Release Please](https://github.com/googleapis/release-please) automates semantic versioning and changelog generation based on [Conventional Commits](https://www.conventionalcommits.org/).

This workflow handles the complete release lifecycle for Helm charts:
1. Creates release PRs when changes are detected
2. Creates GitHub releases when PRs are merged
3. Publishes charts to GitHub Container Registry (GHCR)
4. Signs releases with Cosign

## How It Works

### High-Level Flow

```
Push to main
     │
     ▼
Process any pending releases
(PRs with "autorelease: pending" label)
     │
     ▼
Release Please analyzes commits
     │
     ├── No releasable changes → Done
     │
     └── Releasable changes found
              │
              ▼
         Create/update release PR
         (with "autorelease: pending" label)
              │
              ▼
         CI runs on PR (lint-test, etc.)
              │
              ▼
         PR merged by maintainer
              │
              ▼
         Next workflow run creates release
         (updates label to "autorelease: tagged")
              │
              ▼
         release-charts job publishes to GHCR
```

### Detailed Steps

1. **Process Pending Releases** - Checks for merged PRs with `autorelease: pending` label and creates GitHub releases for them
2. **Analyze Commits** - Release Please scans commits since last release
3. **Create Release PR** - If releasable changes found, creates/updates a release PR
4. **On Merge** - When release PR is merged, the next workflow run creates the GitHub release
5. **Publish Charts** - The `release-charts` job pushes to GHCR and signs with Cosign

## Commit Types and Version Bumps

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat:` | Minor (0.x.0) | `feat(cloudflared): add ingress support` |
| `fix:` | Patch (0.0.x) | `fix(cloudflared): correct service port` |
| `feat!:` or `BREAKING CHANGE:` | Major (x.0.0) | `feat!: remove deprecated values` |
| `ci:`, `docs:`, `chore:` | No bump | `ci: update workflow` |

## Configuration

### release-please-config.json

```json
{
  "packages": {
    "charts/cloudflared": {
      "release-type": "helm",
      "package-name": "cloudflared"
    },
    "charts/olm": {
      "release-type": "helm",
      "package-name": "holmes"
    },
    "charts/mdbook-htmx": {
      "release-type": "helm",
      "package-name": "mdbook-htmx"
    }
  },
  "separate-pull-requests": true
}
```

### .release-please-manifest.json

Tracks current versions for each package:

```json
{
  "charts/cloudflared": "0.4.0",
  "charts/olm": "0.1.0",
  "charts/mdbook-htmx": "0.2.1"
}
```

## Token Strategy

The workflow uses two different tokens for different purposes:

### GitHub App Token (`x-repo-auth`)

**Used for:** Creating release PRs

**Why:** PRs created with the standard `GITHUB_TOKEN` don't trigger CI workflows due to a GitHub security limitation. Using a GitHub App token ensures CI runs on release PRs.

**Source:** Loaded from 1Password via `1password/load-secrets-action`

### GITHUB_TOKEN

**Used for:** Creating GitHub releases, updating PR labels, pushing to GHCR

**Why:** Works reliably with the `gh` CLI for release creation.

## Known Limitations and Workarounds

### Issue: "Resource not accessible by integration"

The release-please action's internal Octokit API calls fail with "Resource not accessible by integration" when trying to create GitHub releases. This affects both `GITHUB_TOKEN` and GitHub App tokens.

**Workaround:** The workflow uses `skip-github-release: true` in release-please and creates releases manually using the `gh` CLI, which works correctly.

### Issue: "Untagged, merged release PRs outstanding"

Release-please aborts when it finds merged PRs that still have the `autorelease: pending` label.

**Workaround:** The workflow processes pending releases BEFORE running release-please. This ensures all merged PRs have their releases created and labels updated.

## Manual Operations

### Force Release Charts

If the `release-charts` job didn't run (e.g., due to a transient failure), you can manually trigger it:

```bash
gh workflow run release-please.yaml --field force_release=true
```

### Create a Release Manually

If automated release creation fails:

```bash
# Create the release
gh release create cloudflared-v0.4.0 \
  --target main \
  --title "cloudflared: v0.4.0" \
  --notes "## Features
- Add Prometheus metrics support
- Add Linkerd integration"

# Update the PR label
gh pr edit <pr_number> --remove-label "autorelease: pending" --add-label "autorelease: tagged"
```

### Check Release Status

```bash
# List recent releases
gh api /repos/OWNER/REPO/releases --jq '.[0:5] | .[] | {tag_name, name, created_at}'

# Check for pending release PRs
gh pr list --state merged --label "autorelease: pending"
```

## Orphan Branches

Release Please creates branches like `release-please--branches--main--components--<chart>`. These are cleaned up automatically by the [cleanup workflow](./cleanup.md) if no PR exists and they're older than 7 days.

## Troubleshooting

### Release PR not created

1. Check that commits follow [Conventional Commits](https://www.conventionalcommits.org/) format
2. Verify changes are in a tracked package path (e.g., `charts/cloudflared/`)
3. Check workflow logs for errors

### CI not running on release PR

1. Verify PR was created by the GitHub App (author should be `app/x-repo-auth`, not `github-actions[bot]`)
2. Check 1Password secrets are accessible
3. Review workflow logs for token generation errors

### release-charts job skipped

The job runs when ANY of these conditions is true:
- `releases_created == 'true'` (release-please detected releases)
- `pending_releases_created == 'true'` (pending releases were processed)
- `force_release == true` (manually triggered)

If none are true, use `gh workflow run release-please.yaml --field force_release=true`

### Release not created after PR merge

1. Check the PR has `autorelease: pending` label (not `tagged`)
2. Wait for the next push to main or manually trigger the workflow
3. Check workflow logs for the "Process pending releases" step

## Related Documentation

- [Release Workflow](./release.md) - Chart publishing details
- [Lint Test Workflow](./lint-test.md) - CI checks for PRs
- [Cleanup Workflow](./cleanup.md) - Orphan branch cleanup
