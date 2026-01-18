# ADR-009: Trust-Based Auto-Merge for Integration Branch

## Status

Accepted (Updated 2025-01-17)

## Context

The CI pipeline has two merge points that currently require manual intervention:
1. PRs to `integration` branch (W1 validation)
2. PRs to `main` branch (W5 validation)

Manual merging creates bottlenecks and slows down the development workflow. However, fully automated merging raises security concerns about untrusted contributions.

### Architectural Consideration

Embedding auto-merge logic in W1 creates a **sync dependency** - the `integration` branch must always have the latest W1 workflow to get auto-merge functionality. This is fragile because:
- PRs to `integration` run the workflow from the base branch
- Workflow updates on `main` don't automatically apply to `integration`
- Creates chicken-and-egg problems when testing workflow changes

## Decision

Implement trust-based auto-merge as a **separate workflow** using `workflow_run` trigger:

| Condition | Auto-Merge? |
|-----------|-------------|
| Trusted contributor (in CODEOWNERS) + Verified commits | Yes |
| Trusted contributor + Unverified commits | No |
| Unknown contributor | No |

PRs to `main` continue to require human review.

### Implementation

1. **Separate workflow** (`auto-merge-integration.yaml`) that:
   - Triggers on `workflow_run` of W1 completing successfully
   - **Runs from default branch (main)**, not the PR branch
   - Checks if PR author is listed in `.github/CODEOWNERS`
   - Verifies all commits are signed (GPG or SSH)
   - Enables GitHub's native auto-merge only if both conditions pass

2. **W1 workflow** remains focused on validation only (lint, ArtifactHub, commits)

3. **CODEOWNERS file** defines trusted contributors who can have PRs auto-merged

4. **GitHub's native auto-merge** respects all branch protection rules

### Why `workflow_run` Trigger?

The `workflow_run` event has a critical property: **it runs from the default branch (main)**, regardless of which branch triggered the source workflow.

```yaml
on:
  workflow_run:
    workflows: ["Validate Contribution PR"]
    types: [completed]
    branches: [integration]
```

This means:
- Auto-merge workflow always runs the version from `main`
- No need to keep workflow files synced between branches
- Updates to auto-merge logic apply immediately
- Decouples validation (W1) from merge automation

## Rationale

### Why CODEOWNERS for trust?
- Already used by GitHub for review assignments
- Easy to audit and maintain
- Supports path-specific ownership (future extensibility)
- No external systems or tokens required

### Why commit signing?
- Cryptographically verifies commit authorship
- Prevents impersonation attacks
- GitHub natively tracks verification status
- Standard security practice for sensitive repositories

### Why separate workflow?
- Runs from `main` branch regardless of PR target
- Eliminates workflow sync issues between branches
- Cleaner separation of concerns (validation vs. automation)
- Easier to test and update independently

### Why auto-merge only to integration?
- `integration` branch is a staging area, not production
- PRs to `main` represent release candidates that warrant human review
- Reduces friction for trusted contributors while maintaining security gates

## Consequences

### Positive
- Faster merge cycles for trusted contributors
- Reduced maintainer burden for routine PRs
- Clear security policy (trust + verification)
- Full audit trail via GitHub workflow logs
- Branch protection rules still enforced
- **No workflow sync required** between branches

### Negative
- New contributors must wait for manual review
- Contributors must set up commit signing
- CODEOWNERS file must be maintained
- Auto-merge setting must be enabled in repository settings
- Slight delay (workflow_run triggers after W1 completes)

## Configuration Required

### Repository Settings
1. Enable "Allow auto-merge" in repository settings

### Branch Protection (integration)
- Require pull request before merging: Yes
- Require status checks: Yes (lint, artifacthub-lint, commit-validation)
- Require branches up to date: No (allows concurrent PRs)
- Require review: Optional (0 for full automation with trusted contributors)

### CODEOWNERS
```
# Trusted contributors
* @username
```

## Alternatives Considered

### Embed auto-merge in W1
Initially implemented but **rejected** because it requires keeping W1 in sync between `main` and `integration` branches. The `workflow_run` approach is more robust.

### Auto-merge all passing PRs
Rejected because it allows any contributor to merge without review, creating security risk.

### Require manual approval for all PRs
Rejected because it creates unnecessary bottlenecks for trusted contributors.

### Path-based auto-merge (charts only)
Considered but deferred. Can be added later by modifying the auto-merge workflow to check changed paths.

### GitHub App token for auto-merge
Rejected because GitHub's native auto-merge with `GITHUB_TOKEN` is sufficient and simpler.

## Related

- [ADR-008: Repository Dispatch for Workflow Automation](008-repository-dispatch-automation.md)
- [Auto-Merge Workflow](.github/workflows/auto-merge-integration.yaml)
- [Workflow 1: Validate Contribution PR](.github/workflows/validate-contribution-pr.yaml)
- [CODEOWNERS](.github/CODEOWNERS)
