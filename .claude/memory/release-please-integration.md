# Release-Please Integration

> Agent Reference: GitHub Actions release automation for Helm charts

## Table of Contents

| Section | Lines | Description |
|---------|-------|-------------|
| [Overview](#overview) | 12-25 | Architecture and key components |
| [Known Issues](#known-issues) | 27-60 | Permission errors and workarounds |
| [Workflow Structure](#workflow-structure) | 62-100 | Job flow and conditions |
| [Token Strategy](#token-strategy) | 102-130 | GITHUB_TOKEN vs App token usage |
| [Troubleshooting](#troubleshooting) | 132-180 | Common errors and solutions |
| [Evidence](#evidence) | 182-250 | Analysis records and experiments |

---

## Overview

**Workflow File**: `.github/workflows/release-please.yaml`

### Architecture

1. **release-please job**: Creates/updates release PRs, processes pending releases
2. **release-charts job**: Publishes charts to GHCR, updates charts branch

### Key Components

- **1Password Integration**: Loads GitHub App credentials (`op://gh-shared/xauth/app/*`)
- **GitHub App**: `x-repo-auth` - creates PRs that trigger CI workflows
- **Labels**: `autorelease: pending` → `autorelease: tagged` lifecycle

---

## Known Issues

### Issue: "Resource not accessible by integration"

**Symptom**: release-please fails when creating GitHub releases via Octokit API

**Affects**: Both `GITHUB_TOKEN` and GitHub App tokens

**Root Cause**: Unknown - possibly GitHub Actions app permission limitation

**Solution**: Use `gh release create` CLI instead of release-please internal API

```yaml
# Working approach
gh release create "$tag_name" --target "$sha" --title "$title" --notes "$notes"
```

### Issue: "Untagged, merged release PRs outstanding"

**Symptom**: release-please aborts when merged PRs have `autorelease: pending` label

**Solution**: Process pending releases BEFORE running release-please

```yaml
# Check for pending PRs
pending_prs=$(gh pr list --state merged --label "autorelease: pending" ...)
# Create releases for each
gh release create ...
# Update label
gh pr edit "$pr_number" --remove-label "autorelease: pending" --add-label "autorelease: tagged"
```

---

## Workflow Structure

### Job: release-please

**Trigger**: Push to main, workflow_dispatch

**Steps**:
1. Checkout repository
2. Process pending releases (create releases, update labels)
3. Load 1Password secrets
4. Generate GitHub App token
5. Run release-please action (skip-github-release: true)

**Outputs**:
- `releases_created`: true if release-please detected releases
- `pending_releases_created`: true if pending releases were processed
- Chart-specific outputs: `cloudflared--tag_name`, `cloudflared--version`, etc.

### Job: release-charts

**Condition**:
```yaml
if: >
  always() && (
    needs.release-please.outputs.releases_created == 'true' ||
    needs.release-please.outputs.pending_releases_created == 'true' ||
    inputs.force_release == true
  )
```

**Steps**:
1. Chart-releaser (pushes to charts branch, creates Helm releases)
2. Sign release assets with Cosign
3. Push to GHCR
4. Generate attestations

---

## Token Strategy

### GitHub App Token (`x-repo-auth`)

**Used For**: Creating release PRs

**Reason**: PRs created with `GITHUB_TOKEN` don't trigger CI workflows

**Configuration**:
```yaml
- uses: 1password/load-secrets-action@v2
  env:
    X_REPO_AUTH_APP_ID: op://gh-shared/xauth/app/id
    X_REPO_AUTH_PRIVATE_KEY: op://gh-shared/xauth/app/private-key.pem
```

### GITHUB_TOKEN

**Used For**: Creating releases, updating labels, GHCR push

**Reason**: Works with `gh` CLI even though release-please Octokit calls fail

---

## Troubleshooting

### Error: Release creation fails

**Check**:
1. PR label is `autorelease: pending` (not already `tagged`)
2. Release doesn't already exist: `gh release view <tag>`
3. Tag format matches: `<chart>-v<version>` (e.g., `cloudflared-v0.4.0`)

**Fix**: Manually create release and update label:
```bash
gh release create cloudflared-v0.4.0 --target main --title "cloudflared: v0.4.0" --notes "..."
gh pr edit <pr_number> --remove-label "autorelease: pending" --add-label "autorelease: tagged"
```

### Error: release-charts job doesn't run

**Check**: Outputs from release-please job
- `releases_created` should be `true`
- Or `pending_releases_created` should be `true`

**Fix**: Use `force_release` input:
```bash
gh workflow run release-please.yaml --field force_release=true
```

### Error: CI not triggering on release PR

**Check**: PR was created by GitHub App (not `github-actions[bot]`)

**Fix**: Verify 1Password secrets are accessible and App token is generated

---

## Evidence

### Experiment: GITHUB_TOKEN for releases

**Date**: 2026-01-14
**Result**: Failed with "Resource not accessible by integration"
**Commit**: `de97f86`

### Experiment: GitHub App token for releases

**Date**: 2026-01-14
**Result**: Same error
**Commit**: `97f98c6`

### Experiment: Split workflow (App for PRs, GITHUB_TOKEN for releases)

**Date**: 2026-01-14
**Result**: Same error
**Commit**: `4f9fa2d`

### Solution: gh CLI for release creation

**Date**: 2026-01-14
**Result**: SUCCESS
**Commits**: `75c7628`, `e1a7ea7`

### Related Issues

- Issue #39: PRs not triggering CI (solved with GitHub App)
- Issue #42: Release creation permission error (solved with gh CLI)

### API Behavior Difference

| Method | Token | Result |
|--------|-------|--------|
| release-please Octokit | GITHUB_TOKEN | "Resource not accessible by integration" |
| release-please Octokit | App token | "Resource not accessible by integration" |
| `gh release create` | GITHUB_TOKEN | SUCCESS |
| `gh release create` | Personal PAT | SUCCESS |

---

## Related Files

- `.github/workflows/release-please.yaml` - Main workflow
- `.github/workflows/lint-test.yaml` - CI checks (has skip logic for release PRs)
- `release-please-config.json` - Chart configurations
- `.release-please-manifest.json` - Version tracking
