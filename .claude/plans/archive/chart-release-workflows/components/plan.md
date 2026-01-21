# Shared Components Development - Phase Plan

## Overview

This plan covers the development of the 5 custom shell functions and configuration files that are shared across multiple workflows.

### Related Documents
- **Components Index**: [components-index.md](../components-index.md)
- **ADR-003**: [Attestation Storage Format](../adr/ADR-003-attestation-storage-format.md)
- **Research**: [05-research-plan.md](../05-research-plan.md)

---

## Implementation Language Decision

### Decision: **Bash Shell Functions**

**Rationale**:
1. **Simplicity**: Shell functions can be sourced directly in workflow steps
2. **No Build Step**: Unlike composite actions or Node.js actions, no compilation needed
3. **Portable**: Works with standard GitHub Actions runners
4. **Easy Testing**: Can be tested locally with simple bash tests
5. **Minimal Dependencies**: Only requires `gh`, `jq`, and `git` (pre-installed)

**Trade-offs Considered**:

| Option | Pros | Cons | Decision |
|--------|------|------|----------|
| Bash Shell Functions | Simple, no build, easy to source | Limited error handling, no types | ✅ **Selected** |
| Composite Actions | Reusable, inputs/outputs defined | More boilerplate, slower iteration | ❌ Overkill |
| TypeScript Actions | Type safety, better testing | Requires build step, Node.js dep | ❌ Overkill |
| Python Scripts | Good stdlib, readable | Python dep, slower startup | ❌ Unnecessary |

