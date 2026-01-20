#!/usr/bin/env bash
# E2E-17: Bypass Integration (Negative Test)
#
# Objective: Verify that PRs cannot bypass the integration branch to reach main.
#
# This test attempts:
#   - Create PR directly to main (bypassing integration)
#   - Verify it cannot merge or is blocked
#
# Expected: PR to main from feature branch is blocked or flagged.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-17"
TEST_NAME="Bypass Integration"
CHART="${E2E_CHART:-test-workflow}"
BRANCH=""

# =============================================================================
# Test Implementation
# =============================================================================

main() {
  setup_test "$TEST_ID" "$TEST_NAME"

  # Step 1: Prerequisites
  log_info "Step 1: Checking prerequisites"
  validate_chart_exists "$CHART"

  # Step 2: Create test branch from main
  log_info "Step 2: Creating test branch from main"
  git fetch origin main --quiet
  git checkout -b "test/e2e-17-bypass-$$" origin/main
  BRANCH="test/e2e-17-bypass-$$"

  # Step 3: Make a change
  log_info "Step 3: Making chart change"
  cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-17: Bypass attempt - this should be blocked
e2e17Bypass:
  enabled: false
  bypassed: true
EOF

  git add .
  git commit -S -m "feat($CHART): bypass integration attempt (E2E-17)" || \
    git commit -m "feat($CHART): bypass integration attempt (E2E-17)"

  # Step 4: Push branch
  log_info "Step 4: Pushing test branch"
  git push origin "$BRANCH"

  # Step 5: Attempt to create PR directly to main
  log_info "Step 5: Attempting PR directly to main"

  local pr_url=""
  local pr_number=""
  local pr_created=false

  if pr_url=$(gh pr create \
    --base main \
    --head "$BRANCH" \
    --title "Test E2E-17: Bypass Integration" \
    --body "This PR attempts to bypass integration - should be blocked" 2>&1); then
    pr_created=true
    pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$' || echo "")
    log_warn "PR created to main: #$pr_number"
    log_warn "Integration bypass was not prevented at PR creation"
  else
    log_info "PR creation to main was blocked or failed"
    log_info "Response: $pr_url"
  fi

  # Step 6: Check if W1 runs differently for main-targeted PRs
  if [[ "$pr_created" == "true" ]] && [[ -n "$pr_number" ]]; then
    log_info "Step 6: Checking workflow behavior for main-targeted PR"
    sleep 10

    # Check for any workflow runs
    local run_id
    run_id=$(gh run list --workflow validate-contribution-pr.yaml \
      --branch "$BRANCH" \
      --json databaseId \
      --jq '.[0].databaseId' 2>/dev/null || echo "")

    if [[ -n "$run_id" ]]; then
      log_info "W1 workflow triggered: $run_id"
      # W1 should only run on PRs to integration
      log_warn "W1 ran on PR to main - check workflow trigger configuration"
    else
      log_info "W1 did not trigger (correct - should only run on PRs to integration)"
    fi

    # Step 7: Check if PR can be merged
    log_info "Step 7: Checking merge eligibility"

    # Check PR mergeable state
    local mergeable
    mergeable=$(gh pr view "$pr_number" --json mergeable -q '.mergeable' 2>/dev/null || echo "UNKNOWN")
    log_info "PR mergeable state: $mergeable"

    # Check required status checks
    local status_checks
    status_checks=$(gh pr checks "$pr_number" 2>/dev/null || echo "")
    log_info "PR checks: $status_checks"

    # Step 8: Verify required checks are failing/missing
    log_info "Step 8: Verifying PR is blocked"

    local is_blocked=false

    # Check if PR state indicates blocking
    if [[ "$mergeable" == "CONFLICTING" ]] || [[ "$mergeable" == "UNKNOWN" ]]; then
      is_blocked=true
      log_info "PR blocked due to merge conflict or unknown state"
    fi

    # Check if required checks are failing
    if echo "$status_checks" | grep -q "fail\|pending"; then
      is_blocked=true
      log_info "PR blocked by failing or pending checks"
    fi

    # Check if PR requires review
    local review_decision
    review_decision=$(gh pr view "$pr_number" --json reviewDecision -q '.reviewDecision' 2>/dev/null || echo "")
    if [[ "$review_decision" == "REVIEW_REQUIRED" ]] || [[ -z "$review_decision" ]]; then
      is_blocked=true
      log_info "PR requires review approval"
    fi

    # Step 9: Attempt merge (should fail)
    log_info "Step 9: Attempting merge (should fail)"

    local merge_result=0
    if gh pr merge "$pr_number" --squash --admin 2>&1 | tee /tmp/e2e-17-merge.log; then
      merge_result=0
      log_error "SECURITY ISSUE: PR merged to main bypassing integration!"
    else
      merge_result=1
      log_info "Merge blocked as expected"
    fi

    # Check merge failure reason
    if grep -q "required status check" /tmp/e2e-17-merge.log 2>/dev/null; then
      log_info "Blocked by required status checks"
    elif grep -q "review" /tmp/e2e-17-merge.log 2>/dev/null; then
      log_info "Blocked by review requirements"
    elif grep -q "permission" /tmp/e2e-17-merge.log 2>/dev/null; then
      log_info "Blocked by permissions"
    fi

    rm -f /tmp/e2e-17-merge.log
  else
    log_info "Step 6-9: Skipped (PR creation blocked)"
  fi

  # Step 10: Cleanup
  log_info "Step 10: Cleanup"

  if [[ -n "$pr_number" ]]; then
    close_pr "$pr_number" "true" || true
  fi

  # Delete remote branch
  git push origin --delete "$BRANCH" 2>/dev/null || true

  # Restore local state
  git checkout origin/integration 2>/dev/null || git checkout main 2>/dev/null || true

  # Step 11: Summary
  log_info "Step 11: Test Summary"

  echo ""
  echo "====== BYPASS INTEGRATION SUMMARY ======"
  echo "PR to main created: $pr_created"
  if [[ "$pr_created" == "true" ]]; then
    echo "PR number: ${pr_number:-unknown}"
    echo "Merge blocked: $(if [[ ${merge_result:-1} -eq 1 ]]; then echo 'YES'; else echo 'NO - SECURITY ISSUE'; fi)"
  else
    echo "PR creation was blocked (good)"
  fi
  echo "========================================"
  echo ""

  # Determine pass/fail
  if [[ "$pr_created" == "false" ]] || [[ ${merge_result:-1} -eq 1 ]]; then
    pass "$TEST_ID"
  else
    fail "$TEST_ID" "Integration bypass was successful - security issue"
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
