# Atomic Components Index

## Overview

This document indexes all atomic components used across the 8 workflows, highlighting which components are shared to enable efficient development planning.

### Implementation Plan
See **[components/plan.md](components/plan.md)** for the detailed phase plan covering:
- Implementation language decision (Bash shell functions)
- GitHub App decision (ruleset bypass preferred)
- Development phases for each component
- Testing strategy

## Component Categories

1. **GitHub Actions** - Third-party actions
2. **Custom Actions** - Actions we need to build
3. **Shell Functions** - Reusable shell scripts
4. **Configurations** - Config files and formats
5. **Rulesets** - GitHub repository rulesets

---

## Shared Components Matrix

### GitHub Actions

| Component | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | Priority |
|-----------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|----------|
| `actions/checkout@v4` | ✓ | ✓ | - | - | ✓ | ✓ | ✓ | ✓ | Exists |
| `actions/attest-build-provenance@v3` | ✓ | - | - | - | ✓ | - | ✓ | - | Exists |
| `actions/upload-artifact@v4` | - | - | - | - | - | - | ✓ | - | Exists |
| `azure/setup-helm@v4` | ✓ | - | - | - | - | - | ✓ | ✓ | Exists |
| `sigstore/cosign-installer@v3` | - | - | - | - | - | - | ✓ | ✓ | Exists |
| `docker/login-action@v3` | - | - | - | - | - | - | - | ✓ | Exists |
| `helm/chart-testing-action@v2` | ✓ | - | - | - | - | - | - | - | Exists |
| `googleapis/release-please-action@v4` | - | - | - | - | ✓ | - | - | - | Exists |
| `wagoid/commitlint-github-action@v5` | ✓ | - | - | - | - | - | - | - | Exists |
| `peter-evans/create-pull-request@v6` | - | ✓ | - | ✓ | - | ✓ | - | - | Consider |
| `pascalgn/automerge-action@v0.16.3` | - | - | ✓ | - | - | - | - | - | Consider |

### CLI Tools

| Tool | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | Status |
|------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|--------|
| `gh` CLI | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | Pre-installed |
| `jq` | ✓ | ✓ | - | ✓ | ✓ | ✓ | ✓ | ✓ | Pre-installed |
| `git-cliff` | ✓ | - | - | - | - | - | - | - | Install |
| `ah` (ArtifactHub) | ✓ | - | - | - | - | - | - | - | Install |
| `yq` | - | - | - | - | ✓ | ✓ | ✓ | ✓ | Consider |
| `helm` | ✓ | - | - | - | - | - | ✓ | ✓ | Via action |
| `cosign` | - | - | - | - | - | - | ✓ | ✓ | Via action |

### Custom Components (TO BUILD)

| Component | W1 | W2 | W3 | W4 | W5 | W6 | W7 | W8 | Priority |
|-----------|:--:|:--:|:--:|:--:|:--:|:--:|:--:|:--:|----------|
| **`update_attestation_map`** | ✓ | - | - | - | ✓ | - | ✓ | - | 🔴 High |
| **`extract_attestation_map`** | - | ✓ | - | ✓ | ✓ | ✓ | ✓ | ✓ | 🔴 High |
| **`verify_attestation_chain`** | - | - | - | - | ✓ | - | ✓ | - | 🔴 High |
| **`detect_changed_charts`** | - | ✓ | - | - | - | ✓ | ✓ | ✓ | 🟡 Medium |
| **`validate_source_branch`** | - | - | ✓ | - | - | - | ✓ | - | 🟡 Medium |

**Legend**: ✓ = Used, - = Not used

---

## Component Details

### 1. GitHub Actions (Third-Party)

#### `actions/checkout@v4`
- **Used by**: W1, W2, W5, W6, W7, W8
- **Purpose**: Checkout repository code
- **Status**: ✅ Exists
- **Config variations**:
  - `fetch-depth: 0` for full history (W2, W5, W6, W7, W8)
  - `fetch-depth: 2` for diff (W2)

#### `actions/attest-build-provenance@v3`
- **Used by**: W1, W5, W7
- **Purpose**: Generate SLSA attestations
- **Status**: ✅ Exists
- **Permissions required**: `id-token: write`, `attestations: write`

