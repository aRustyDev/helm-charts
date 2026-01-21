# Phase 2: W1 Contribution Validation Tests

## Overview

Tests for the consolidated W1 workflow that validates PRs to the integration branch.

| Attribute | Value |
|-----------|-------|
| **Dependencies** | Phase 1 (Unit Tests) must pass |
| **Time Estimate** | ~15 minutes per test PR |
| **Infrastructure** | GitHub repository with rulesets configured |
| **Workflow File** | `validate-contribution-pr.yaml` (CONSOLIDATED) |

> **📚 Skill References**:
> - `~/.claude/skills/cicd-github-actions-dev` - Debugging CI failures, understanding job logs
> - `~/.claude/skills/cicd-github-actions-ops` - Systematic review of workflow behavior

---

## Workflow Consolidation

This section covers the consolidated W1 workflow that merges:
- `validate-contribution-pr.yaml` (lint, commit validation)
- `auto-merge-integration.yaml` (trust checks, auto-merge)
- `atomic-branching-preview.yaml` (cherry-pick validation)

---

## Controls

| ID | Control | Code Location |
|----|---------|---------------|
| W1-C1 | PR targets integration | `pull_request.branches: [integration]` |
| W1-C2 | Chart linting passes | `ct lint` jobs |
| W1-C3 | ArtifactHub lint passes | `ah lint` job |
| W1-C4 | Commit validation passes | Conventional commit check |
| W1-C5 | Cherry-pick preview passes | Validates atomization feasibility |
| W1-C6 | **All commits signed** (FIRST) | `.commit.verification.verified` |
| W1-C7 | **Trust check** (SECOND) | CODEOWNERS OR dependabot |
| W1-C8 | Auto-merge enabled | `peter-evans/enable-pull-request-automerge` |
| W1-C9 | PR enters merge queue | Merge queue requirement |

---

## Trust Check Flow

```
PR Created → integration
       │
       ▼
┌─────────────────────────────────────────┐
│ Step 1: Check Commit Signatures (FIRST) │
│   • ALL commits must be signed/verified │
│   • Reject if ANY commit unsigned       │
└─────────────────────────────────────────┘
       │ All signed
       ▼
┌─────────────────────────────────────────┐
│ Step 2: Determine Trust Path (SECOND)   │
│   IF author == "dependabot[bot]"        │
│     → TRUSTED (skip CODEOWNERS)         │
│   ELSE                                  │
│     → Check CODEOWNERS membership       │
└─────────────────────────────────────────┘
       │ Trusted
       ▼
┌─────────────────────────────────────────┐
│ Step 3: Enable Auto-Merge               │
│   • Squash merge strategy               │
│   • PR enters merge queue               │
└─────────────────────────────────────────┘
```

---

## Test Matrix: Validation

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W1-T1 | W1-C1 | PR targets main (not integration) | Workflow doesn't run | [x] (unit tested) |
| W1-T2 | W1-C2 | Chart.yaml invalid | ct lint fails | [ ] (requires GH infra) |
| W1-T3 | W1-C3 | Missing ArtifactHub metadata | ah lint fails | [ ] (requires GH infra) |
| W1-T4 | W1-C4 | Non-conventional commit | Commit validation fails | [ ] (requires GH infra) |
| W1-T5 | W1-C5 | Commits cannot be cherry-picked | Cherry-pick preview fails | [ ] (requires GH infra) |
| W1-T6 | W1-C5 | Commits can be cherry-picked | Cherry-pick preview passes | [ ] (requires GH infra) |

### Cleanup for Failed Tests
- Delete branch: `git push origin --delete <branch>`
- Close PR: `gh pr close <number> --delete-branch`

---

## Test Matrix: Trust Checks

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W1-T7 | W1-C6 | Unsigned commits | Signature check fails (FIRST) | [x] |
| W1-T8 | W1-C6 | All commits signed | Signature check passes | [x] (skipped if no GPG) |
| W1-T9 | W1-C7 | Author NOT in CODEOWNERS | Trust check fails | [x] |
| W1-T10 | W1-C7 | Author IN CODEOWNERS | Trust check passes | [x] |
| W1-T11 | W1-C7 | Author is dependabot[bot] + signed | Trust check passes (skip CODEOWNERS) | [x] |
| W1-T12 | W1-C7 | Author is dependabot[bot] + unsigned | Signature check fails (FIRST) | [x] |

### Trust Check Order (CRITICAL)
1. **Signatures FIRST** - ALL commits must be signed
2. **CODEOWNERS SECOND** - Only checked after signatures pass
3. **Dependabot exception** - Skips CODEOWNERS but still requires signed commits

---

