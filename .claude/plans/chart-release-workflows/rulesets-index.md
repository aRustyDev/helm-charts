# Rulesets Index

## Overview

This document defines all GitHub repository rulesets required for the chart release workflow. It includes both branch rulesets and tag rulesets.

---

## Ruleset Summary

| Ruleset Name | Type | Target | Purpose |
|--------------|------|--------|---------|
| `main-protection` | Branch | `main` | Protect main branch |
| `integration-protection` | Branch | `integration` | Protect integration branch |
| `integration-chart-protection` | Branch | `integration/*` | Protect per-chart branches |
| `release-protection` | Branch | `release` | Protect release branch |
| `release-tag-protection` | Tag | `*-v*` | Protect release tags |

---

## Branch Rulesets

### 1. `main-protection`

**Target**: `main` branch

| Rule | Setting | Bypass |
|------|---------|--------|
| Restrict deletions | ✅ Enabled | None |
| Restrict updates (push) | ✅ Enabled | Admin |
| Require pull request | ✅ Enabled | None |
| Require approvals | ✅ 1 approval | None |
| Require status checks | ✅ Enabled | None |
| Block force pushes | ✅ Enabled | None |

**Required Status Checks**:
- `workflow-5-verify-attestations`
- `workflow-5-semver-bump`

**JSON Configuration**:
```json
{
  "name": "main-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true,
        "require_code_owner_review": false,
        "require_last_push_approval": false
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "workflow-5-verify-attestations" },
          { "context": "workflow-5-semver-bump" }
        ]
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 1,
      "actor_type": "RepositoryRole",
      "bypass_mode": "pull_request"
    }
  ]
}
```

---

### 2. `integration-protection`

**Target**: `integration` branch

| Rule | Setting | Bypass |
|------|---------|--------|
| Restrict deletions | ✅ Enabled | None |
| Restrict updates (push) | ✅ Enabled | Admin |
| Require pull request | ✅ Enabled | None |
| Require approvals | ✅ 1 approval | None |
| Require status checks | ✅ Enabled | Admin |
| Block force pushes | ✅ Enabled | None |

**Required Status Checks**:
- `lint-test-v1.32.11`
- `lint-test-v1.33.7`
- `lint-test-v1.34.3`
- `artifacthub-lint`
- `commit-validation`

**JSON Configuration**:
```json
{
  "name": "integration-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/integration"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 1,
        "dismiss_stale_reviews_on_push": true
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "lint-test-v1.32.11" },
          { "context": "lint-test-v1.33.7" },
          { "context": "lint-test-v1.34.3" },
          { "context": "artifacthub-lint" },
          { "context": "commit-validation" }
        ]
      }
    }
  ],
  "bypass_actors": [
    {
      "actor_id": 1,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ]
}
```

---

### 3. `integration-chart-protection`

**Target**: `integration/*` branches

| Rule | Setting | Bypass |
|------|---------|--------|
| Restrict deletions | ❌ Disabled | N/A |
| Restrict updates (push) | ✅ Enabled | None |
| Require pull request | ❌ Disabled | N/A |
| Block force pushes | ✅ Enabled | None |

**Note**: Merge source restriction (`only integration can merge`) is enforced via Workflow 3, not rulesets.

**JSON Configuration**:
```json
{
  "name": "integration-chart-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/integration/*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "update" },
    { "type": "non_fast_forward" }
  ],
  "bypass_actors": []
}
```

---

### 4. `release-protection`

**Target**: `release` branch

| Rule | Setting | Bypass |
|------|---------|--------|
| Restrict deletions | ✅ Enabled | None |
| Restrict updates (push) | ✅ Enabled | None |
| Require pull request | ✅ Enabled | None |
| Require status checks | ✅ Enabled | None |
| Block force pushes | ✅ Enabled | None |

**Required Status Checks**:
- `workflow-7-verify-attestations`
- `workflow-7-build-charts`

**Note**: Merge source restriction (`only main can merge`) is enforced via Workflow 7, not rulesets.