#### `azure/setup-helm@v4`
- **Used by**: W1, W7, W8
- **Purpose**: Install Helm CLI
- **Status**: ✅ Exists
- **Config**: `version: v3.14.0`

#### `sigstore/cosign-installer@v3`
- **Used by**: W7, W8
- **Purpose**: Install Cosign for signing
- **Status**: ✅ Exists

#### `docker/login-action@v3`
- **Used by**: W8
- **Purpose**: Login to GHCR
- **Status**: ✅ Exists

#### `helm/chart-testing-action@v2`
- **Used by**: W1
- **Purpose**: Set up chart-testing CLI
- **Status**: ✅ Exists

#### `googleapis/release-please-action@v4`
- **Used by**: W5
- **Purpose**: Determine version bump
- **Status**: ✅ Exists (with known issues)
- **Config**: `skip-github-release: true`, `dry-run: true`

#### `wagoid/commitlint-github-action@v5`
- **Used by**: W1
- **Purpose**: Validate conventional commit messages
- **Status**: ✅ Exists
- **Config**: Requires `commitlint.config.js` in repo root

#### `actions/upload-artifact@v4`
- **Used by**: W7
- **Purpose**: Upload chart packages as workflow artifacts
- **Status**: ✅ Exists

#### `peter-evans/create-pull-request@v6`
- **Used by**: W2, W4, W6
- **Purpose**: Create PRs programmatically with custom content
- **Status**: ✅ Exists (alternative to `gh pr create`)
- **Note**: Consider for better error handling and idempotency

#### `pascalgn/automerge-action@v0.16.3`
- **Used by**: W3
- **Purpose**: Auto-merge PRs when conditions are met
- **Status**: ✅ Exists (alternative to `gh pr merge --auto`)
- **Note**: Provides more control over merge conditions

---

### 1.5. CLI Tools Required

#### `git-cliff`
- **Used by**: W1
- **Purpose**: Generate changelog from conventional commits
- **Status**: 🔧 Install required
- **Installation**: `cargo install git-cliff` or download binary
- **Alternative**: `conventional-changelog-cli` (npm)

#### `ah` (ArtifactHub CLI)
- **Used by**: W1
- **Purpose**: Lint Helm charts for ArtifactHub metadata
- **Status**: 🔧 Install required
- **Installation**: Download from ArtifactHub releases
- **URL**: https://github.com/artifacthub/hub

#### `jq`
- **Used by**: W1, W2, W4, W5, W6, W7, W8
- **Purpose**: Parse JSON (attestation maps, PR data)
- **Status**: ✅ Pre-installed on GitHub runners

#### `yq`
- **Used by**: W5, W6, W7, W8
- **Purpose**: Parse/modify YAML (Chart.yaml)
- **Status**: 🔧 Consider adding
- **Alternative**: `sed` with careful regex (current approach)

---

### 1.6. GitHub App (REQUIRED)

#### `helm-charts-release-bot` GitHub App
- **Purpose**: Push to protected branches, create tags, bypass ruleset protections
- **Used by**: W5 (push version bump), W6 (create/push tags)
- **Status**: 🔴 **REQUIRED** - See [ADR-010](adr/ADR-010-github-app-for-protected-operations.md)
- **Implementation Plan**: [infrastructure/github-app/plan.md](infrastructure/github-app/plan.md)

#### Research Findings (Confirmed)
- ❌ `GITHUB_TOKEN` **cannot** bypass protected branch rules (even with ruleset settings)
- ❌ Classic branch protection "Allow specified actors to bypass" does NOT bypass status checks
- ✅ **GitHub rulesets with Bypass list** + **GitHub App** = complete bypass

#### Required Setup
| Step | Description |
|------|-------------|
| 1 | Create GitHub App with `Contents: Read and write` |
| 2 | Install App on repository |
| 3 | Store `RELEASE_BOT_APP_ID` (variable) and `RELEASE_BOT_PRIVATE_KEY` (secret) |
| 4 | Add App to ruleset bypass lists |
| 5 | Use `actions/create-github-app-token@v2` in workflows |
| 6 | Add `if: github.actor != 'helm-charts-release-bot[bot]'` guard |

#### Action Required
```yaml
- uses: actions/create-github-app-token@v2
  with:
    app-id: ${{ vars.RELEASE_BOT_APP_ID }}
    private-key: ${{ secrets.RELEASE_BOT_PRIVATE_KEY }}
```

