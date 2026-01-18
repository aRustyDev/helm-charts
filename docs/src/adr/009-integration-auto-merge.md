# ADR-009: Trust-Based Auto-Merge

## Status

Accepted (Updated 2025-01-18)

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
| PR targets allowed branch + Trusted contributor + Verified commits | Yes |
| Missing any condition | No |

PRs to `main` continue to require human review (not in `AUTO_MERGE_ALLOWED_BRANCHES`).

### Implementation

1. **Separate workflow** (`auto-merge.yaml`) that:
   - Triggers on `workflow_run` of W1 completing successfully
   - **Runs from default branch (main)**, not the PR branch
   - Checks if PR targets an allowed branch (configurable)
   - Checks if PR author is listed in `.github/CODEOWNERS`
   - Verifies all commits are signed (GPG or SSH)
   - Enables GitHub's native auto-merge only if all conditions pass

2. **W1 workflow** remains focused on validation only (lint, ArtifactHub, commits)

3. **CODEOWNERS file** defines trusted contributors who can have PRs auto-merged

4. **GitHub's native auto-merge** respects all branch protection rules

5. **Configurable allowed branches** via GitHub repository variable

### Why `workflow_run` Trigger?

The `workflow_run` event has a critical property: **it runs from the default branch (main)**, regardless of which branch triggered the source workflow.

```yaml
on:
  workflow_run:
    workflows: ["Validate Contribution PR"]
    types: [completed]
    # No branches filter - filtering done inside workflow via
    # vars.AUTO_MERGE_ALLOWED_BRANCHES to support configurable targets
```

This means:
- Auto-merge workflow always runs the version from `main`
- No need to keep workflow files synced between branches
- Updates to auto-merge logic apply immediately
- Decouples validation (W1) from merge automation

### Branch Filtering

Allowed target branches are configured via **GitHub repository variable**:

| Setting | Location | Default |
|---------|----------|---------|
| `AUTO_MERGE_ALLOWED_BRANCHES` | Settings → Secrets and variables → Actions → Variables | `integration` |

The workflow:
1. Finds the PR that triggered W1
2. Checks if PR's base branch is in the allowed list
3. Logs warning and skips if targeting non-allowed branch (e.g., `main`)

This prevents auto-merge from accidentally enabling on PRs to protected branches.

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

### Why configurable allowed branches?
- Flexibility for different repository configurations
- Can expand to multiple branches (e.g., `integration,staging`)
- Easy to disable by clearing the variable
- No code changes required to modify policy

### Why auto-merge only to integration by default?
- `integration` branch is a staging area, not production
- PRs to `main` represent release candidates that warrant human review
- Reduces friction for trusted contributors while maintaining security gates

## Consequences

### Positive
- Faster merge cycles for trusted contributors
- Reduced maintainer burden for routine PRs
- Clear security policy (branch + trust + verification)
- Full audit trail via GitHub workflow logs
- Branch protection rules still enforced
- **No workflow sync required** between branches
- **Configurable** without code changes

### Negative
- New contributors must wait for manual review
- Contributors must set up commit signing
- CODEOWNERS file must be maintained
- Auto-merge setting must be enabled in repository settings
- Slight delay (workflow_run triggers after W1 completes)
- Requires GitHub variable configuration

## Configuration Required

### Repository Settings
1. Enable "Allow auto-merge" in repository settings

### Repository Variables
| Variable | Value | Purpose |
|----------|-------|---------|
| `AUTO_MERGE_ALLOWED_BRANCHES` | `integration` | Comma-separated list of allowed base branches |

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

### Hardcoded branch list in workflow
Rejected in favor of GitHub variable for flexibility and easier policy changes.

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
- [Auto-Merge Workflow](.github/workflows/auto-merge.yaml)
- [Workflow 1: Validate Contribution PR](.github/workflows/validate-contribution-pr.yaml)
- [CODEOWNERS](.github/CODEOWNERS)
- [Test Plan](/.claude/plans/chart-release-workflows/tests/plan.md)