**JSON Configuration**:
```json
{
  "name": "release-protection",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/release"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "update" },
    { "type": "non_fast_forward" },
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0
      }
    },
    {
      "type": "required_status_checks",
      "parameters": {
        "strict_required_status_checks_policy": true,
        "required_status_checks": [
          { "context": "workflow-7-verify-attestations" },
          { "context": "workflow-7-build-charts" }
        ]
      }
    }
  ],
  "bypass_actors": []
}
```

---

## Tag Rulesets

### 5. `release-tag-protection`

**Target**: `*-v*` tags (e.g., `cloudflared-v0.5.0`)

| Rule | Setting | Bypass |
|------|---------|--------|
| Restrict deletions | ✅ Enabled | None |
| Restrict updates | ✅ Enabled | None |
| Restrict creations | ✅ Enabled | Workflow (GitHub Actions) |

**JSON Configuration**:
```json
{
  "name": "release-tag-protection",
  "target": "tag",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/tags/*-v*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "deletion" },
    { "type": "update" },
    { "type": "creation" }
  ],
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "Integration",
      "bypass_mode": "always"
    }
  ]
}
```

**Note**: The bypass actor for tag creation should be the GitHub Actions app or a specific GitHub App used by workflows.

---

## Workflow-Enforced Rules

These rules cannot be enforced via GitHub rulesets and require workflow implementation:

| Rule | Enforced By | Logic |
|------|-------------|-------|
| Only `integration` → `integration/*` | Workflow 3 | Check `github.head_ref == 'integration'` |
| Only `main` → `release` | Workflow 7 | Check `github.head_ref == 'main'` |
| Tags only from `main` | Workflow 6 | Create tags only in workflow running on `main` |

---

## Existing Rulesets to Modify

Based on current repository state:

| Current Ruleset | Action | Notes |
|-----------------|--------|-------|
| `charts: prevent deletion` | Rename to `release-protection` | Target changes from `charts` to `release` |
| `charts: require PRs` | Delete (disabled) | N/A |
| `main: prevent deletion` | Update to `main-protection` | Add required checks |
| `main: require PRs` | Merge into `main-protection` | Combine rules |
| `main: require status checks` | Merge into `main-protection` | Combine rules |

---

## Ruleset Creation Order

1. **Create new rulesets** (before migration):
   - `integration-protection`
   - `integration-chart-protection`
   - `release-tag-protection`

2. **Migrate existing** (during branch rename):
   - Update `charts: prevent deletion` → `release-protection`

3. **Update main** (after workflow deployment):
   - Consolidate main rulesets into `main-protection`

---

## Ruleset Permissions Required

To create/modify rulesets, you need:
- Repository admin access, OR
- Custom role with "Edit repository rules" permission

---

## Verification Commands

```bash
# List all rulesets
gh api repos/{owner}/{repo}/rulesets

# Get specific ruleset
gh api repos/{owner}/{repo}/rulesets/{ruleset_id}

# Create ruleset (from JSON file)
gh api repos/{owner}/{repo}/rulesets -X POST --input ruleset.json

# Update ruleset
gh api repos/{owner}/{repo}/rulesets/{ruleset_id} -X PUT --input ruleset.json

# Delete ruleset
gh api repos/{owner}/{repo}/rulesets/{ruleset_id} -X DELETE
```

---

## Summary Table

| Branch/Tag | Delete | Push | Force Push | PR Required | Checks | Merge Source |
|------------|:------:|:----:|:----------:|:-----------:|:------:|:------------:|
| `main` | ❌ | ❌ (admin✓) | ❌ | ✅ | W5 | Any |
| `integration` | ❌ | ❌ (admin✓) | ❌ | ✅ | W1 | Any |
| `integration/*` | ✅ | ❌ | ❌ | ❌ | - | `integration` (W3) |
| `release` | ❌ | ❌ | ❌ | ✅ | W7 | `main` (W7) |
| `*-v*` tags | ❌ | ❌ | N/A | N/A | N/A | `main` (W6) |

**Legend**: ❌ = Blocked, ✅ = Required/Allowed, (admin✓) = Admin bypass, (Wx) = Workflow enforced
