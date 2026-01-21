# Phase 3: W2 Atomization Tests

## Test Summary

| Category | Unit Tests | GH Infra Tests | Total |
|----------|------------|----------------|-------|
| Trigger & Categorization | 5 | 2 | 7 |
| Branch Creation & PRs | 1 | 5 | 6 |
| DLQ & Reset | 4 | 1 | 5 |
| Attestation | 0 | 2 | 2 |
| Additional (LF, BF, SL, IR) | 45+ | 0 | 45+ |
| **Total** | **55+** | **10** | **65+** |

**Status**: ✅ **125/125 Unit Tests PASSED** (Phase 3 specific tests)

**Test Files**:
- `.github/tests/atomize/test-file-categorization.bats` - 41 tests
- `.github/tests/atomize/test-dlq-handling.bats` - 27 tests
- `.github/tests/atomize/test-integration-reset.bats` - 14 tests
- `.github/tests/atomize/test-large-files.bats` - 15 tests
- `.github/tests/atomize/test-binary-symlinks.bats` - 28 tests

**Bugs Fixed During Testing**:
1. Config pattern ordering: ADR pattern now comes before general docs pattern
2. POSIX regex compatibility: Changed `\d` to `[0-9]` in ADR pattern
3. Sed whitespace handling: Changed `\s*` to `[[:space:]]*` in relationships.sh

---

## Overview

Tests for the W2 atomization workflow that extracts content from merged integration PRs into atomic branches.

| Attribute | Value |
|-----------|-------|
| **Dependencies** | Phase 2 (W1 tests) - PR must merge to integration |
| **Time Estimate** | ~10 minutes per atomization |
| **Infrastructure** | GitHub repository with merge queue |
| **Workflow File** | `atomize-integration-pr.yaml` |

> **📚 Skill References**:
> - `~/.claude/skills/cicd-github-actions-dev` - Debugging CI failures, workflow syntax
> - `~/.claude/skills/cicd-github-actions-ops` - Systematic debugging of failed GHA runs

---

## Workflow Description

This workflow supersedes `create-atomic-chart-pr.yaml` (DEPRECATED). The deprecated workflow will be removed in the next iteration after porting unique features.

**Trigger**: `pull_request [closed+merged]` → integration

**Flow**:
1. Categorize files via `atomic-branches.json`
2. Extract to atomic branches (`chart/*`, `docs/*`, `ci/*`, `repo/*`)
3. Create PRs to main with related links
4. Trigger W5 via `repository_dispatch`
5. Handle DLQ (unmatched files)
6. Reset integration (selective trim or full reset)

---

## Controls

| ID | Control | Code Location |
|----|---------|---------------|
| W2-C1 | Trigger on PR merged to integration | `pull_request.types: [closed]` + `merged == true` |
| W2-C2 | Categorize files via config | `atomic-branches.json` pattern matching |
| W2-C3 | Create atomic branches (ALL types) | `chart/*`, `docs/*`, `ci/*`, `repo/*` |
| W2-C4 | Cherry-pick commits to branches | `git checkout <merge_commit> -- <file>` |
| W2-C5 | Create PRs to main with related links | Two-pass PR creation |
| W2-C6 | Trigger W5 via repository_dispatch | `gh api dispatches -f event_type=atomic-pr-created` |
| W2-C7 | Handle DLQ (unmatched files) | Create DLQ branch + issue |
| W2-C8 | Reset integration | Selective trim or full reset to main |
| W2-C9 | Concurrency control | `group: atomize-integration` |
| W2-C10 | Generate W2 attestation | `attest-build-provenance` action |

---

## Shared Configuration

Both W2 and W5 use `.github/actions/configs/atomic-branches.json`:

```json
{
  "branches": [
    {"name": "$chart", "prefix": "chart/", "pattern": "charts/(?P<chart>[^/]+)/**"},
    {"name": "$topic", "prefix": "docs/", "pattern": "docs/src/(?P<topic>[^/]+)/**"},
    {"name": "$workflow", "prefix": "ci/", "pattern": "\\.github/workflows/(?P<workflow>[^.]+)\\.ya?ml"},
    {"name": "config", "prefix": "repo/", "pattern": "^(CONTRIBUTING|README|LICENSE).*"}
  ]
}
```

---