---

### 2. Custom Actions/Components (TO BUILD)

#### `update_attestation_map`
- **Used by**: W1, W5, W7
- **Priority**: 🔴 High (blocking)
- **Purpose**: Update PR description with attestation ID
- **Type**: Composite action or shell function
- **Input**:
  - `check_name`: Name of the check
  - `attestation_id`: ID from attestation action
  - `pr_number`: PR to update
- **Output**: Updated PR description
- **Implementation**:
  ```bash
  function update_attestation_map() {
    local check_name="$1"
    local attestation_id="$2"
    local pr_number="${3:-$PR_NUMBER}"

    # Get current body
    local body=$(gh pr view "$pr_number" --json body -q '.body')

    # Extract existing map or create new
    local existing=$(echo "$body" | grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | tr -d '\0')
    if [ -z "$existing" ]; then
      existing='{}'
    fi

    # Update map
    local updated=$(echo "$existing" | jq --arg k "$check_name" --arg v "$attestation_id" '. + {($k): $v}')

    # Replace in body (or append if not exists)
    if echo "$body" | grep -q "ATTESTATION_MAP"; then
      new_body=$(echo "$body" | sed "s|<!-- ATTESTATION_MAP.*-->|<!-- ATTESTATION_MAP\n$updated\n-->|")
    else
      new_body="$body

<!-- ATTESTATION_MAP
$updated
-->"
    fi

    # Update PR
    gh pr edit "$pr_number" --body "$new_body"
  }
  ```

#### `extract_attestation_map`
- **Used by**: W2, W4, W5, W6, W7, W8
- **Priority**: 🔴 High (blocking)
- **Purpose**: Extract attestation map from PR description
- **Type**: Shell function
- **Input**: `pr_number` or `pr_body`
- **Output**: JSON object of attestation IDs
- **Implementation**:
  ```bash
  function extract_attestation_map() {
    local pr_number="$1"
    local body

    if [ -n "$pr_number" ]; then
      body=$(gh pr view "$pr_number" --json body -q '.body')
    else
      body=$(cat -)
    fi

    echo "$body" | grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | tr -d '\0'
  }
  ```

#### `verify_attestation_chain`
- **Used by**: W5, W7
- **Priority**: 🔴 High (blocking)
- **Purpose**: Verify all attestations in map are valid
- **Type**: Shell function or composite action
- **Input**: Attestation map (JSON)
- **Output**: Success/failure with details
- **Implementation**:
  ```bash
  function verify_attestation_chain() {
    local attestation_map="$1"
    local failed=0

    for key in $(echo "$attestation_map" | jq -r 'keys[]'); do
      id=$(echo "$attestation_map" | jq -r --arg k "$key" '.[$k]')
      echo "Verifying $key: $id"

      if ! gh attestation verify --repo "$REPO" --attestation-id "$id" 2>/dev/null; then
        echo "::error::Failed to verify: $key ($id)"
        failed=$((failed + 1))
      fi
    done

    return $failed
  }
  ```

#### `detect_changed_charts`
- **Used by**: W2, W6, W7, W8
- **Priority**: 🟡 Medium
- **Purpose**: Detect which charts changed in a commit/merge
- **Type**: Shell function
- **Input**: Commit range (optional, defaults to HEAD~1..HEAD)
- **Output**: Space-separated list of chart names
- **Implementation**:
  ```bash
  function detect_changed_charts() {
    local range="${1:-HEAD~1..HEAD}"

    git diff --name-only "$range" | \
      grep '^charts/' | \
      cut -d'/' -f2 | \
      sort -u | \
      tr '\n' ' '
  }
  ```

#### `validate_source_branch`
- **Used by**: W3, W7
- **Priority**: 🟡 Medium
- **Purpose**: Validate PR source branch is allowed
- **Type**: Shell function or workflow step
- **Input**: Source branch, allowed pattern
- **Output**: Exit 0/1
- **Implementation**:
  ```bash
  function validate_source_branch() {
    local source="$1"
    local allowed="$2"

    if [[ "$source" != "$allowed" ]]; then
      echo "::error::Invalid source branch: $source (expected: $allowed)"
      return 1
    fi
    return 0
  }
  ```