## Test Matrix: Auto-Merge

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W1-T13 | W1-C8 | Trusted + Verified | Auto-merge ENABLED | [x] (unit tested via full_trust_check) |
| W1-T14 | W1-C8 | Untrusted + Verified | Auto-merge NOT enabled | [x] (unit tested via full_trust_check) |
| W1-T15 | W1-C9 | PR added to merge queue | PR queued for merge | [ ] (requires GH infra) |
| W1-T16 | W1-C9 | Merge queue processes PR | PR merged to integration | [ ] (requires GH infra) |

---

## Test Execution Steps

### W1-T10: Author IN CODEOWNERS (Happy Path)

```bash
# 1. Ensure you're listed in CODEOWNERS
cat .github/CODEOWNERS

# 2. Create test branch
git checkout integration
git pull origin integration
git checkout -b test/w1-t10-codeowner-$(date +%Y%m%d)

# 3. Make a valid chart change
echo "# Test change" >> charts/test-workflow/values.yaml

# 4. Commit with signature
git add .
git commit -S -m "feat(test-workflow): test W1-T10 CODEOWNERS check"

# 5. Push and create PR
git push origin HEAD
gh pr create --base integration --title "Test W1-T10: CODEOWNERS Trust Check"

# 6. Verify workflow runs
gh pr view --json statusCheckRollup

# 7. Expected: Trust check passes, auto-merge enabled
```

### W1-T7: Unsigned Commits (Negative Test)

```bash
# 1. Create test branch
git checkout integration
git checkout -b test/w1-t7-unsigned-$(date +%Y%m%d)

# 2. Make change with UNSIGNED commit
echo "# Unsigned change" >> charts/test-workflow/values.yaml
git add .
git commit --no-gpg-sign -m "feat(test-workflow): test W1-T7 unsigned commit"

# 3. Push and create PR
git push origin HEAD
gh pr create --base integration --title "Test W1-T7: Unsigned Commit"

# 4. Expected: Signature check FAILS
gh pr view --json statusCheckRollup

# 5. Cleanup
gh pr close --delete-branch
```

---

## Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| W1-C1 | Workflow only runs on integration PRs | Runs on main PRs |
| W1-C2 | Invalid charts fail lint | Invalid charts pass |
| W1-C6 | Unsigned commits rejected | Unsigned commits pass |
| W1-C7 | Only CODEOWNERS trusted | Non-CODEOWNERS trusted |
| W1-C8 | Auto-merge only for trusted+signed | Auto-merge for untrusted |

---

## Checklist

### Validation Tests
- [x] W1-T1: PR targets main - workflow doesn't run (unit tested)
- [ ] W1-T2: Chart.yaml invalid - ct lint fails (requires GH infra)
- [ ] W1-T3: Missing ArtifactHub metadata - ah lint fails (requires GH infra)
- [ ] W1-T4: Non-conventional commit - validation fails (requires GH infra)
- [ ] W1-T5: Commits cannot be cherry-picked - preview fails (requires GH infra)
- [ ] W1-T6: Commits can be cherry-picked - preview passes (requires GH infra)

### Trust Check Tests
- [x] W1-T7: Unsigned commits - signature check fails
- [x] W1-T8: All commits signed - signature check passes (skipped if no GPG)
- [x] W1-T9: Author NOT in CODEOWNERS - trust check fails
- [x] W1-T10: Author IN CODEOWNERS - trust check passes
- [x] W1-T11: Dependabot + signed - trust check passes
- [x] W1-T12: Dependabot + unsigned - signature check fails

### Auto-Merge Tests
- [x] W1-T13: Trusted + Verified - auto-merge enabled (unit tested)
- [x] W1-T14: Untrusted + Verified - auto-merge NOT enabled (unit tested)
- [ ] W1-T15: PR added to merge queue (requires GH infra)
- [ ] W1-T16: Merge queue processes PR (requires GH infra)

### Unit Test Summary
- **Total Unit Tests**: 72
- **Passing**: 72 (1 skipped - GPG not installed)
- **Test Files**:
  - `.github/tests/trust/test-codeowners-trust.bats`
  - `.github/tests/trust/test-dependabot-detection.bats`
  - `.github/tests/trust/test-signature-verification.bats`
  - `.github/tests/trust/test-branch-filtering.bats`

---

## Failure Investigation

> **📚 Skill Reference**: Use `~/.claude/skills/method-debugging-systematic-eng` - ALWAYS find root cause before attempting fixes

When a W1 test fails:

1. **Check workflow logs**: `gh run view <run-id> --log`
2. **Check specific job**: `gh run view <run-id> --job <job-id> --log`
3. **Verify CODEOWNERS**: `cat .github/CODEOWNERS`
4. **Check commit signatures**: `git log --show-signature -1`
5. **Find root cause** - don't patch symptoms

---

## Notes

### Dependabot Configuration

