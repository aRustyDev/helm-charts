# Research Plan: Open Questions Resolution

## Overview

This document tracks research needed to resolve open questions identified during the planning phase.

---

## Questions Status

| Question | Status | Resolution |
|----------|--------|------------|
| Security scanning tool | **Out of Scope** | Deferred to future iteration |
| Changelog generation | **Decided** | Per-chart generation |
| Attestation subjects | **Decided** | Subject = check/action name |
| Token permissions | **Research Needed** | See Section 1 |
| GitHub App necessity | **Research Needed** | See Section 2 |

---

## 1. Token Permissions Research

### Question
Can `GITHUB_TOKEN` push to protected branches, or do we need a GitHub App token?

### Research Tasks
- [x] Review GitHub Actions documentation on GITHUB_TOKEN permissions
- [x] Test GITHUB_TOKEN push to protected branch with bypass ruleset
- [x] Investigate ruleset bypass options for GitHub Actions

### Findings

**GITHUB_TOKEN CANNOT bypass branch protection rules**

Key discoveries:
1. **Classic branch protection "Allow specified actors to bypass required pull requests"** only allows pushing without a PR, but does NOT bypass required status checks
2. **Rulesets are the solution** - GitHub rulesets support a "Bypass list" that provides complete bypass including status checks
3. **GitHub App is required** for reliable protected branch pushes

**Error without proper bypass**:
```
remote: error: GH006: Protected branch update failed for refs/heads/main.
remote: - Changes must be made through a pull request.
remote: - 3 of 3 required status checks are expected.
```