---

### 3. Configurations

#### Attestation Map Format
- **Used by**: All workflows (storage/reading)
- **Priority**: 🔴 High (design decision)
- **Format**:
  ```markdown
  <!-- ATTESTATION_MAP
  {
    "lint-test-v1.32.11": "123456",
    "lint-test-v1.33.7": "234567"
  }
  -->
  ```

#### Tag Annotation Format
- **Used by**: W6, W7, W8
- **Priority**: 🟡 Medium
- **Format**:
  ```
  Release: <chart> v<version>

  Attestation Lineage:
  - <check>: <attestation-id>

  Changelog:
  <content>

  Source PR: #<number>
  Commit: <sha>
  ```

#### Release Attestation Manifest
- **Used by**: W5, W7
- **Priority**: 🟡 Medium
- **Format**: JSON file for overall attestation

---

### 4. Workflow Triggers

| Workflow | Trigger Type | Target |
|----------|--------------|--------|
| W1 | `pull_request` | `integration` |
| W2 | `push` | `integration` |
| W3 | `pull_request` | `integration/*` |
| W4 | `push` | `integration/*` |
| W5 | `pull_request` | `main` |
| W6 | `push` | `main` |
| W7 | `pull_request` | `release` |
| W8 | `push` | `release` |

---

## Development Priority Order

### Phase 0: Infrastructure (Before Workflows)
0a. **GitHub App Setup** - Required for W5, W6 (protected operations)
    - See [infrastructure/github-app/plan.md](infrastructure/github-app/plan.md)
    - See [ADR-010](adr/ADR-010-github-app-for-protected-operations.md)
0b. **Branch Setup** - Create `integration` branch, rename `charts` → `release`
    - See [migration-plan.md](migration-plan.md)
0c. **Ruleset Configuration** - Create rulesets with App bypass
    - See [rulesets-index.md](rulesets-index.md)

### Phase 1: Foundation (Required First)
1. `update_attestation_map` - Core to all attestation storage
2. `extract_attestation_map` - Core to all attestation reading
3. Attestation Map Format - Design decision, documented

### Phase 2: Verification
4. `verify_attestation_chain` - Core to attestation lineage
5. Tag Annotation Format - Design decision, documented

### Phase 3: Utilities
6. `detect_changed_charts` - Used by multiple workflows
7. `validate_source_branch` - Used by W3, W7

### Phase 4: Workflow Implementation (W1-W4)
8. W1: Validate Initial Contribution
9. W2: Filter Charts
10. W3: Enforce Atomic PRs
11. W4: Format Atomic PRs

### Phase 5: Workflow Implementation (W5-W8) - Requires GitHub App
12. W5: Validate & SemVer Bump ← **Needs GitHub App**
13. W6: Atomic Tagging ← **Needs GitHub App**
14. W7: Atomic Releases
15. W8: Publishing

---

## Component Dependency Graph

```
                    ┌─────────────────────────┐
                    │   Attestation Format    │
                    │   (Design Decision)     │
                    └───────────┬─────────────┘
                                │
            ┌───────────────────┼───────────────────┐
            ▼                   ▼                   ▼
┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐
│ update_attestation│  │extract_attestation│  │ verify_attestation│
│      _map         │  │      _map         │  │      _chain       │
└─────────┬─────────┘  └─────────┬─────────┘  └─────────┬─────────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    ▼                         ▼
            ┌───────────────┐         ┌───────────────┐
            │ Workflows 1-8 │         │Tag Annotation │
            │               │         │    Format     │
            └───────────────┘         └───────────────┘
```

---

## Shared Shell Library Proposal

To maximize reuse, create a shared shell library that can be sourced by all workflows:

```bash
# .github/scripts/attestation-lib.sh

# Attestation map operations
update_attestation_map() { ... }
extract_attestation_map() { ... }
verify_attestation_chain() { ... }

# Chart detection
detect_changed_charts() { ... }

# Validation
validate_source_branch() { ... }

# PR operations
get_source_pr() { ... }
get_pr_attestation_map() { ... }
```

Usage in workflows:
```yaml
- name: Setup attestation library
  run: source .github/scripts/attestation-lib.sh

- name: Update attestation map
  run: update_attestation_map "lint-test" "$ATTESTATION_ID"
```