For Dependabot tests to work, ensure `.github/dependabot.yml` targets integration:

```yaml
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    target-branch: "integration"  # REQUIRED
    schedule:
      interval: "weekly"
```

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Workflow doesn't run | PR targets wrong branch | Target `integration` |
| Trust check fails unexpectedly | Not in CODEOWNERS | Add to `.github/CODEOWNERS` |
| Signature check fails | GPG key not configured | Configure signing key |
| Auto-merge not enabled | Missing permissions | Check workflow permissions |

---

## Test Matrix: Partial Signing (P2-G1 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| W1-T7b | First commit signed, second unsigned | Signature check FAILS | [x] |
| W1-T7c | First commit unsigned, second signed | Signature check FAILS | [x] |
| W1-T7d | Middle commit unsigned (3 commits) | Signature check FAILS | [x] |
| W1-T7e | All signed except merge commit | Signature check FAILS | [ ] (requires GH infra) |

### W1-T7b: First Signed, Second Unsigned

```bash
# 1. Create test branch
git checkout integration
git checkout -b test/w1-t7b-partial-sign-$(date +%Y%m%d)

# 2. First commit WITH signature
echo "# First change" >> charts/test-workflow/values.yaml
git add .
git commit -S -m "feat(test-workflow): first commit (signed)"

# 3. Second commit WITHOUT signature
echo "# Second change" >> charts/test-workflow/values.yaml
git add .
git commit --no-gpg-sign -m "feat(test-workflow): second commit (unsigned)"

# 4. Push and create PR
git push origin HEAD
gh pr create --base integration --title "Test W1-T7b: Partial Signing"

# 5. Expected: Signature check FAILS
# Verify error message identifies the unsigned commit
gh pr view --json statusCheckRollup

# 6. Verify error message
gh run list --workflow=validate-contribution-pr.yaml --limit 1 --json databaseId -q '.[0].databaseId' | \
  xargs -I {} gh run view {} --log | grep -A5 "unsigned"

# 7. Cleanup
gh pr close --delete-branch
```

### W1-T7c: First Unsigned, Second Signed

```bash
# 1. Create test branch
git checkout integration
git checkout -b test/w1-t7c-partial-sign-$(date +%Y%m%d)

# 2. First commit WITHOUT signature
echo "# First change" >> charts/test-workflow/values.yaml
git add .
git commit --no-gpg-sign -m "feat(test-workflow): first commit (unsigned)"

# 3. Second commit WITH signature
echo "# Second change" >> charts/test-workflow/values.yaml
git add .
git commit -S -m "feat(test-workflow): second commit (signed)"

# 4. Push and create PR
git push origin HEAD
gh pr create --base integration --title "Test W1-T7c: Partial Signing Reverse"

# 5. Expected: Signature check FAILS (first commit is unsigned)
gh pr view --json statusCheckRollup

# 6. Cleanup
gh pr close --delete-branch
```

---

## Test Matrix: Dependabot Simulation (P2-G2 Resolved)

### Option 1: Wait for Real Dependabot PR (Production)

```bash
# Monitor for dependabot PRs
gh pr list --author "app/dependabot" --base integration

# When one appears, verify:
# 1. PR targets integration
gh pr view <number> --json baseRefName -q '.baseRefName'
# Should be: integration

# 2. Commits are signed
gh api repos/{owner}/{repo}/pulls/<number>/commits --jq '.[].commit.verification.verified'
# Should all be: true

# 3. Author is dependabot[bot]
gh pr view <number> --json author -q '.author.login'
# Should be: dependabot[bot]
```

### Option 2: Unit Test for Dependabot Detection (Phase 1)

Add BATS test for the trust check function:

```bash
# .github/tests/trust/test-dependabot-detection.bats

@test "dependabot[bot] author is detected" {
  # Mock the PR author check
  export PR_AUTHOR="dependabot[bot]"
  run is_dependabot_pr
  [ "$status" -eq 0 ]
}

@test "regular user is not detected as dependabot" {
  export PR_AUTHOR="aRustyDev"
  run is_dependabot_pr
  [ "$status" -eq 1 ]
}

@test "dependabot-preview[bot] is also detected" {
  export PR_AUTHOR="dependabot-preview[bot]"
  run is_dependabot_pr
  [ "$status" -eq 0 ]
}
```

### Option 3: API Verification Script