**Reference**: [Letting GitHub Actions Push to Protected Branches](https://medium.com/ninjaneers/letting-github-actions-push-to-protected-branches-a-how-to-57096876850d) (Dec 2025)

---

## 2. GitHub App Necessity

### Question
Do we need a dedicated GitHub App for elevated permissions?

### Workflows Requiring Elevated Permissions
| Workflow | Action | Current Token Sufficient? |
|----------|--------|---------------------------|
| W5 | Push version bump to PR branch | ❌ No - needs App |
| W6 | Create annotated tags | ❌ No - needs App |
| W6 | Push tags to protected refs | ❌ No - needs App |

### Research Tasks
- [x] Review existing 1Password GitHub App integration
- [x] Test tag creation with GITHUB_TOKEN + ruleset bypass
- [x] Document GitHub App permissions if needed

### Findings

**YES - A GitHub App is required**

#### Required Setup
1. **Create GitHub App** with permissions:
   - `Contents: Read and write` - for pushing commits and tags

2. **Install App on repository**

3. **Store credentials as secrets**:
   - `RELEASE_BOT_APP_ID` (variable)
   - `RELEASE_BOT_PRIVATE_KEY` (secret)

4. **Configure ruleset bypass**:
   - Add App to ruleset's "Bypass list"
   - This allows complete bypass including status checks

5. **Use in workflow**:
```yaml
- name: Create GitHub App token
  id: app-token
  uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ vars.RELEASE_BOT_APP_ID }}
    private-key: ${{ secrets.RELEASE_BOT_PRIVATE_KEY }}

- uses: actions/checkout@v4
  with:
    fetch-depth: 0
    token: ${{ steps.app-token.outputs.token }}

- name: Push changes
  run: |
    git config user.name "release-bot[bot]"
    git config user.email "release-bot[bot]@users.noreply.github.com"
    git push origin main --tags
```

6. **Add infinite loop guard**:
```yaml
jobs:
  build:
    if: github.actor != 'release-bot[bot]'
```

#### Existing Integration
The repository already has 1Password integration for GitHub App tokens. Consider:
- **Option A**: Create new dedicated "release-bot" App (cleaner separation)
- **Option B**: Reuse existing 1Password-managed App (simpler setup)

**Recommendation**: Create dedicated App named `helm-charts-release-bot` for:
- Clear audit trail
- Minimal permissions
- Easy revocation if compromised

---

## 3. Changelog Generation (DECIDED: Per-Chart)

### Decision
Generate changelog **per-chart**, not combined.

### Research Tasks
- [x] Decision made: Per-chart
- [ ] Research changelog generation tools for Helm charts
- [ ] Evaluate: git-cliff, conventional-changelog, release-please changelog
- [ ] Determine integration approach with W1

### Options to Evaluate
1. **git-cliff** - Rust-based, highly configurable
2. **conventional-changelog** - Node.js, conventional commits
3. **release-please** - Built-in changelog from commits
4. **Custom script** - Parse conventional commits manually

### Evaluation Criteria
- Supports Keep-a-Changelog format
- Can scope to specific chart directory
- Integrates with conventional commits
- Works in GitHub Actions

### Findings
*(See Section 3.1 for research results)*

---

## 4. Attestation Subjects (DECIDED)

### Decision
The **subject** for attestations should be the **name of the check/action**.

### Rationale
- Consistent naming across all workflows
- Easy to trace in attestation lineage
- Aligns with GitHub attestation patterns

### Subject Format
```
<workflow>-<check-name>[-<variant>]
```

### Examples
| Workflow | Check | Subject |
|----------|-------|---------|
| W1 | Lint test (K8s 1.32) | `w1-lint-test-v1.32.11` |
| W1 | Lint test (K8s 1.33) | `w1-lint-test-v1.33.7` |
| W1 | ArtifactHub lint | `w1-artifacthub-lint` |
| W1 | Commit validation | `w1-commit-validation` |
| W5 | Chain verification | `w5-attestation-verify` |
| W5 | SemVer bump | `w5-semver-bump` |
| W7 | Build attestation | `w7-build-<chart>` |

---

## 3.1 Changelog Generation Research

### Tool Comparison

#### git-cliff
- **Language**: Rust
- **Installation**: Binary download or cargo install
- **Config**: `cliff.toml`
- **Pros**:
  - Highly configurable templates
  - Fast execution
  - Supports Keep-a-Changelog
  - Can filter by path (charts/<name>)
- **Cons**:
  - Requires binary installation
  - Learning curve for templates

#### conventional-changelog
- **Language**: Node.js
- **Installation**: npm install
- **Config**: Various preset options
- **Pros**:
  - Well-established
  - Multiple output formats
- **Cons**:
  - Node.js dependency
  - Less flexible filtering

#### release-please changelog
- **Language**: Node.js (integrated)
- **Config**: release-please-config.json
- **Pros**:
  - Already integrated for versioning
  - Automatic changelog generation
- **Cons**:
  - Tied to release-please workflow
  - Less control over format

#### Custom Script
- **Pros**: Full control, no dependencies
- **Cons**: Maintenance burden, reinventing wheel

### Recommendation

**Primary**: `git-cliff` with per-chart configuration

**Rationale**:
1. Path-based filtering (`--include-path charts/<name>/**/*`) - **CONFIRMED**
2. Keep-a-Changelog format support
3. Fast, single binary (Rust)
4. Active development (v2.11.0 as of Jan 2025)
5. Built-in monorepo support with directory scoping

### Confirmed Features (from git-cliff docs)

**Monorepo Support** (https://git-cliff.org/docs/usage/monorepos/):
```bash
# Filter commits by path - exactly what we need
git cliff --include-path "charts/cloudflared/**/*" --exclude-path ".github/*"
```

**Configuration Approach**:
```toml
# cliff.toml
[git]
conventional_commits = true
filter_commits = true
commit_parsers = [
    { message = "^feat", group = "Features" },
    { message = "^fix", group = "Bug Fixes" },
    { message = "^docs", group = "Documentation" },
    { message = "^perf", group = "Performance" },
    { message = "^refactor", group = "Refactoring" },
]

[changelog]
header = "# Changelog\n\n"
body = """
{% for group, commits in commits | group_by(attribute="group") %}
## {{ group }}
{% for commit in commits %}
- {{ commit.message }}{% endfor %}
{% endfor %}
"""
```

**Per-Chart Invocation**:
```bash
# Generate changelog for specific chart
git cliff --include-path "charts/$CHART/**/*" --unreleased

# Or from chart directory
cd charts/$CHART && git cliff
```

### Alternative Evaluated: conventional-changelog-conventionalcommits-helm
- **URL**: https://github.com/scc-digitalhub/conventional-changelog-conventionalcommits-helm
- **Status**: Not recommended
- **Reason**: Low adoption (0 stars), requires Node.js, last updated 2+ years ago

---

## Next Steps

1. [x] Test git-cliff with current repo - **PASSED**
2. [x] Create `cliff.toml` configuration - Created at `.github/cliff.toml`
3. [x] Test per-chart filtering - **PASSED**
4. [x] Document integration in W1 phase plan - Updated
5. [x] Research GitHub App requirements (Section 2) - **Completed**

## Test Results

### git-cliff Installation
```bash
brew install git-cliff  # v2.11.0
```

### Per-Chart Changelog Test
```bash
git-cliff --config .github/cliff.toml --include-path "charts/cloudflared/**/*" --unreleased
```

**Output**:
```markdown
# Changelog

All notable changes to this chart will be documented in this file.

## Features

- *(cloudflared)* Add External Secrets Operator integration (#37) ([ad17042](https://github.com/aRustyDev/helm-charts/commit/ad17042...))
- *(cloudflared)* Add Prometheus metrics support (#41) ([44432d0](https://github.com/aRustyDev/helm-charts/commit/44432d0...))
- *(cloudflared)* Add Linkerd service mesh integration (#43) ([47ba9dd](https://github.com/aRustyDev/helm-charts/commit/47ba9dd...))
```

### Configuration Created
- File: `.github/cliff.toml`
- Features:
  - Conventional commit parsing
  - Keep-a-Changelog format
  - GitHub commit links
  - Scope filtering