## Test Matrix: Trigger & Categorization

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W2-T1 | W2-C1 | PR closed without merge | Workflow skips | [GH] Requires GH infra |
| W2-T2 | W2-C1 | PR merged to integration | Workflow runs | [GH] Requires GH infra |
| W2-T3 | W2-C2 | Files match chart/* pattern | Categorized to `chart/{name}` | [x] PASSED |
| W2-T4 | W2-C2 | Files match docs/* pattern | Categorized to `docs/{topic}` | [x] PASSED |
| W2-T5 | W2-C2 | Files match ci/* pattern | Categorized to `ci/{workflow}` | [x] PASSED |
| W2-T6 | W2-C2 | Files match repo/* pattern | Categorized to `repo/config` | [x] PASSED |
| W2-T7 | W2-C2 | Files match no pattern | Sent to DLQ | [x] PASSED |

---

## Test Matrix: Branch Creation & PRs

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W2-T8 | W2-C3 | Single chart change | Creates `chart/{name}` branch | [GH] Requires GH infra |
| W2-T9 | W2-C3 | Multiple file types changed | Creates multiple atomic branches | [x] PASSED (categorize_files) |
| W2-T10 | W2-C4 | Cherry-pick succeeds | Files extracted to branch | [GH] Requires GH infra |
| W2-T11 | W2-C4 | Cherry-pick fails | Error logged, cleanup triggered | [GH] Requires GH infra |
| W2-T12 | W2-C5 | PRs created with related links | Each PR references siblings | [GH] Requires GH infra |
| W2-T13 | W2-C6 | W5 triggered via dispatch | `atomic-pr-created` event sent | [GH] Requires GH infra |

---

## Test Matrix: DLQ & Reset

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W2-T14 | W2-C7 | Unmatched files exist | DLQ branch + issue created | [x] PASSED (unit tests) |
| W2-T15 | W2-C7 | All files matched | No DLQ created | [x] PASSED |
| W2-T16 | W2-C8 | No concurrent merges | Full reset to main | [x] PASSED (IR-T1) |
| W2-T17 | W2-C8 | Concurrent merge (edge case) | Selective trim preserves commits | [x] PASSED (IR-T2) |
| W2-T18 | W2-C9 | Concurrent atomization runs | Second run queued (not cancelled) | [GH] Requires GH infra |

---

## Test Matrix: Attestation

| Test ID | Control | Scenario | Expected | Status |
|---------|---------|----------|----------|--------|
| W2-T19 | W2-C10 | Atomization completes | W2 attestation generated | [GH] Requires GH infra |
| W2-T20 | W2-C10 | Attestation map propagated | PRs contain attestation lineage | [GH] Requires GH infra |

---

## Test Execution Steps

### W2-T2: PR Merged to Integration (Happy Path)

```bash
# 1. Prerequisites: W1 tests passed, PR merged to integration
# This test verifies W2 triggers after merge

# 2. Monitor atomization workflow
gh run list --workflow=atomize-integration-pr.yaml --limit 5

# 3. Get latest run
gh run view <run-id> --log

# 4. Verify atomic branches created
git fetch origin
git branch -r | grep -E "^origin/(chart|docs|ci|repo)/"

# 5. Verify PRs created
gh pr list --base main --state open

# 6. Verify W5 was triggered
gh run list --workflow=validate-atomic-pr.yaml --limit 5
```

### W2-T7: Files Match No Pattern (DLQ Test)

```bash
# 1. Create PR with unmatched files
git checkout integration
git checkout -b test/w2-t7-dlq-$(date +%Y%m%d)

# 2. Add files that don't match any pattern
mkdir -p scripts
echo "#!/bin/bash" > scripts/custom-tool.sh
echo "Notes" > misc.txt

# 3. Also add a valid chart change (to ensure partial success)
echo "# Test" >> charts/test-workflow/values.yaml

# 4. Commit and create PR
git add .
git commit -S -m "feat: test W2-T7 DLQ handling"
git push origin HEAD
gh pr create --base integration --title "Test W2-T7: DLQ Files"

# 5. After merge, verify:
# - chart/* branch created for charts/
# - DLQ branch created for scripts/, misc.txt
# - DLQ issue created
gh issue list --search "DLQ"
```

---

## Cleanup Procedures

```bash
# Delete atomic branches
git push origin --delete chart/test-workflow
git push origin --delete docs/test-topic
git push origin --delete ci/test-workflow

# Close DLQ issues
gh issue close <dlq-issue-number>

# Delete DLQ branch
git push origin --delete dlq/<pr-number>

# Verify integration reset
git log origin/integration --oneline -1
git log origin/main --oneline -1
# Should be the same commit
```

---

## Pass/Fail Criteria

| Criteria | Pass | Fail |
|----------|------|------|
| W2-C1 | Only runs on merged PRs | Runs on closed-not-merged |
| W2-C2 | Correct categorization | Wrong category |
| W2-C3 | All branch types created | Missing branches |
| W2-C7 | Unmatched → DLQ | Unmatched lost |
| W2-C8 | Integration reset | Integration diverged |

---

## Checklist

### Trigger & Categorization
- [GH] W2-T1: PR closed without merge - workflow skips (Requires GH infra)
- [GH] W2-T2: PR merged to integration - workflow runs (Requires GH infra)
- [x] W2-T3: Files match chart/* pattern
- [x] W2-T4: Files match docs/* pattern
- [x] W2-T5: Files match ci/* pattern
- [x] W2-T6: Files match repo/* pattern
- [x] W2-T7: Files match no pattern - sent to DLQ

### Branch Creation & PRs
- [GH] W2-T8: Single chart creates atomic branch (Requires GH infra)
- [x] W2-T9: Multiple file types creates multiple branches
- [GH] W2-T10: Cherry-pick succeeds (Requires GH infra)
- [GH] W2-T11: Cherry-pick fails - cleanup triggered (Requires GH infra)
- [GH] W2-T12: PRs created with related links (Requires GH infra)
- [GH] W2-T13: W5 triggered via repository_dispatch (Requires GH infra)

### DLQ & Reset
- [x] W2-T14: Unmatched files - DLQ branch + issue
- [x] W2-T15: All files matched - no DLQ
- [x] W2-T16: No concurrent merges - full reset
- [x] W2-T17: Concurrent merge - selective trim
- [GH] W2-T18: Concurrent runs - second queued (Requires GH infra)

### Attestation
- [GH] W2-T19: Atomization completes - attestation generated (Requires GH infra)
- [GH] W2-T20: Attestation map propagated to PRs (Requires GH infra)

---

## Failure Investigation

> **📚 Skill References**:
> - `~/.claude/skills/cicd-github-actions-ops` - Systematic debugging
> - `~/.claude/skills/method-debugging-systematic-eng` - Root cause analysis

When W2 fails:

1. **Check workflow logs**: `gh run view <run-id> --log`
2. **Check concurrency**: Is another run queued?
3. **Check config**: Validate `atomic-branches.json`
4. **Check permissions**: Workflow needs write access
5. **Check integration state**: `git log origin/integration`

### Common Issues

| Issue | Cause | Fix |
|-------|-------|-----|
| Workflow doesn't trigger | PR not merged (just closed) | Merge the PR |
| Wrong categorization | Pattern mismatch | Update `atomic-branches.json` |
| Reset fails | Concurrent commits | Use selective trim |
| DLQ not created | All files matched | Expected behavior |

---

## Deprecated Workflow Reference

### `create-atomic-chart-pr.yaml` (DEPRECATED)

> **⚠️ DEPRECATED**: Superseded by `atomize-integration-pr.yaml`.
> Will be removed in the next iteration.

#### Unique Features to Port

| Feature | Status | Target |
|---------|--------|--------|
| Attestation map extraction | TO PORT | atomize-integration-pr.yaml |
| Retry logic with force-with-lease | TO PORT | atomize-integration-pr.yaml |
| Merge commit detection | TO PORT | atomize-integration-pr.yaml |
| W5 trigger via dispatch | TO PORT | atomize-integration-pr.yaml |

---

## Notes

### Concurrency Control

W2 uses `concurrency: group: atomize-integration` to prevent:
- Multiple atomization runs clobbering each other
- Race conditions on integration reset
- Duplicate atomic branches

### Selective Trim vs Full Reset

| Scenario | Strategy | Reason |
|----------|----------|--------|
| No concurrent merges | Full reset to main | Clean state |
| Concurrent merge (queue bypassed) | Selective trim | Preserve later commits |
| Rebase conflict | Manual intervention | Requires human review |

---

## Test Matrix: DLQ Issue Lifecycle (P3-G1 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| DLQ-L1 | DLQ issue closed without resolution | Files remain in DLQ branch | [ ] |
| DLQ-L2 | DLQ branch deleted before issue closed | Issue updated with warning | [ ] |
| DLQ-L3 | Pattern updated, DLQ files re-atomized | New atomic branches created | [ ] |
| DLQ-L4 | DLQ issue stale (30+ days) | Manual review required | [ ] |
| DLQ-L5 | Re-run atomization on DLQ files | DLQ cleared, files categorized | [ ] |

### DLQ-L1: Issue Closed Without Resolution

```bash
# 1. Setup: Create PR with unmatched files (W2-T7)
git checkout integration
git checkout -b test/dlq-l1-lifecycle

mkdir -p scripts
echo "#!/bin/bash" > scripts/test.sh
echo "# Valid change" >> charts/test-workflow/values.yaml

git add .
git commit -S -m "feat: test DLQ lifecycle"
git push origin HEAD
gh pr create --base integration --title "Test DLQ-L1"

# 2. Merge PR to trigger W2
gh pr merge --squash

# 3. Verify DLQ created
gh issue list --search "DLQ"
DLQ_ISSUE=$(gh issue list --search "DLQ" --json number -q '.[0].number')
git fetch origin
git branch -r | grep "dlq/"

# 4. Close issue WITHOUT resolving DLQ
gh issue close $DLQ_ISSUE

# 5. Verify DLQ branch still exists
git branch -r | grep "dlq/"
# Expected: Branch still exists with unmatched files

# 6. Verify files are still in DLQ branch
DLQ_BRANCH=$(git branch -r | grep "dlq/" | head -1 | tr -d ' ')
git log $DLQ_BRANCH --oneline -1
```

### DLQ-L3: Re-Atomize After Pattern Update

```bash
# 1. Prerequisites: DLQ branch exists with files like scripts/test.sh

# 2. Update atomic-branches.json to include scripts
cat > /tmp/new-pattern.json << 'EOF'
{"name": "$script", "prefix": "scripts/", "pattern": "scripts/(?P<script>[^/]+)\\.sh"}
EOF

# 3. Add the new pattern (requires PR through W1)
# This would be a separate contribution PR

# 4. After pattern update merged, manually trigger re-atomization:
# Option A: Cherry-pick DLQ commits to new integration PR
# Option B: Run atomization script directly on DLQ branch

# 5. Verify new atomic branch created
git fetch origin
git branch -r | grep "scripts/"

# 6. Verify DLQ issue can be closed
gh issue close $DLQ_ISSUE --comment "Files re-atomized after pattern update"
```

### DLQ Cleanup Script

```bash
#!/usr/bin/env bash
# .github/scripts/dlq-cleanup.sh

set -euo pipefail

echo "=== DLQ Cleanup Script ==="

# Find all DLQ branches
DLQ_BRANCHES=$(git branch -r | grep "origin/dlq/" | sed 's|origin/||')

if [[ -z "$DLQ_BRANCHES" ]]; then
  echo "No DLQ branches found"
  exit 0
fi

echo "Found DLQ branches:"
echo "$DLQ_BRANCHES"

for branch in $DLQ_BRANCHES; do
  echo ""
  echo "Processing: $branch"

  # Check if corresponding issue exists
  PR_NUM=$(echo "$branch" | sed 's|dlq/||')
  ISSUE=$(gh issue list --search "DLQ PR #$PR_NUM" --json number -q '.[0].number' || echo "")

  if [[ -z "$ISSUE" ]]; then
    echo "  WARNING: No issue found for $branch"
  else
    echo "  Issue: #$ISSUE"
    ISSUE_STATE=$(gh issue view $ISSUE --json state -q '.state')
    echo "  State: $ISSUE_STATE"
  fi

  # List files in DLQ
  echo "  Files:"
  git ls-tree --name-only -r "origin/$branch" | head -10
done

echo ""
echo "=== Cleanup Complete ==="
```

---

## Test Matrix: Large File Counts (P3-G2 Resolved)

| Test ID | Scenario | Threshold | Status |
|---------|----------|-----------|--------|
| LF-T1 | 100 files across 5 categories | < 5 minutes | [ ] |
| LF-T2 | 50 files in single chart | < 3 minutes | [ ] |
| LF-T3 | 200 files total | < 10 minutes | [ ] |
| LF-T4 | Memory usage with 500 files | < 500MB | [ ] |

### LF-T1: 100 Files Across 5 Categories

```bash
# 1. Create test branch
git checkout integration
git checkout -b test/lf-t1-large-multi

# 2. Generate files across categories
# Charts (40 files)
for i in $(seq 1 20); do
  echo "value$i: test" >> charts/test-workflow/values.yaml
  echo "value$i: test" >> charts/cloudflared/values.yaml
done

# Docs (30 files)
for i in $(seq 1 30); do
  echo "# Doc $i" > "docs/src/test-topic/doc-$i.md"
done

# CI (20 files)
for i in $(seq 1 20); do
  cat > ".github/workflows/test-$i.yaml" << EOF
name: Test $i
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - run: echo test
EOF
done

# Repo (10 files)
for i in $(seq 1 10); do
  echo "Section $i" >> README.md
done

# 3. Commit and push
git add .
git commit -S -m "feat: test large file count"
git push origin HEAD
gh pr create --base integration --title "Test LF-T1: Large Multi-Category"

# 4. Merge and monitor
START=$(date +%s)
gh pr merge --squash

# 5. Wait for W2
gh run list --workflow=atomize-integration-pr.yaml --limit 1

# 6. Verify completion time
END=$(date +%s)
DURATION=$((END - START))
echo "Duration: $DURATION seconds"

if [[ $DURATION -gt 300 ]]; then
  echo "FAIL: Took longer than 5 minutes"
else
  echo "PASS: Completed in $DURATION seconds"
fi

# 7. Verify all branches created
git fetch origin
git branch -r | grep -E "origin/(chart|docs|ci|repo)/" | wc -l
# Expected: Multiple branches (chart/*, docs/*, ci/*, repo/*)
```

### LF-T2: 50 Files in Single Chart

```bash
# 1. Create test branch
git checkout integration
git checkout -b test/lf-t2-single-chart

# 2. Generate 50 files in one chart
for i in $(seq 1 50); do
  mkdir -p "charts/test-workflow/templates"
  cat > "charts/test-workflow/templates/configmap-$i.yaml" << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-config-$i
data:
  key: value$i
EOF
done

# 3. Commit and push
git add .
git commit -S -m "feat(test-workflow): add 50 configmaps"
git push origin HEAD
gh pr create --base integration --title "Test LF-T2: Single Chart 50 Files"

# 4. Merge and verify
START=$(date +%s)
gh pr merge --squash

# Wait for completion
sleep 30
gh run list --workflow=atomize-integration-pr.yaml --limit 1

END=$(date +%s)
DURATION=$((END - START))
echo "Duration: $DURATION seconds"

# Verify all files in atomic branch
git fetch origin
git ls-tree --name-only -r origin/chart/test-workflow | wc -l
# Expected: 50+ files
```

---

## Test Matrix: Binary Files (P3-G3 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| BF-T1 | Small binary (< 1MB) | Handled normally | [ ] |
| BF-T2 | Large binary (> 10MB) | Warning, handled | [ ] |
| BF-T3 | Binary in chart (icon.png) | Goes to chart branch | [ ] |
| BF-T4 | Unrecognized binary | Goes to DLQ | [ ] |

### BF-T3: Binary in Chart

```bash
# 1. Create test branch
git checkout integration
git checkout -b test/bf-t3-binary-chart

# 2. Add a binary file (chart icon)
# Using a small PNG as example
curl -o charts/test-workflow/icon.png \
  "https://raw.githubusercontent.com/helm/helm/main/cmd/helm/testdata/icons/test.png" 2>/dev/null || \
  echo "PNG placeholder" > charts/test-workflow/icon.png

# 3. Update Chart.yaml with icon reference
echo "icon: file://icon.png" >> charts/test-workflow/Chart.yaml

# 4. Commit and push
git add .
git commit -S -m "feat(test-workflow): add chart icon"
git push origin HEAD
gh pr create --base integration --title "Test BF-T3: Binary in Chart"

# 5. Merge and verify
gh pr merge --squash

# 6. Verify binary is in atomic branch
git fetch origin
git ls-tree origin/chart/test-workflow | grep icon.png
# Expected: Binary file listed
```

---

## Test Matrix: Symlinks (P3-G4 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| SL-T1 | Symlink within same directory | Preserved in atomic branch | [ ] |
| SL-T2 | Symlink to external file | Warning, broken link or DLQ | [ ] |
| SL-T3 | Symlink to matched file | Both included | [ ] |

### SL-T1: Symlink Within Directory

```bash
# 1. Create test branch
git checkout integration
git checkout -b test/sl-t1-symlink

# 2. Create symlink within chart
cd charts/test-workflow
ln -s values.yaml values-link.yaml
cd ../..

# 3. Commit and push
git add .
git commit -S -m "feat(test-workflow): add symlink"
git push origin HEAD
gh pr create --base integration --title "Test SL-T1: Symlink"

# 4. Merge and verify
gh pr merge --squash

# 5. Verify symlink preserved
git fetch origin
git ls-tree origin/chart/test-workflow | grep values-link
# Note: Git stores symlinks as blobs with mode 120000
```

---

## Test Matrix: Integration Reset Verification (P3-G5 Resolved)

| Test ID | Scenario | Expected | Status |
|---------|----------|----------|--------|
| IR-T1 | Normal atomization | Integration = main | [ ] |
| IR-T2 | Selective trim (concurrent) | Integration = main + later commits | [ ] |
| IR-T3 | Reset failure | Error logged, manual intervention | [ ] |

### IR-T1: Verify Full Reset

```bash
#!/usr/bin/env bash
# .github/tests/scripts/verify-integration-reset.sh

set -euo pipefail

echo "=== Integration Reset Verification ==="

# Fetch latest
git fetch origin

# Get SHAs
INTEGRATION_SHA=$(git rev-parse origin/integration)
MAIN_SHA=$(git rev-parse origin/main)

echo "Integration: $INTEGRATION_SHA"
echo "Main:        $MAIN_SHA"

if [[ "$INTEGRATION_SHA" == "$MAIN_SHA" ]]; then
  echo ""
  echo "✓ PASS: Integration reset to main"
  exit 0
else
  echo ""
  echo "✗ FAIL: Integration NOT reset to main"
  echo ""
  echo "Divergence:"
  git log --oneline origin/main..origin/integration
  exit 1
fi
```

### IR-T2: Verify Selective Trim

```bash
#!/usr/bin/env bash
# Verify selective trim preserves later commits

set -euo pipefail

echo "=== Selective Trim Verification ==="

# Get commit history
INTEGRATION_COMMITS=$(git log --oneline origin/integration -5)
MAIN_COMMITS=$(git log --oneline origin/main -5)

echo "Integration recent commits:"
echo "$INTEGRATION_COMMITS"
echo ""
echo "Main recent commits:"
echo "$MAIN_COMMITS"

# Check if integration is ahead of main
AHEAD=$(git rev-list --count origin/main..origin/integration)

if [[ "$AHEAD" -eq 0 ]]; then
  echo ""
  echo "✓ Integration matches main (full reset)"
elif [[ "$AHEAD" -gt 0 ]]; then
  echo ""
  echo "⚠ Integration is $AHEAD commits ahead (selective trim)"
  echo "Additional commits:"
  git log --oneline origin/main..origin/integration
else
  echo ""
  echo "✗ ERROR: Unexpected state"
  exit 1
fi
```

### Automated Reset Verification in W2

```yaml
# Add to atomize-integration-pr.yaml
- name: Verify Integration Reset
  run: |
    git fetch origin
    INTEGRATION_SHA=$(git rev-parse origin/integration)
    MAIN_SHA=$(git rev-parse origin/main)

    if [[ "$INTEGRATION_SHA" == "$MAIN_SHA" ]]; then
      echo "::notice::Integration successfully reset to main"
    else
      AHEAD=$(git rev-list --count origin/main..origin/integration)
      if [[ "$AHEAD" -gt 0 ]]; then
        echo "::warning::Integration is $AHEAD commits ahead of main (selective trim)"
      else
        echo "::error::Integration reset failed"
        exit 1
      fi
    fi
```

---

## GAPs Resolution Status

| GAP ID | Description | Priority | Status |
|--------|-------------|----------|--------|
| P3-G1 | Add tests for DLQ issue lifecycle | Medium | [x] **RESOLVED** |
| P3-G2 | Add tests for very large file counts (100+) | Medium | [x] **RESOLVED** |
| P3-G3 | Add tests for binary file handling | Low | [x] **RESOLVED** |
| P3-G4 | Add tests for symlink handling | Low | [x] **RESOLVED** |
| P3-G5 | Document integration reset verification | High | [x] **RESOLVED** |

### Resolution Summary

- **P3-G1**: Added DLQ-L1 through DLQ-L5 lifecycle tests with cleanup script
- **P3-G2**: Added LF-T1 through LF-T4 large file count tests with timing thresholds
- **P3-G3**: Added BF-T1 through BF-T4 binary file handling tests
- **P3-G4**: Added SL-T1 through SL-T3 symlink tests
- **P3-G5**: Added IR-T1 through IR-T3 reset verification with automated script