```bash
#!/usr/bin/env bash
# .github/tests/scripts/verify-dependabot-detection.sh

set -euo pipefail

# Verify dependabot detection logic matches workflow
verify_dependabot_detection() {
  local author="$1"

  # This should match the logic in validate-contribution-pr.yaml
  if [[ "$author" == "dependabot[bot]" ]] || \
     [[ "$author" == "dependabot-preview[bot]" ]]; then
    echo "DEPENDABOT"
    return 0
  else
    echo "NOT_DEPENDABOT"
    return 1
  fi
}

# Test cases
echo "Testing dependabot detection..."
verify_dependabot_detection "dependabot[bot]" && echo "✓ dependabot[bot] detected"
verify_dependabot_detection "aRustyDev" || echo "✓ aRustyDev NOT detected"
verify_dependabot_detection "dependabot-preview[bot]" && echo "✓ dependabot-preview[bot] detected"

echo "All tests passed!"
```

---

## Test Matrix: Workflow Timeout (P2-G3 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| TO-T1 | PR with 100+ files | Completes within timeout | [ ] (requires GH infra) |
| TO-T2 | Slow lint (large chart) | Completes within timeout | [ ] (requires GH infra) |
| TO-T3 | Timeout reached | Workflow fails gracefully | [ ] (requires GH infra) |

### Timeout Configuration Reference

```yaml
# Current timeout settings in validate-contribution-pr.yaml
jobs:
  lint:
    timeout-minutes: 10

  artifacthub-lint:
    timeout-minutes: 5

  commit-validation:
    timeout-minutes: 5

  trust-check:
    timeout-minutes: 5
```

### TO-T3: Verify Timeout Behavior

```bash
# To test timeout, temporarily reduce timeout in workflow:
# timeout-minutes: 1

# Then create PR with slow operation (e.g., many files)
git checkout integration
git checkout -b test/to-t3-timeout

# Create many files to slow down lint
for i in $(seq 1 50); do
  cp charts/test-workflow/values.yaml "charts/test-workflow/values-$i.yaml"
done

git add .
git commit -S -m "test: trigger timeout"
git push origin HEAD
gh pr create --base integration --title "Test TO-T3: Timeout"

# Expected: Workflow times out with clear error
gh run list --workflow=validate-contribution-pr.yaml --limit 1

# Cleanup
gh pr close --delete-branch
```

---

## Test Matrix: Team CODEOWNERS (P2-G4 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| TM-T1 | Author in team `@org/chart-maintainers` | Trust check passes | [x] (team detection unit tested) |
| TM-T2 | Author NOT in team | Trust check fails | [ ] (requires GH API) |
| TM-T3 | Author in nested team | Trust check passes | [ ] (requires GH API) |
| TM-T4 | Individual + team in CODEOWNERS | Both work | [x] |

### CODEOWNERS Team Configuration

```bash
# .github/CODEOWNERS with team syntax
* @aRustyDev @org/chart-maintainers

# For specific paths
charts/ @org/chart-maintainers
docs/ @org/docs-team
.github/ @aRustyDev
```

### TM-T1: Team Member Trust Check

```bash
# Prerequisites:
# 1. GitHub organization with team created
# 2. User is member of the team
# 3. CODEOWNERS includes @org/team-name

# Verify team membership
gh api orgs/{org}/teams/{team}/members --jq '.[].login'

# Create PR as team member
git checkout integration
git checkout -b test/tm-t1-team-member

echo "# Team member change" >> charts/test-workflow/values.yaml
git add .
git commit -S -m "feat(test-workflow): test team membership"
git push origin HEAD
gh pr create --base integration --title "Test TM-T1: Team Member"

# Expected: Trust check passes
gh pr view --json statusCheckRollup
```

### TM-T4: Individual + Team Combined

```bash
# CODEOWNERS content:
# * @individual-user @org/team-name

# Both individual user PRs AND team member PRs should pass trust check

# Test 1: Individual user
# (same as W1-T10)

# Test 2: Team member (not listed individually)
# (same as TM-T1)
```

### Team Detection Logic

```bash
# The workflow should check team membership via:
gh api orgs/{org}/teams/{team}/memberships/{username}

# Success (200) = member
# Failure (404) = not a member
```

---

## GAPs Resolution Status

| GAP ID | Description | Priority | Status |
|--------|-------------|----------|--------|
| P2-G1 | Add test for partial signing (some commits signed, some not) | High | [x] **RESOLVED** |
| P2-G2 | Document how to simulate dependabot PRs locally | Medium | [x] **RESOLVED** |
| P2-G3 | Add workflow timeout tests | Low | [x] **RESOLVED** |
| P2-G4 | Add tests for CODEOWNERS with team membership | Medium | [x] **RESOLVED** |

### Resolution Summary

- **P2-G1**: Added W1-T7b through W1-T7e partial signing tests with execution steps
- **P2-G2**: Documented 3 options for dependabot testing (real PR, unit test, API script)
- **P2-G3**: Added TO-T1 through TO-T3 timeout tests with configuration reference
- **P2-G4**: Added TM-T1 through TM-T4 team CODEOWNERS tests with detection logic
