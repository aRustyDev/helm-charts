# Auto Assign Workflow

**File:** `.github/workflows/auto-assign.yml`

**Trigger:** Pull request opened

## Overview

Automatically assigns the pull request author as an assignee when a PR is opened.

## Configuration

Uses the [auto-assign-action](https://github.com/pozil/auto-assign-action) with default settings.

## Behavior

When a PR is opened:
1. The PR author is automatically added as an assignee
2. No reviewers are automatically assigned (manual review assignment)

This ensures PRs always have at least one assignee for accountability.
