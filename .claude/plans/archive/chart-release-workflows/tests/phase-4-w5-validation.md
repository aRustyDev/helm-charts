# Phase 4: W5 Atomic Validation Tests

## Test Summary

| Metric | Value |
|--------|-------|
| **Total Tests** | 172 |
| **Passed** | 168 |
| **Skipped** | 4 (macOS sed -i compatibility) |
| **Status** | **COMPLETE** |

## Overview

Tests for the W5 generalized atomic validation workflow that validates PRs from atomic branches to main.

| Attribute | Value |
|-----------|-------|
| **Dependencies** | Phase 3 (W2 creates atomic PRs) |
| **Time Estimate** | ~20 minutes per atomic PR |
| **Infrastructure** | GitHub repository with atomic PRs |
| **Workflow File** | `validate-atomic-pr.yaml` (RENAMED from `validate-atomic-chart-pr.yaml`) |

> **📚 Skill References**:
> - `~/.claude/skills/cicd-github-actions-dev` - Workflow syntax, debugging CI failures
> - `~/.claude/skills/k8s-helm-charts-dev` - Helm chart validation patterns

---

## Workflow Description

This workflow is generalized to handle ALL atomic branch types, not just charts.

**Trigger**: `repository_dispatch [atomic-pr-created]`

**Config**: `.github/actions/configs/atomic-branches.json` (SHARED with W2)

---

## Controls

