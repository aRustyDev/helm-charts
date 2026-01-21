# Phase 7: Live E2E Execution Guide

## Overview

This phase covers executing E2E tests LIVE against the actual GitHub repository. Unlike unit tests that mock dependencies, these tests exercise the real CI/CD pipeline.

| Attribute | Value |
|-----------|-------|
| **Dependencies** | Phases 1-6 complete, workflows deployed, test infrastructure ready |
| **Time Estimate** | 4-8 hours for full suite |
| **Infrastructure** | Full GitHub repository with all workflows active |
| **Risk Level** | Medium - modifies real repository state |

---

## Prerequisites Checklist

### P7-PREREQ-1: Test Chart Must Exist

```bash
# Verify test-workflow chart exists
ls -la charts/test-workflow/Chart.yaml

# If missing, create minimal chart:
mkdir -p charts/test-workflow/templates

cat > charts/test-workflow/Chart.yaml << 'EOF'
apiVersion: v2
name: test-workflow
description: Test chart for workflow validation (E2E testing only)
type: application
version: 0.1.0
appVersion: "1.0.0"
maintainers:
  - name: aRustyDev
    url: https://github.com/aRustyDev
EOF

cat > charts/test-workflow/values.yaml << 'EOF'
# Default values for test-workflow
replicaCount: 1
EOF

cat > charts/test-workflow/templates/configmap.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "test-workflow.fullname" . }}
data:
  test: "value"
EOF

cat > charts/test-workflow/templates/_helpers.tpl << 'EOF'
{{- define "test-workflow.fullname" -}}
{{- .Release.Name }}-{{ .Chart.Name }}
{{- end }}
EOF
```

### P7-PREREQ-2: Verify CODEOWNERS Membership

```bash
# Check current user
CURRENT_USER=$(gh api user --jq '.login')
echo "Current user: $CURRENT_USER"

# Check CODEOWNERS
cat .github/CODEOWNERS

# Verify membership
if grep -q "@$CURRENT_USER" .github/CODEOWNERS; then
  echo "PASS: User is in CODEOWNERS"
else
  echo "FAIL: Add @$CURRENT_USER to CODEOWNERS first"
fi
```

### P7-PREREQ-3: Verify Branch Protections

```bash
# Check integration branch rules
gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name | contains("integration")) | {name, enforcement}'

# Check main branch rules
gh api repos/{owner}/{repo}/rulesets --jq '.[] | select(.name | contains("main")) | {name, enforcement}'

# Verify merge queue is enabled
gh api repos/{owner}/{repo}/rulesets --jq '.[] | .rules[] | select(.type == "merge_queue")'
```

### P7-PREREQ-4: Verify Active Workflows

```bash
# List all workflows
gh workflow list

# Verify critical workflows exist and are enabled
for wf in validate-contribution-pr atomize-integration-pr validate-atomic-chart-pr release-atomic-chart; do
  STATUS=$(gh workflow list --json name,state --jq ".[] | select(.name | ascii_downcase | contains(\"${wf//-/ }\")) | .state" | head -1)
  echo "$wf: ${STATUS:-NOT FOUND}"
done
```

### P7-PREREQ-5: Verify GPG Signing

```bash
# Check GPG configuration
git config --get user.signingkey

# Test signing
echo "test" | gpg --clearsign > /dev/null 2>&1 && echo "GPG signing works" || echo "GPG not configured"

# Alternative: Use SSH signing
git config --get gpg.format
```

---

## Pre-Execution Checklist

Before running ANY live E2E test:

- [ ] On `integration` branch with clean working tree
- [ ] Current user is in CODEOWNERS
- [ ] GPG/SSH signing is configured
- [ ] Test chart exists (or will be created by fixture)
- [ ] No pending PRs that could conflict
- [ ] GitHub CLI authenticated (`gh auth status`)
- [ ] Sufficient time to monitor (30-60 min per E2E)

---

## E2E Test Execution Order

### Critical Path (Must Run in Order)

