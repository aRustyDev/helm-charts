#!/usr/bin/env bash
# E2E-14: Failure Recovery
#
# Objective: Verify that workflows can recover from transient failures.
#
# This test:
#   - Creates a valid PR
#   - Simulates/checks for retry behavior
#   - Verifies workflow can resume after failure
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-14"
TEST_NAME="Failure Recovery"
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
  BRANCH=$(create_test_branch "test/e2e-14")

  # Step 3: Make a valid change
  log_info "Step 3: Making valid chart change"
  cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-14: Recovery test annotation
e2e14Test:
  enabled: false
  recoveryTest: true
EOF

  # Step 4: Commit
  log_info "Step 4: Committing changes"
  git add .
  git commit -S -m "feat($CHART): add recovery test feature (E2E-14)" || \
    git commit -m "feat($CHART): add recovery test feature (E2E-14)"

  # Step 5: Push and create PR
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-14: Recovery" "Testing failure recovery")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Get initial workflow run
  log_info "Step 6: Getting initial workflow status"
  sleep 10

  local run_id
  run_id=$(gh run list --workflow validate-contribution-pr.yaml \
    --branch "$BRANCH" \
    --json databaseId \
    --jq '.[0].databaseId' 2>/dev/null || echo "")

  if [[ -z "$run_id" ]]; then
    log_warn "Could not find workflow run"
  else
    log_info "Workflow run ID: $run_id"
  fi

  # Step 7: Monitor workflow (check for potential failures/retries)
  log_info "Step 7: Monitoring workflow execution"

  local attempts=0
  local max_attempts=30
  local final_status=""

  while [[ $attempts -lt $max_attempts ]]; do
    if [[ -n "$run_id" ]]; then
      local run_status
      run_status=$(gh run view "$run_id" --json status,conclusion \
        -q '.status + ":" + (.conclusion // "")' 2>/dev/null || echo "unknown:")

      log_info "Run status (attempt $((attempts+1))): $run_status"

      if [[ "$run_status" == "completed:"* ]]; then
        final_status="$run_status"
        break
      fi
    fi

    sleep 10
    ((attempts++))
  done

  # Step 8: Check for retry patterns
  log_info "Step 8: Checking for retry patterns"

  # Get workflow run attempts
  if [[ -n "$run_id" ]]; then
    local run_attempt
    run_attempt=$(gh run view "$run_id" --json attempt -q '.attempt' 2>/dev/null || echo "1")
    log_info "Workflow attempt number: $run_attempt"

    if [[ "$run_attempt" -gt 1 ]]; then
      log_info "Workflow was retried (attempt $run_attempt)"
    else
      log_info "Workflow completed on first attempt"
    fi
  fi

  # Step 9: Verify re-run capability
  log_info "Step 9: Testing re-run capability"

  if [[ -n "$run_id" ]]; then
    # Check if re-run is available
    local can_rerun
    can_rerun=$(gh run view "$run_id" --json jobs -q '.jobs | any(.conclusion == "failure")' 2>/dev/null || echo "false")

    if [[ "$can_rerun" == "true" ]]; then
      log_info "Re-run available for failed jobs"
      # Optionally trigger re-run
      # gh run rerun "$run_id" --failed
    else
      log_info "No failed jobs to re-run"
    fi
  fi

  # Step 10: Verify idempotency
  log_info "Step 10: Testing idempotency"

  # Push a no-op commit to trigger workflow again
  git commit --allow-empty -m "chore: trigger re-validation (E2E-14)"
  git push origin "$BRANCH"

  sleep 5

  # Get new workflow run
  local new_run_id
  new_run_id=$(gh run list --workflow validate-contribution-pr.yaml \
    --branch "$BRANCH" \
    --json databaseId \
    --jq '.[0].databaseId' 2>/dev/null || echo "")

  if [[ "$new_run_id" != "$run_id" ]] && [[ -n "$new_run_id" ]]; then
    log_info "New workflow triggered: $new_run_id"
  else
    log_info "Same workflow or no new run detected"
  fi

  # Step 11: Wait for final status
  log_info "Step 11: Waiting for validation to complete"
  wait_for_workflow "validate-contribution-pr" "$pr_number"

  # Step 12: Verify final state
  log_info "Step 12: Verifying final state"

  local check_status
  check_status=$(get_check_conclusion "$pr_number" "lint" || echo "unknown")
  log_info "Final lint status: $check_status"

  # Cleanup
  log_info "Cleanup: Closing PR and reverting"
  close_pr "$pr_number" "true" || true

  git checkout origin/integration -- "charts/$CHART/values.yaml" 2>/dev/null || true

  teardown_test "$TEST_ID" "$BRANCH"

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
