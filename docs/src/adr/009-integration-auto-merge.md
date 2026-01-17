# ADR-009: Trust-Based Auto-Merge for Integration Branch

**Status:** Accepted
**Date:** 2025-01-17

## Context

The CI pipeline has two merge points that currently require manual intervention:
1. PRs to `integration` branch (W1 validation)
2. PRs to `main` branch (W5 validation)

Manual merging creates bottlenecks and slows down the development workflow. However, fully automated merging raises security concerns about untrusted contributions.

## Decision

Implement trust-based auto-merge for PRs to the `integration` branch:

| Condition | Auto-Merge? |
|-----------|-------------|
| Trusted contributor (in CODEOWNERS) + Verified commits | Yes |
| Trusted contributor + Unverified commits | No |
| Unknown contributor | No |

PRs to `main` continue to require human review.

### Implementation

1. **W1 workflow** includes an `enable-automerge` job that:
   - Checks if PR author is listed in `.github/CODEOWNERS`
   - Verifies all commits are signed (GPG or SSH)
   - Enables GitHub's native auto-merge only if both conditions pass

2. **CODEOWNERS file** defines trusted contributors who can have PRs auto-merged

3. **GitHub's native auto-merge** respects all branch protection rules

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

### Negative
- New contributors must wait for manual review
- Contributors must set up commit signing
- CODEOWNERS file must be maintained
- Auto-merge setting must be enabled in repository settings

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

### Auto-merge all passing PRs
Rejected because it allows any contributor to merge without review, creating security risk.

### Require manual approval for all PRs
Rejected because it creates unnecessary bottlenecks for trusted contributors.

### Path-based auto-merge (charts only)
Considered but deferred. Can be added later by modifying the `enable-automerge` job to check changed paths.

### GitHub App token for auto-merge
Rejected because GitHub's native auto-merge with `GITHUB_TOKEN` is sufficient and simpler.

## Related

- [ADR-008: Repository Dispatch for Workflow Automation](008-repository-dispatch-automation.md)
- [Workflow 1: Validate Contribution PR](.github/workflows/validate-contribution-pr.yaml)
- [CODEOWNERS](.github/CODEOWNERS)
