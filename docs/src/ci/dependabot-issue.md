# Dependabot Issue Workflow

**File:** `.github/workflows/dependabot-issue.yml`

**Trigger:** Pull request opened by Dependabot

## Overview

Creates tracking issues when Dependabot opens pull requests for dependency updates.

## Behavior

When Dependabot opens a PR:
1. Workflow detects the PR author is `dependabot[bot]`
2. Creates a tracking issue with:
   - Title matching the PR title
   - Labels: `dependencies`, `github-actions`
   - Link to the Dependabot PR

## Note on Auto-Closing

Dependabot PRs do **not** automatically include `Closes #X` keywords, so tracking issues created by this workflow must be manually closed after the PR is merged.

**Alternatives:**
- Don't create tracking issues (PRs already track the work)
- Add a workflow to auto-close issues when Dependabot PRs merge
- Manually add `Closes #X` to Dependabot PR descriptions

## Configuration

Dependabot is configured in `.github/dependabot.yml`:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    commit-message:
      prefix: "ci"
    labels:
      - "dependencies"
      - "github-actions"
```
