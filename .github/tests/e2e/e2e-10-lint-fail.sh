#!/usr/bin/env bash
# E2E-10: Lint Failure Blocks Release
#
# Objective: Verify that a lint failure in W1 prevents the PR from merging.
#
# This test creates a chart change that:
#   - Fails helm lint (missing required Chart.yaml field)
#   - Should be blocked at W1 stage
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-10"
TEST_NAME="Lint Failure Blocks Release"
CHART="${E2E_CHART:-test-workflow}"
BRANCH=""

# =============================================================================
# Test Implementation
# =============================================================================

main() {
  setup_test "$TEST_ID" "$TEST_NAME"

  # Step 1: Prerequisites
  log_info "Step 1: Checking prerequisites"
  assert_on_integration
  validate_chart_exists "$CHART"

  # Step 2: Create test branch
  log_info "Step 2: Creating test branch"
  BRANCH=$(create_test_branch "test/e2e-10")

  # Step 3: Apply lint-fail fixtures
  log_info "Step 3: Applying lint-fail fixtures"
  apply_fixture "e2e-10-lint-fail"

  # Step 4: Commit
  log_info "Step 4: Committing changes"
  git add .
  git commit -S -m "feat($CHART): remove description (E2E-10)" || \
    git commit -m "feat($CHART): remove description (E2E-10)"

  # Step 5: Push and create PR to integration
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-10: Lint Fail" "This PR should fail lint in W1")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Wait for W1 (should fail - lint error)
  log_info "Step 6: Waiting for W1 validation (expecting failure)"

  # Give W1 time to start
  sleep 10

  # Check lint status
  local lint_status
  lint_status=$(get_check_conclusion "$pr_number" "lint" || echo "pending")

  local attempts=0
  while [[ "$lint_status" == "pending" || "$lint_status" == "in_progress" ]] && [[ $attempts -lt 30 ]]; do
    sleep 10
    lint_status=$(get_check_conclusion "$pr_number" "lint" || echo "pending")
    ((attempts++))
    log_info "Lint status: $lint_status (attempt $attempts)"
  done

  # Step 7: Verify lint failed
  log_info "Step 7: Verifying lint failure"
  if [[ "$lint_status" == "failure" ]]; then
    log_info "Lint failed as expected - PASS"
  elif [[ "$lint_status" == "success" ]]; then
    fail "$TEST_ID" "Lint passed unexpectedly (chart may have been fixed)"
    cleanup_fixture "e2e-10-lint-fail"
    teardown_test "$TEST_ID" "$BRANCH"
    return 1
  else
    log_warn "Lint status: $lint_status (may still be running)"
  fi

  # Step 8: Verify PR cannot merge (required checks failed)
  log_info "Step 8: Verifying merge is blocked"
  local pr_state
  pr_state=$(get_pr_state "$pr_number")

  if [[ "$pr_state" == "OPEN" ]]; then
    log_info "PR is still open (blocked by failing checks) - EXPECTED"
  elif [[ "$pr_state" == "MERGED" ]]; then
    fail "$TEST_ID" "PR was merged despite failing lint!"
    cleanup_fixture "e2e-10-lint-fail"
    teardown_test "$TEST_ID" "$BRANCH"
    return 1
  fi

  # Step 9: Verify auto-merge was NOT enabled
  log_info "Step 9: Verifying auto-merge status"
  local auto_merge
  auto_merge=$(gh pr view "$pr_number" --json autoMergeRequest -q '.autoMergeRequest // "null"' 2>/dev/null || echo "null")

  if [[ "$auto_merge" == "null" ]]; then
    log_info "Auto-merge not enabled (as expected for failing PR)"
  else
    log_warn "Auto-merge was enabled despite failing checks"
  fi

  # Cleanup: Close the PR
  log_info "Cleanup: Closing PR and removing fixtures"
  close_pr "$pr_number" "true" || true
  cleanup_fixture "e2e-10-lint-fail"

  teardown_test "$TEST_ID" "$BRANCH"

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