```
E2E-1 (Happy Path) ─────────────────────────────────────────────────
  │
  │  Creates test release, establishes baseline
  │
  ├── E2E-12 (Verify Failure) ─── Requires E2E-1 release
  │
  └── E2E-13 (Lineage Trace) ──── Requires E2E-1 release
```

### Independent Tests (Can Run After E2E-1)

```
┌──────────────┬──────────────┬──────────────┐
│   E2E-2      │   E2E-3      │   E2E-4      │
│  Untrusted   │  Unsigned    │  Multi-type  │
│   30 min     │   20 min     │   45 min     │
└──────────────┴──────────────┴──────────────┘
       │              │              │
       └──────────────┴──────────────┘
                      │
┌──────────────┬──────────────┬──────────────┐
│   E2E-6      │   E2E-7      │   E2E-9      │
│    DLQ       │ Multi-chart  │  K8s Fail    │
│   30 min     │   60 min     │   25 min     │
└──────────────┴──────────────┴──────────────┘
```

### Negative Tests (Run Last)

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│   E2E-16     │   E2E-17     │   E2E-19     │   E2E-20     │
│ Direct Push  │   Bypass     │ Idempotent   │ Bad Commit   │
│   10 min     │   15 min     │   15 min     │   15 min     │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

---

## Live E2E-1: Happy Path Execution

### Step 1: Setup (5 min)

```bash
# Navigate to repo root
cd /path/to/helm-charts

# Ensure on integration
git checkout integration
git pull origin integration

# Verify clean state
git status
# Should show: "nothing to commit, working tree clean"

# Set test variables
export E2E_CHART="test-workflow"
export E2E_REPO="aRustyDev/helm-charts"
```

### Step 2: Create Test Branch (2 min)

```bash
BRANCH="test/e2e-1-$(date +%Y%m%d-%H%M%S)"
git checkout -b "$BRANCH"
echo "Created branch: $BRANCH"
```

### Step 3: Apply Fixture (5 min)

```bash
# Run fixture script
bash .github/tests/e2e/fixtures/e2e-1-happy-path/create.sh

# Verify changes
git status
git diff --stat
```

### Step 4: Commit with Signature (2 min)

```bash
git add .

# Commit with signature
git commit -S -m "feat($E2E_CHART): E2E-1 happy path test feature

This commit adds a test feature for E2E validation.

Ref: Live E2E-1 test execution"

# Verify signature
git log --show-signature -1
```

### Step 5: Push and Create PR (5 min)

```bash
# Push branch
git push origin "$BRANCH"

# Create PR
PR_URL=$(gh pr create \
  --base integration \
  --title "Test E2E-1: Happy Path Validation" \
  --body "## E2E-1: Happy Path Test

This PR validates the complete workflow pipeline:
- W1: Contribution validation
- Auto-merge via merge queue
- W2: Atomization
- W5: Atomic PR validation
- W6: Release

**DO NOT MERGE MANUALLY** - Auto-merge should be enabled.

---
_Automated E2E test - will be cleaned up after completion_")

PR_NUMBER=$(echo "$PR_URL" | grep -oE '[0-9]+$')
echo "Created PR #$PR_NUMBER: $PR_URL"
```

### Step 6: Monitor W1 Validation (5-10 min)

```bash
echo "Monitoring W1 validation for PR #$PR_NUMBER..."

# Watch workflow status
watch -n 10 "gh pr checks $PR_NUMBER 2>/dev/null | head -20"

# Or poll manually
while true; do
  STATUS=$(gh pr checks $PR_NUMBER --json state --jq 'map(.state) | unique | join(",")')
  echo "[$(date +%H:%M:%S)] Checks: $STATUS"

  if [[ "$STATUS" == *"COMPLETED"* ]] || [[ "$STATUS" == *"SUCCESS"* ]]; then
    break
  fi

  sleep 30
done
```

### Step 7: Verify Auto-Merge Enabled (5 min)

```bash
# Check if auto-merge was enabled
AUTO_MERGE=$(gh pr view $PR_NUMBER --json autoMergeRequest --jq '.autoMergeRequest != null')

if [[ "$AUTO_MERGE" == "true" ]]; then
  echo "PASS: Auto-merge enabled"
else
  echo "WARNING: Auto-merge NOT enabled - check trust validation"
  gh pr view $PR_NUMBER --json statusCheckRollup --jq '.statusCheckRollup[] | "\(.name): \(.conclusion)"'
fi
```