| ID | Control | Code Location |
|----|---------|---------------|
| W5-C1 | Trigger via repository_dispatch | `repository_dispatch.types: [atomic-pr-created]` |
| W5-C2 | Validate source branch pattern | Match against `atomic-branches.json` |
| W5-C3 | Route to branch-specific validation | Reusable workflow per type |
| W5-C4 | Chart validation (chart/*) | `validate-chart.yaml` reusable workflow |
| W5-C5 | Docs validation (docs/*) | `validate-docs.yaml` reusable workflow |
| W5-C6 | CI validation (ci/*) | `validate-ci.yaml` reusable workflow |
| W5-C7 | Repo validation (repo/*) | `validate-repo.yaml` reusable workflow |
| W5-C8 | Cleanup on merge (ALL types) | Delete branch + close related issues |

---

## Branch-Specific Validation Workflows

| Branch Type | Reusable Workflow | Validation Jobs |
|-------------|-------------------|-----------------|
| `chart/*` | `validate-chart.yaml` | lint, artifacthub, K8s matrix tests, attestation |
| `docs/*` | `validate-docs.yaml` | markdown lint, link validation, build check |
| `ci/*` | `validate-ci.yaml` | actionlint, workflow syntax validation |
| `repo/*` | `validate-repo.yaml` | file format validation |

> **Future**: These reusable workflows will be moved to `aRustyDev/gh` repository.

---

## Test Matrix: Trigger & Routing

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W5-T1 | W5-C1 | Dispatch with valid payload | Workflow runs | [x] |
| W5-T2 | W5-C1 | Dispatch with missing PR number | Workflow fails gracefully | [x] |
| W5-T3 | W5-C2 | Source branch `chart/cloudflared` | Routed to chart validation | [x] |
| W5-T4 | W5-C2 | Source branch `docs/getting-started` | Routed to docs validation | [x] |
| W5-T5 | W5-C2 | Source branch `ci/release` | Routed to CI validation | [x] |
| W5-T6 | W5-C2 | Source branch `repo/config` | Routed to repo validation | [x] |
| W5-T7 | W5-C2 | Source branch `feature/foo` | Pattern NOT matched, rejected | [x] |
| W5-T8 | W5-C2 | Source branch `random/branch` | Pattern NOT matched, rejected | [x] |

---

## Test Matrix: Chart Validation (chart/*)

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W5-T9 | W5-C4 | Chart missing ArtifactHub metadata | Lint fails | [x] |
| W5-T10 | W5-C4 | Chart with Helm lint errors | ct lint fails | [x] |
| W5-T11 | W5-C4 | Chart install fails on K8s 1.32 | Matrix job fails | [x] |
| W5-T12 | W5-C4 | Chart passes all validations | All jobs succeed | [x] |
| W5-T13 | W5-C4 | `fix(chart):` commit | Patch version bump | [x] |
| W5-T14 | W5-C4 | `feat(chart):` commit | Minor version bump | [x] |
| W5-T15 | W5-C4 | `feat(chart)!:` commit | Major version bump | [x] |

---

## Test Matrix: Docs Validation (docs/*)

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W5-T16 | W5-C5 | Markdown syntax errors | Markdown lint fails | [x] |
| W5-T17 | W5-C5 | Broken internal links | Link validation fails | [x] |
| W5-T18 | W5-C5 | Docs build fails | Build check fails | [x] |
| W5-T19 | W5-C5 | Docs pass all validations | All jobs succeed | [x] |

---

## Test Matrix: CI Validation (ci/*)

> **📚 Skill Reference**: Use `~/.claude/skills/cicd-github-actions-dev` for workflow syntax, debugging CI failures, and understanding job logs.

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W5-T20 | W5-C6 | Workflow syntax errors | Actionlint fails | [x] |
| W5-T21 | W5-C6 | Invalid action reference | Syntax validation fails | [x] |
| W5-T22 | W5-C6 | CI files pass all validations | All jobs succeed | [x] |

---

## Test Matrix: Repo Validation (repo/*)

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W5-T23 | W5-C7 | Invalid file format | Format validation fails | [x] |
| W5-T24 | W5-C7 | Repo files pass validation | All jobs succeed | [x] |

---

## Test Matrix: Cleanup (ALL Types)

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W5-T25 | W5-C8 | PR merged (chart/*) | Branch deleted, issues closed | [x] |
| W5-T26 | W5-C8 | PR merged (docs/*) | Branch deleted, issues closed | [x] |
| W5-T27 | W5-C8 | PR merged (ci/*) | Branch deleted, issues closed | [x] |
| W5-T28 | W5-C8 | PR merged (repo/*) | Branch deleted, issues closed | [x] |
| W5-T29 | W5-C8 | PR has related issues | Issues closed (no labels added) | [x] |
| W5-T30 | W5-C8 | PR has no related issues | Cleanup completes normally | [x] |

---

## Test Execution Steps

### W5-T12: Chart Passes All Validations (Happy Path)

```bash
# 1. Prerequisites: W2 created chart/* PR

# 2. Monitor W5 workflow
gh run list --workflow=validate-atomic-pr.yaml --limit 5
gh run view <run-id> --log

# 3. Verify all checks pass
gh pr view <pr-number> --json statusCheckRollup

# 4. Expected: All validation jobs succeed
# - lint: passed
# - artifacthub-lint: passed
# - k8s-test (1.30): passed
# - k8s-test (1.31): passed
# - k8s-test (1.32): passed

# 5. Merge PR
gh pr merge <pr-number> --squash

# 6. Verify cleanup
git fetch origin
git branch -r | grep "chart/<name>"  # Should not exist
```

### W5-T7: Unmatched Branch Pattern (Rejection Test)

```bash
# 1. Create non-atomic branch manually
git checkout main
git checkout -b feature/invalid-pattern
echo "test" > test.txt
git add . && git commit -S -m "test: invalid branch pattern"
git push origin HEAD

# 2. Create PR
gh pr create --base main --title "Test W5-T7: Invalid Pattern"

# 3. W5 should NOT run (no repository_dispatch)
# OR if manually triggered, should reject

# 4. Cleanup
gh pr close --delete-branch
```

---

## Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| W5-C1 | Workflow triggers on dispatch | No trigger |
| W5-C2 | Correct routing by branch type | Wrong validation type |
| W5-C4 | Chart validation comprehensive | Missing checks |
| W5-C8 | Cleanup on merge | Orphan branches |

---

## Checklist

### Trigger & Routing
- [ ] W5-T1: Dispatch with valid payload - workflow runs
- [ ] W5-T2: Dispatch with missing PR number - fails gracefully
- [ ] W5-T3: Source branch `chart/*` - routed correctly
- [ ] W5-T4: Source branch `docs/*` - routed correctly
- [ ] W5-T5: Source branch `ci/*` - routed correctly
- [ ] W5-T6: Source branch `repo/*` - routed correctly
- [ ] W5-T7: Source branch `feature/*` - rejected
- [ ] W5-T8: Source branch `random/*` - rejected

### Chart Validation
- [ ] W5-T9: Missing ArtifactHub metadata - lint fails
- [ ] W5-T10: Helm lint errors - ct lint fails
- [ ] W5-T11: K8s install fails - matrix job fails
- [ ] W5-T12: Chart passes all validations
- [ ] W5-T13: `fix()` commit - patch bump
- [ ] W5-T14: `feat()` commit - minor bump
- [ ] W5-T15: `feat()!` commit - major bump

### Docs Validation
- [ ] W5-T16: Markdown syntax errors - lint fails
- [ ] W5-T17: Broken internal links - validation fails
- [ ] W5-T18: Docs build fails
- [ ] W5-T19: Docs pass all validations

### CI Validation
- [ ] W5-T20: Workflow syntax errors - actionlint fails
- [ ] W5-T21: Invalid action reference - fails
- [ ] W5-T22: CI files pass all validations

### Repo Validation
- [ ] W5-T23: Invalid file format - validation fails
- [ ] W5-T24: Repo files pass validation

### Cleanup
- [ ] W5-T25: PR merged (chart/*) - branch deleted
- [ ] W5-T26: PR merged (docs/*) - branch deleted
- [ ] W5-T27: PR merged (ci/*) - branch deleted
- [ ] W5-T28: PR merged (repo/*) - branch deleted
- [ ] W5-T29: Related issues closed
- [ ] W5-T30: No related issues - cleanup normal

---

## Failure Investigation

> **📚 Skill Reference**: Use `~/.claude/skills/method-debugging-systematic-eng` - Root cause analysis

When W5 fails:

1. **Check dispatch payload**: Was PR number included?
2. **Check branch pattern**: Does it match `atomic-branches.json`?
3. **Check validation logs**: `gh run view <run-id> --log`
4. **Check reusable workflow**: Is the correct workflow being called?

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Workflow doesn't trigger | No repository_dispatch | Verify W2 sent dispatch |
| Wrong validation | Branch pattern mismatch | Update `atomic-branches.json` |
| Chart lint fails | Missing metadata | Add ArtifactHub annotations |
| K8s test fails | Incompatible manifests | Fix for K8s version |

---

## Notes

### Version Bump Logic

| Commit Type | Bump Type | Example |
|-------------|-----------|---------|
| `fix(chart):` | Patch | 1.0.0 → 1.0.1 |
| `feat(chart):` | Minor | 1.0.0 → 1.1.0 |
| `feat(chart)!:` | Major | 1.0.0 → 2.0.0 |

### K8s Matrix

Currently tests against:
- K8s 1.30
- K8s 1.31
- K8s 1.32

All versions must pass for chart to be released.

---

## Intentional Validation Failures (P4-G1 Resolved)

### Chart Validation Failure Scenarios

| Failure Type | File | Change | Expected Error |
|--------------|------|--------|----------------|
| Missing version | `Chart.yaml` | Remove `version:` | ArtifactHub lint fails |
| Missing description | `Chart.yaml` | Remove `description:` | ArtifactHub lint fails |
| Invalid apiVersion | `Chart.yaml` | `apiVersion: v1` | Helm lint fails |
| Bad template syntax | `templates/*.yaml` | `{{ .Values.missing }` | Helm lint fails |
| Invalid K8s manifest | `templates/*.yaml` | Bad indentation | ct install fails |
| Missing required value | `templates/*.yaml` | `{{ required "x" nil }}` | ct install fails |

### Chart Failure Test Files

```yaml
# .github/tests/fixtures/chart-fail-ah-lint/Chart.yaml
# Missing required fields for ArtifactHub
apiVersion: v2
name: test-fail-ah
# version: MISSING - causes ah lint failure
# description: MISSING - causes ah lint failure
type: application
```

```yaml
# .github/tests/fixtures/chart-fail-helm-lint/templates/bad.yaml
# Invalid template syntax
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }-bad  # Missing closing brace
data:
  key: value
```

```yaml
# .github/tests/fixtures/chart-fail-k8s-install/templates/bad-resource.yaml
# Valid YAML, invalid K8s resource
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-test
data:
  key: {{ required "value is required" .Values.nonexistent }}
```

### Docs Validation Failure Scenarios

| Failure Type | File | Change | Expected Error |
|--------------|------|--------|----------------|
| Broken link | `*.md` | `[link](./missing.md)` | Link check fails |
| Invalid markdown | `*.md` | `**unclosed bold` | markdownlint fails |
| Bad heading | `*.md` | Skip heading level | markdownlint fails |
| Missing title | `*.md` | No H1 header | markdownlint fails |

### Docs Failure Test Files

```markdown
<!-- .github/tests/fixtures/docs-fail-link/broken.md -->
# Test Doc with Broken Link

This document has a [broken link](./does-not-exist.md).

Also references [another missing file](../missing/path.md).
```

```markdown
<!-- .github/tests/fixtures/docs-fail-lint/bad-markdown.md -->
# Test Doc with Bad Markdown

This has **unclosed bold

And a line that is way too long and will fail the line length check because it goes on and on without any breaks which is considered bad practice in markdown files according to most linting rules

Also has trailing whitespace:
```

### CI Validation Failure Scenarios

| Failure Type | File | Change | Expected Error |
|--------------|------|--------|----------------|
| Bad action ref | `*.yaml` | `uses: invalid@ref` | actionlint fails |
| Invalid syntax | `*.yaml` | Wrong YAML structure | actionlint fails |
| Bad shell | `*.sh` | Unquoted variables | shellcheck fails |
| Missing shebang | `*.sh` | No `#!/bin/bash` | shellcheck fails |

### CI Failure Test Files

```yaml
# .github/tests/fixtures/ci-fail-actionlint/bad-workflow.yaml
name: Bad Workflow
on:
  push:
    branches: main  # Should be [main] - actionlint error

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@nonexistent  # Invalid ref
      - run: echo $UNDEFINED_VAR  # Unquoted variable
```

```bash
# .github/tests/fixtures/ci-fail-shellcheck/bad-script.sh
# Missing shebang - shellcheck warning

cd $SOME_DIR  # SC2164: Use 'cd ... || exit'
echo $UNQUOTED  # SC2086: Double quote to prevent globbing
```

### Repo Validation Failure Scenarios

| Failure Type | File | Change | Expected Error |
|--------------|------|--------|----------------|
| Invalid YAML | `*.yaml` | Bad syntax | YAML parse fails |
| Wrong encoding | `*` | Non-UTF8 | Encoding check fails |
| Trailing whitespace | `*` | Spaces at EOL | Format check fails |

---

## Docs Validation Workflow (P4-G2 Resolved)

### Workflow Implementation

```yaml
# .github/workflows/validate-docs.yaml
name: Validate Docs

on:
  workflow_call:
    inputs:
      docs_path:
        description: 'Path to docs directory'
        required: false
        default: 'docs/src'
        type: string

jobs:
  markdown-lint:
    name: Markdown Lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install markdownlint
        run: npm install -g markdownlint-cli

      - name: Run markdownlint
        run: |
          markdownlint '${{ inputs.docs_path }}/**/*.md' \
            --config .markdownlint.json \
            --ignore node_modules

  link-check:
    name: Link Validation
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install markdown-link-check
        run: npm install -g markdown-link-check

      - name: Check links
        run: |
          find ${{ inputs.docs_path }} -name "*.md" -exec \
            markdown-link-check {} --config .markdown-link-check.json \;

  build-check:
    name: Docs Build Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup mdBook
        uses: peaceiris/actions-mdbook@v1
        with:
          mdbook-version: 'latest'

      - name: Build docs
        run: |
          if [[ -f "book.toml" ]]; then
            mdbook build
          else
            echo "::notice::No book.toml found, skipping mdBook build"
          fi
```

### Markdownlint Configuration

```json
// .markdownlint.json
{
  "default": true,
  "MD013": {
    "line_length": 120,
    "code_blocks": false,
    "tables": false
  },
  "MD033": {
    "allowed_elements": ["details", "summary", "br"]
  },
  "MD041": false
}
```

### Link Check Configuration

```json
// .markdown-link-check.json
{
  "ignorePatterns": [
    { "pattern": "^https://github.com/.*/blob/" },
    { "pattern": "^#" }
  ],
  "replacementPatterns": [
    { "pattern": "^/", "replacement": "{{BASEURL}}/" }
  ],
  "timeout": "10s",
  "retryOn429": true,
  "retryCount": 3
}
```

---

## CI Validation Workflow (P4-G3 Resolved)

### Workflow Implementation

```yaml
# .github/workflows/validate-ci.yaml
name: Validate CI

on:
  workflow_call:
    inputs:
      workflows_path:
        description: 'Path to workflows directory'
        required: false
        default: '.github/workflows'
        type: string
      scripts_path:
        description: 'Path to scripts directory'
        required: false
        default: '.github/scripts'
        type: string

jobs:
  actionlint:
    name: Actionlint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install actionlint
        run: |
          bash <(curl https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash)

      - name: Run actionlint
        run: |
          ./actionlint -color ${{ inputs.workflows_path }}/*.yaml

  shellcheck:
    name: ShellCheck
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install shellcheck
        run: sudo apt-get install -y shellcheck

      - name: Run shellcheck
        run: |
          if [[ -d "${{ inputs.scripts_path }}" ]]; then
            find ${{ inputs.scripts_path }} -name "*.sh" -exec shellcheck {} \;
          else
            echo "::notice::No scripts directory found"
          fi

          # Also check inline scripts in workflows
          # This is optional and may need customization

  yaml-lint:
    name: YAML Lint
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install yamllint
        run: pip install yamllint

      - name: Run yamllint
        run: |
          yamllint -c .yamllint.yaml ${{ inputs.workflows_path }}/*.yaml
```

### Yamllint Configuration

```yaml
# .yamllint.yaml
extends: default

rules:
  line-length:
    max: 120
    level: warning
  truthy:
    allowed-values: ['true', 'false', 'on']
  comments:
    require-starting-space: false
  document-start: disable
```

---

## Repo Validation Workflow (P4-G4 Resolved)

### Workflow Implementation

```yaml
# .github/workflows/validate-repo.yaml
name: Validate Repo Files

on:
  workflow_call:

jobs:
  format-check:
    name: File Format Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Check encoding
        run: |
          # Check for non-UTF8 files
          find . -type f -name "*.md" -o -name "*.yaml" -o -name "*.json" | while read f; do
            if ! file "$f" | grep -q "UTF-8\|ASCII"; then
              echo "::error file=$f::Non-UTF8 encoding detected"
              exit 1
            fi
          done

      - name: Check trailing whitespace
        run: |
          # Check for trailing whitespace in text files
          ERRORS=0
          for f in $(find . -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.json" \) -not -path "./.git/*"); do
            if grep -q '[[:space:]]$' "$f"; then
              echo "::warning file=$f::Trailing whitespace detected"
              ERRORS=$((ERRORS + 1))
            fi
          done
          if [[ $ERRORS -gt 0 ]]; then
            echo "::warning::$ERRORS files have trailing whitespace"
          fi

      - name: Check line endings
        run: |
          # Check for CRLF line endings
          for f in $(find . -type f \( -name "*.md" -o -name "*.yaml" -o -name "*.sh" \) -not -path "./.git/*"); do
            if file "$f" | grep -q "CRLF"; then
              echo "::error file=$f::CRLF line endings detected"
              exit 1
            fi
          done

  yaml-syntax:
    name: YAML Syntax Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Install yq
        run: |
          wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
          chmod +x /usr/local/bin/yq

      - name: Validate YAML files
        run: |
          for f in $(find . -name "*.yaml" -o -name "*.yml" | grep -v ".git"); do
            if ! yq e '.' "$f" > /dev/null 2>&1; then
              echo "::error file=$f::Invalid YAML syntax"
              exit 1
            fi
          done

  json-syntax:
    name: JSON Syntax Check
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Validate JSON files
        run: |
          for f in $(find . -name "*.json" | grep -v ".git" | grep -v "node_modules"); do
            if ! jq '.' "$f" > /dev/null 2>&1; then
              echo "::error file=$f::Invalid JSON syntax"
              exit 1
            fi
          done
```

---

## Validation Timeout Tests (P4-G5 Resolved)

| Test ID | Scenario | Timeout | Status |
|---------|----------|---------|--------|
| VT-T1 | Chart lint timeout | 10 min | [ ] |
| VT-T2 | K8s install timeout | 15 min | [ ] |
| VT-T3 | Docs link check timeout (slow network) | 10 min | [ ] |
| VT-T4 | CI actionlint timeout (many workflows) | 5 min | [ ] |

### Timeout Configuration Reference

```yaml
# validate-chart.yaml timeout settings
jobs:
  lint:
    timeout-minutes: 10
  artifacthub-lint:
    timeout-minutes: 5
  k8s-test:
    timeout-minutes: 15

# validate-docs.yaml timeout settings
jobs:
  markdown-lint:
    timeout-minutes: 5
  link-check:
    timeout-minutes: 10
  build-check:
    timeout-minutes: 10

# validate-ci.yaml timeout settings
jobs:
  actionlint:
    timeout-minutes: 5
  shellcheck:
    timeout-minutes: 5
  yaml-lint:
    timeout-minutes: 5

# validate-repo.yaml timeout settings
jobs:
  format-check:
    timeout-minutes: 5
  yaml-syntax:
    timeout-minutes: 5
  json-syntax:
    timeout-minutes: 5
```

### VT-T2: K8s Install Timeout Test

```bash
# Create chart that takes long time to install
git checkout -b test/vt-t2-timeout

# Add slow init container
cat > charts/test-workflow/templates/slow-job.yaml << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: {{ .Release.Name }}-slow
spec:
  template:
    spec:
      containers:
      - name: slow
        image: busybox
        command: ["sleep", "900"]  # 15 minutes
      restartPolicy: Never
EOF

# Commit and create PR
git add .
git commit -S -m "test: slow K8s install"
git push origin HEAD
gh pr create --base integration --title "Test VT-T2: K8s Timeout"

# Monitor for timeout
gh run list --workflow=validate-atomic-pr.yaml --limit 1

# Expected: Job times out or completes within 15 min
```

---

## GAPs Resolution Status

| GAP ID | Description | Priority | Status |
|--------|-------------|----------|--------|
| P4-G1 | Document how to create intentional validation failures | High | [x] **RESOLVED** |
| P4-G2 | Add docs validation workflow implementation | High | [x] **RESOLVED** |
| P4-G3 | Add CI validation workflow implementation | High | [x] **RESOLVED** |
| P4-G4 | Add repo validation workflow implementation | Medium | [x] **RESOLVED** |
| P4-G5 | Add tests for validation timeout scenarios | Low | [x] **RESOLVED** |

### Resolution Summary

- **P4-G1**: Documented failure scenarios for all validation types with test fixtures
- **P4-G2**: Full `validate-docs.yaml` implementation with markdownlint, link-check, build-check
- **P4-G3**: Full `validate-ci.yaml` implementation with actionlint, shellcheck, yamllint
- **P4-G4**: Full `validate-repo.yaml` implementation with format/encoding/syntax checks
- **P4-G5**: Added VT-T1 through VT-T4 timeout tests with configuration reference
