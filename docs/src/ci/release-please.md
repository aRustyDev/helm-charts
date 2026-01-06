# Release Please Workflow

**File:** `.github/workflows/release-please.yaml`

**Trigger:** Push to `main` branch

## Overview

[Release Please](https://github.com/googleapis/release-please) automates semantic versioning and changelog generation based on [Conventional Commits](https://www.conventionalcommits.org/).

## How It Works

1. **Analyze Commits** - Scans commits since last release
2. **Create Release PR** - If releasable changes found, creates/updates a release PR
3. **On Merge** - When release PR is merged, creates GitHub releases and tags
4. **Trigger Charts Release** - The `release-charts` job publishes to GHCR

## Commit Types and Version Bumps

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `feat:` | Minor (0.x.0) | `feat(holmes): add ingress support` |
| `fix:` | Patch (0.0.x) | `fix(holmes): correct service port` |
| `feat!:` or `BREAKING CHANGE:` | Major (x.0.0) | `feat!: remove deprecated values` |
| `ci:`, `docs:`, `chore:` | No bump | `ci: update workflow` |

## Configuration

**`release-please-config.json`:**
```json
{
  "packages": {
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

**`.release-please-manifest.json`:**
```json
{
  "charts/olm": "0.1.0",
  "charts/mdbook-htmx": "0.1.0"
}
```

## Release Flow

```
Commit to main
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
              │
              ▼
         PR merged by maintainer
              │
              ▼
         Create GitHub release + tag
              │
              ▼
         Trigger release-charts job
              │
              ▼
         Push to GHCR + Sign with Cosign
```

## Orphan Branches

Release Please creates branches like `release-please--branches--main--components--<chart>`. These are cleaned up automatically by the [cleanup workflow](./cleanup.md) if no PR exists and they're older than 7 days.