### Step 8: Wait for Merge Queue (5-10 min)

```bash
echo "Waiting for PR to merge via merge queue..."

while true; do
  STATE=$(gh pr view $PR_NUMBER --json state --jq '.state')
  echo "[$(date +%H:%M:%S)] PR state: $STATE"

  if [[ "$STATE" == "MERGED" ]]; then
    echo "PASS: PR merged to integration"
    break
  elif [[ "$STATE" == "CLOSED" ]]; then
    echo "FAIL: PR was closed without merge"
    exit 1
  fi

  sleep 30
done
```

### Step 9: Wait for W2 Atomization (10 min)

```bash
echo "Waiting for W2 atomization..."
sleep 10  # Give W2 time to trigger

# Find the atomization run
W2_RUN=$(gh run list --workflow=atomize-integration-pr.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
echo "W2 Run ID: $W2_RUN"

# Wait for completion
gh run watch $W2_RUN

# Verify atomic branch created
git fetch origin --prune
ATOMIC_BRANCH=$(git branch -r | grep "origin/chart/$E2E_CHART" | head -1 | tr -d ' ')

if [[ -n "$ATOMIC_BRANCH" ]]; then
  echo "PASS: Atomic branch created: $ATOMIC_BRANCH"
else
  echo "FAIL: Atomic branch not found"
  exit 1
fi
```

### Step 10: Find and Monitor Atomic PR (5 min)

```bash
# Find atomic PR
ATOMIC_PR=$(gh pr list --base main --head "chart/$E2E_CHART" --json number --jq '.[0].number')

if [[ -z "$ATOMIC_PR" ]]; then
  echo "FAIL: Atomic PR not found"
  exit 1
fi

echo "Found atomic PR #$ATOMIC_PR"

# Wait for W5 validation
echo "Monitoring W5 validation..."
while true; do
  STATUS=$(gh pr checks $ATOMIC_PR --json state --jq 'map(.state) | unique | join(",")')
  echo "[$(date +%H:%M:%S)] W5 Checks: $STATUS"

  if [[ "$STATUS" != *"IN_PROGRESS"* ]] && [[ "$STATUS" != *"QUEUED"* ]]; then
    break
  fi

  sleep 30
done

# Verify all checks passed
FAILED=$(gh pr checks $ATOMIC_PR --json conclusion --jq '[.[] | select(.conclusion == "FAILURE")] | length')
if [[ "$FAILED" -gt 0 ]]; then
  echo "FAIL: W5 checks failed"
  gh pr checks $ATOMIC_PR
  exit 1
fi

echo "PASS: W5 validation complete"
```

### Step 11: Merge Atomic PR (5 min)

```bash
echo "Merging atomic PR #$ATOMIC_PR to main..."

# Merge with admin bypass if needed for review requirements
gh pr merge $ATOMIC_PR --squash --admin

# Verify merge
MERGE_STATE=$(gh pr view $ATOMIC_PR --json state --jq '.state')
if [[ "$MERGE_STATE" == "MERGED" ]]; then
  echo "PASS: Atomic PR merged to main"
else
  echo "FAIL: Merge failed"
  exit 1
fi
```

### Step 12: Wait for Release (10 min)

```bash
echo "Waiting for release workflow..."
sleep 10  # Give release time to trigger

# Find release run
RELEASE_RUN=$(gh run list --workflow=release-atomic-chart.yaml --limit 1 --json databaseId --jq '.[0].databaseId')
echo "Release Run ID: $RELEASE_RUN"

# Wait for completion
gh run watch $RELEASE_RUN

# Verify release created
RELEASE_TAG=$(gh release list --limit 1 --json tagName --jq '.[0].tagName')
echo "Latest release: $RELEASE_TAG"

if [[ "$RELEASE_TAG" == *"$E2E_CHART"* ]]; then
  echo "PASS: Release created for $E2E_CHART"
else
  echo "WARNING: Release tag doesn't match expected chart"
fi
```