**References**:
- [GitHub Actions Composite vs Reusable Workflows](https://dev.to/hkhelil/github-actions-composite-vs-reusable-workflows-4bih)
- Composite actions are better for complex multi-step logic; our functions are simpler

---

## GitHub App Decision

### Decision: **Use Ruleset Bypass for GitHub Actions**

**Rationale**:
1. GitHub rulesets support "Bypass mode" for GitHub Actions
2. Avoids complexity of managing GitHub App credentials
3. Already have 1Password integration if needed as fallback

**Workflows Needing Elevated Permissions**:

| Workflow | Action | Solution |
|----------|--------|----------|
| W5 | Push version bump to PR branch | `GITHUB_TOKEN` should work (PR author) |
| W6 | Create/push tags | Ruleset bypass for Actions |

**Fallback Plan**:
If `GITHUB_TOKEN` is insufficient:
1. Use existing 1Password-managed GitHub App token
2. OR create dedicated "release-bot" GitHub App with minimal permissions

**GitHub App Best Practices** (if needed):
- Minimum permissions principle
- Store private key in secrets (not repo)
- Use installation access tokens (expire in 1 hour)
- Reference: [GitHub App Best Practices](https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/best-practices-for-creating-a-github-app)

---

## Development Phases

### Phase C.1: Create Shell Library Skeleton
**Effort**: Low
**Dependencies**: None

**Tasks**:
1. Create `.github/scripts/attestation-lib.sh`
2. Add shebang and header documentation
3. Add stub functions for each component
4. Add basic error handling pattern

**Deliverable**:
```bash
#!/usr/bin/env bash
# .github/scripts/attestation-lib.sh
# Shared functions for attestation-backed release workflows

set -euo pipefail

# Error handling
error() { echo "::error::$*" >&2; exit 1; }
warn() { echo "::warning::$*" >&2; }
info() { echo "::notice::$*"; }

# Attestation map operations
update_attestation_map() { :; }    # TODO
extract_attestation_map() { :; }   # TODO
verify_attestation_chain() { :; }  # TODO

# Chart detection
detect_changed_charts() { :; }     # TODO

# Validation
validate_source_branch() { :; }    # TODO
```

---

### Phase C.2: Implement `update_attestation_map`
**Effort**: Medium
**Dependencies**: Phase C.1, ADR-003

**Used by**: W1, W5, W7
**Priority**: 🔴 High (blocking)

**Tasks**:
1. Implement PR body extraction
2. Implement attestation map JSON parsing
3. Implement JSON update logic
4. Implement PR body update with retry
5. Handle race conditions with exponential backoff

**Implementation**:
```bash
update_attestation_map() {
  local check_name="$1"
  local attestation_id="$2"
  local pr_number="${3:-$PR_NUMBER}"
  local max_retries=3
  local retry=0

  while [ $retry -lt $max_retries ]; do
    # Get current body
    local body
    body=$(gh pr view "$pr_number" --json body -q '.body')

    # Extract existing map or create new
    local existing
    existing=$(echo "$body" | grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | tr -d '\0' || echo '{}')

    # Validate JSON
    if ! echo "$existing" | jq empty 2>/dev/null; then
      existing='{}'
    fi

    # Update map
    local updated
    updated=$(echo "$existing" | jq --arg k "$check_name" --arg v "$attestation_id" '. + {($k): $v}')

    # Build new body
    local new_body
    if echo "$body" | grep -q "ATTESTATION_MAP"; then
      # Replace existing map
      new_body=$(echo "$body" | sed -E "s|<!-- ATTESTATION_MAP[[:space:]]*\n[^-]+-->|<!-- ATTESTATION_MAP\n$updated\n-->|")
    else
      # Append new map
      new_body="$body

<!-- ATTESTATION_MAP
$updated
-->"
    fi

    # Attempt update
    if gh pr edit "$pr_number" --body "$new_body"; then
      info "Updated attestation map: $check_name = $attestation_id"
      return 0
    fi

    retry=$((retry + 1))
    warn "Retry $retry/$max_retries for attestation map update"
    sleep $((2 ** retry))
  done

  error "Failed to update attestation map after $max_retries retries"
}
```

**Test Cases**:
- [ ] Add attestation to empty PR body
- [ ] Add attestation to existing map
- [ ] Update existing attestation key
- [ ] Handle concurrent updates (retry logic)
- [ ] Handle invalid JSON in existing map

---

### Phase C.3: Implement `extract_attestation_map`
**Effort**: Low
**Dependencies**: Phase C.1, ADR-003

**Used by**: W2, W4, W5, W6, W7, W8
**Priority**: 🔴 High (blocking)

**Tasks**:
1. Extract map from PR number OR stdin
2. Parse and validate JSON
3. Handle missing map gracefully

**Implementation**:
```bash
extract_attestation_map() {
  local pr_number="${1:-}"
  local body

  if [ -n "$pr_number" ]; then
    body=$(gh pr view "$pr_number" --json body -q '.body')
  else
    body=$(cat -)
  fi

  local map
  map=$(echo "$body" | grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | tr -d '\0' || echo '{}')

  # Validate JSON
  if ! echo "$map" | jq empty 2>/dev/null; then
    warn "Invalid attestation map JSON, returning empty"
    echo '{}'
    return 0
  fi

  echo "$map"
}
```

**Test Cases**:
- [ ] Extract from PR with map
- [ ] Extract from PR without map (return empty)
- [ ] Extract from stdin
- [ ] Handle malformed JSON

---

### Phase C.4: Implement `verify_attestation_chain`
**Effort**: High
**Dependencies**: Phase C.3

**Used by**: W5, W7
**Priority**: 🔴 High (blocking)

**Tasks**:
1. Iterate over attestation map entries
2. Verify each attestation ID using `gh attestation verify`
3. Track failures
4. Return detailed report

**Implementation**:
```bash
verify_attestation_chain() {
  local attestation_map="${1:-}"
  local repo="${GITHUB_REPOSITORY:-}"
  local failed=0
  local verified=0

  if [ -z "$attestation_map" ]; then
    error "Attestation map is empty"
  fi

  # Parse map
  local keys
  keys=$(echo "$attestation_map" | jq -r 'keys[]')

  for key in $keys; do
    local id
    id=$(echo "$attestation_map" | jq -r --arg k "$key" '.[$k]')
    info "Verifying $key: $id"

    # Note: gh attestation verify syntax may vary
    # This is a placeholder for the actual verification
    if gh attestation verify --repo "$repo" --attestation-id "$id" 2>/dev/null; then
      verified=$((verified + 1))
      echo "✅ $key: verified"
    else
      failed=$((failed + 1))
      echo "❌ $key: FAILED"
      warn "Failed to verify attestation: $key ($id)"
    fi
  done

  echo ""
  echo "Summary: $verified verified, $failed failed"

  if [ $failed -gt 0 ]; then
    return 1
  fi
  return 0
}
```

**Open Questions**:
- [ ] Exact `gh attestation verify` syntax and parameters
- [ ] How to verify against specific subjects

**Test Cases**:
- [ ] Verify valid attestation map
- [ ] Handle missing attestation
- [ ] Handle invalid attestation ID
- [ ] Return proper exit code on failure

---

### Phase C.5: Implement `detect_changed_charts`
**Effort**: Low
**Dependencies**: Phase C.1

**Used by**: W2, W6, W7, W8
**Priority**: 🟡 Medium

**Tasks**:
1. Parse git diff output
2. Filter to charts/ directory
3. Extract unique chart names
4. Handle edge cases

**Implementation**:
```bash
detect_changed_charts() {
  local range="${1:-HEAD~1..HEAD}"

  git diff --name-only "$range" | \
    grep '^charts/' | \
    cut -d'/' -f2 | \
    sort -u | \
    grep -v '^$' || true
}
```

**Test Cases**:
- [ ] Single chart changed
- [ ] Multiple charts changed
- [ ] No charts changed (return empty)
- [ ] Non-chart files in charts/ directory

---

### Phase C.6: Implement `validate_source_branch`
**Effort**: Low
**Dependencies**: Phase C.1

**Used by**: W3, W7
**Priority**: 🟡 Medium

**Implementation**:
```bash
validate_source_branch() {
  local source="$1"
  local expected="$2"

  if [[ "$source" != "$expected" ]]; then
    error "Invalid source branch: $source (expected: $expected)"
    return 1
  fi

  info "Source branch validated: $source"
  return 0
}
```

---

### Phase C.7: Configuration Files
**Effort**: Medium
**Dependencies**: Phase C.1

**Tasks**:

#### cliff.toml (git-cliff config)
```toml
# .github/cliff.toml
[git]
conventional_commits = true
filter_commits = true
split_commits = false
protect_breaking_commits = false
tag_pattern = ".*-v[0-9]+\\.[0-9]+\\.[0-9]+"

commit_parsers = [
    { message = "^feat", group = "Features" },
    { message = "^fix", group = "Bug Fixes" },
    { message = "^docs", group = "Documentation" },
    { message = "^perf", group = "Performance" },
    { message = "^refactor", group = "Refactoring" },
    { message = "^style", group = "Styling" },
    { message = "^test", group = "Testing" },
    { message = "^chore", skip = true },
    { message = "^ci", skip = true },
]

[changelog]
header = "# Changelog\n\nAll notable changes to this chart will be documented in this file.\n\n"
body = """
{% for group, commits in commits | group_by(attribute="group") %}
## {{ group }}

{% for commit in commits %}
- {{ commit.message | split(pat="\n") | first }} ([{{ commit.id | truncate(length=7, end="") }}](https://github.com/{{ remote.github.owner }}/{{ remote.github.repo }}/commit/{{ commit.id }}))
{% endfor %}

{% endfor %}
"""
footer = ""
```

#### commitlint.config.js
```javascript
// .github/commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-enum': [
      2,
      'always',
      [
        'cloudflared',
        'external-secrets-operator',
        // Add new chart names here
        'deps',
        'ci',
        'docs',
      ],
    ],
    'subject-case': [2, 'never', ['start-case', 'pascal-case', 'upper-case']],
  },
};
```

---

## File Structure

```
.github/
├── scripts/
│   └── attestation-lib.sh        # Shared shell functions
├── cliff.toml                     # git-cliff config
└── commitlint.config.js          # commitlint config
```

---

## Testing Strategy

### Local Testing
```bash
# Source the library
source .github/scripts/attestation-lib.sh

# Test individual functions
detect_changed_charts "HEAD~3..HEAD"
validate_source_branch "integration" "integration"
```

### CI Testing
Create test workflow to validate functions on push:
```yaml
# .github/workflows/test-attestation-lib.yaml
name: Test Attestation Library
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: |
          source .github/scripts/attestation-lib.sh
          # Add test assertions
```

---

## Success Criteria

- [ ] All 5 functions implemented and documented
- [ ] Functions can be sourced without errors
- [ ] Local testing passes for all functions
- [ ] CI test workflow passes
- [ ] `cliff.toml` generates valid changelog
- [ ] `commitlint.config.js` validates conventional commits