### Step 13: Verify Attestation (5 min)

```bash
echo "Verifying attestation..."

# Download release asset
PACKAGE=$(gh release view "$RELEASE_TAG" --json assets --jq '.assets[].name' | grep ".tgz" | head -1)
gh release download "$RELEASE_TAG" --pattern "$PACKAGE" --dir /tmp/e2e-1

# Verify attestation
if gh attestation verify "/tmp/e2e-1/$PACKAGE" --repo $E2E_REPO; then
  echo "PASS: Attestation verified"
else
  echo "FAIL: Attestation verification failed"
fi

# Cleanup
rm -rf /tmp/e2e-1
```

### Step 14: Verify Integration Reset (2 min)

```bash
echo "Verifying integration branch reset..."

git fetch origin
INTEGRATION_SHA=$(git rev-parse origin/integration)
MAIN_SHA=$(git rev-parse origin/main)

if [[ "$INTEGRATION_SHA" == "$MAIN_SHA" ]]; then
  echo "PASS: Integration reset to main"
else
  AHEAD=$(git rev-list --count origin/main..origin/integration)
  echo "WARNING: Integration is $AHEAD commits ahead of main"
fi
```

### Step 15: Cleanup (5 min)

```bash
echo "Cleaning up..."

# Delete test branch (should be auto-deleted, but verify)
git push origin --delete "$BRANCH" 2>/dev/null || echo "Branch already deleted"

# Return to integration
git checkout integration
git pull origin integration

# Run fixture cleanup
bash .github/tests/e2e/fixtures/e2e-1-happy-path/cleanup.sh

echo ""
echo "=========================================="
echo "E2E-1 COMPLETE"
echo "=========================================="
echo "PR: #$PR_NUMBER"
echo "Atomic PR: #$ATOMIC_PR"
echo "Release: $RELEASE_TAG"
echo "=========================================="
```

---

## Rollback Procedures

### If E2E-1 Fails at W1 (Before Merge)

```bash
# Close PR without merge
gh pr close $PR_NUMBER --delete-branch

# Return to integration
git checkout integration
```

### If E2E-1 Fails at W2 (After Merge to Integration)

```bash
# Check for orphan atomic branches
git branch -r | grep "chart/$E2E_CHART"

# Delete orphan branches
git push origin --delete "chart/$E2E_CHART"

# Close any orphan PRs
gh pr list --head "chart/$E2E_CHART" --json number --jq '.[].number' | xargs -I {} gh pr close {}

# Verify integration state
git fetch origin
git log origin/integration --oneline -5
```

### If E2E-1 Fails at Release (After Merge to Main)

```bash
# Check for incomplete release artifacts
gh release list | head -5

# If tag exists but no release:
TAG="$E2E_CHART-v*"
EXISTING_TAG=$(git tag -l "$TAG" | tail -1)

if [[ -n "$EXISTING_TAG" ]]; then
  # Verify if release exists
  if gh release view "$EXISTING_TAG" &>/dev/null; then
    echo "Release exists - may be incomplete"
    gh release view "$EXISTING_TAG"
  else
    echo "Tag exists but no release - consider deleting tag"
    # git push origin --delete "$EXISTING_TAG"
  fi
fi
```

### Full E2E Cleanup Script

```bash
#!/usr/bin/env bash
# .github/tests/e2e/cleanup-e2e.sh

set -euo pipefail

E2E_CHART="${E2E_CHART:-test-workflow}"

echo "=== Full E2E Cleanup ==="

# 1. Close any open PRs from test branches
echo "Closing test PRs..."
gh pr list --search "Test E2E" --state open --json number --jq '.[].number' | \
  xargs -I {} gh pr close {} --delete-branch 2>/dev/null || true

# 2. Delete test branches
echo "Deleting test branches..."
git fetch origin --prune
for branch in $(git branch -r | grep "origin/test/e2e-" | sed 's|origin/||'); do
  git push origin --delete "$branch" 2>/dev/null || true
done

# 3. Delete atomic branches (chart/test-workflow)
echo "Deleting atomic test branches..."
git push origin --delete "chart/$E2E_CHART" 2>/dev/null || true

# 4. Delete DLQ branches
echo "Deleting DLQ branches..."
for branch in $(git branch -r | grep "origin/dlq/" | sed 's|origin/||'); do
  git push origin --delete "$branch" 2>/dev/null || true
done

# 5. Run fixture cleanup
echo "Running fixture cleanup..."
bash .github/tests/e2e/fixtures/cleanup-all.sh 2>/dev/null || true

echo ""
echo "=== Cleanup Complete ==="
```

---

## Safety Guidelines

### DO NOT Run These Tests On:

1. **Production charts** - Only use `test-workflow` or dedicated test chart
2. **Shared branches** - Don't modify branches others are using
3. **During active development** - Coordinate with team first
4. **Without monitoring** - Always watch workflow execution

### Safe Test Isolation

```bash
# Always verify you're using test chart
if [[ "$E2E_CHART" != "test-workflow" ]]; then
  echo "WARNING: Using non-test chart: $E2E_CHART"
  read -p "Continue? (y/N) " confirm
  [[ "$confirm" == "y" ]] || exit 1
fi
```

### Emergency Abort

```bash
# If something goes wrong, abort all running workflows
gh run list --workflow=atomize-integration-pr.yaml --status in_progress --json databaseId --jq '.[].databaseId' | \
  xargs -I {} gh run cancel {}

gh run list --workflow=validate-atomic-chart-pr.yaml --status in_progress --json databaseId --jq '.[].databaseId' | \
  xargs -I {} gh run cancel {}

gh run list --workflow=release-atomic-chart.yaml --status in_progress --json databaseId --jq '.[].databaseId' | \
  xargs -I {} gh run cancel {}
```

---

## Gaps Identified

| Gap ID | Description | Priority | Status |
|--------|-------------|----------|--------|
| GAP-L1 | No test chart in repo | Critical | [ ] |
| GAP-L2 | W2 workflow consolidation unclear | High | [ ] |
| GAP-L3 | Merge queue configuration not verified | High | [ ] |
| GAP-L4 | CODEOWNERS verification needed | Medium | [ ] |
| GAP-L5 | No mock mode for negative tests | Medium | [ ] |
| GAP-L6 | No live execution runbook | High | [x] THIS DOC |
| GAP-L7 | No rollback procedures | High | [x] THIS DOC |
| GAP-L8 | Attestation requires real release | Medium | [x] DOCUMENTED |
| GAP-L9 | W4 not standalone | Low | [ ] BY DESIGN |
| GAP-L10 | No CI for E2E tests | Low | [ ] OPTIONAL |

---

## Next Steps

### Before Running Live E2E

1. [ ] Create `charts/test-workflow/` test chart
2. [ ] Verify `atomize-integration-pr.yaml` is the active W2 workflow
3. [ ] Verify merge queue is enabled on integration branch
4. [ ] Verify current user is in CODEOWNERS
5. [ ] Configure GPG/SSH signing if not already done
6. [ ] Run BATS unit tests: `bats .github/tests/e2e/lib/common.bats`

### Recommended Execution Order

1. **E2E-1**: Happy path (establishes baseline)
2. **E2E-20**: Bad commit (quick negative test)
3. **E2E-3**: Unsigned commit
4. **E2E-2**: Untrusted contributor (requires fork or secondary account)
5. **E2E-9**: K8s test failure
6. **E2E-10**: Lint failure
7. **E2E-12**: Attestation verification (requires E2E-1)
8. **E2E-13**: Lineage trace (requires E2E-1)

---

## Completion Criteria

E2E testing is considered complete when:

- [ ] E2E-1 passes end-to-end with all verifications
- [ ] At least 3 negative tests pass (E2E-16, E2E-17, E2E-20)
- [ ] Attestation verification works (E2E-12)
- [ ] Lineage trace complete (E2E-13)
- [ ] All cleanup procedures executed successfully
- [ ] No orphan branches, PRs, or incomplete releases remain
