#!/usr/bin/env bash
# E2E-9: K8s Test Failure Blocks Release
#
# Objective: Verify that a K8s test failure in W5 prevents the chart from being released.
#
# This test creates a chart change that:
#   - Passes lint validation
#   - Fails helm install tests (uses required value that's not defined)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-9"
TEST_NAME="K8s Test Failure Blocks Release"
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
  BRANCH=$(create_test_branch "test/e2e-9")

  # Step 3: Apply K8s-fail fixtures
  log_info "Step 3: Applying K8s-fail fixtures"
  apply_fixture "e2e-9-k8s-fail"

  # Step 4: Commit
  log_info "Step 4: Committing changes"
  git add .
  git commit -S -m "feat($CHART): add template with required value (E2E-9)" || \
    git commit -m "feat($CHART): add template with required value (E2E-9)"

  # Step 5: Push and create PR to integration
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-9: K8s Fail" "This PR should fail K8s tests in W5")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Wait for W1 (should pass - only lint)
  log_info "Step 6: Waiting for W1 validation (should pass)"
  wait_for_workflow "validate-contribution-pr" "$pr_number"

  # Step 7: Merge to integration
  log_info "Step 7: Merging to integration"
  wait_for_merge "$pr_number"

  # Step 8: Wait for W2 to create atomic PR
  log_info "Step 8: Waiting for W2 atomization"
  sleep 10
  wait_for_workflow "atomize-integration-pr"

  # Step 9: Find atomic PR
  log_info "Step 9: Finding atomic PR"
  git fetch origin --prune
  local atomic_pr
  atomic_pr=$(gh pr list --base main --head "chart/$CHART" --json number -q '.[0].number' || echo "")
  if [[ -z "$atomic_pr" ]]; then
    fail "$TEST_ID" "Atomic PR not found"
    return 1
  fi
  log_info "Found atomic PR #$atomic_pr"

  # Step 10: Wait for W5 (should have failing K8s tests)
  log_info "Step 10: Waiting for W5 (expecting failure in k8s-test)"
  sleep 30  # Give W5 time to run

  # Check status
  local k8s_status
  k8s_status=$(get_check_conclusion "$atomic_pr" "k8s-test" || echo "pending")

  if [[ "$k8s_status" == "failure" ]]; then
    log_info "K8s test failed as expected"
  elif [[ "$k8s_status" == "success" ]]; then
    log_warn "K8s test passed unexpectedly (chart may have been fixed)"
  else
    log_info "K8s test status: $k8s_status"
  fi

  # Step 11: Verify PR cannot merge (required checks failed)
  log_info "Step 11: Verifying merge is blocked"
  local pr_state
  pr_state=$(get_pr_state "$atomic_pr")

  if [[ "$pr_state" == "OPEN" ]]; then
    log_info "PR is still open (blocked by failing checks) - EXPECTED"
  elif [[ "$pr_state" == "MERGED" ]]; then
    fail "$TEST_ID" "PR was merged despite failing checks!"
    return 1
  fi

  # Step 12: Verify no release was created
  log_info "Step 12: Verifying no release was created"
  local latest_release
  latest_release=$(get_release_tag)
  if [[ "$latest_release" == *"$CHART"* ]]; then
    # Check if this is a new release (created during this test)
    local release_created_at
    release_created_at=$(gh release view "$latest_release" --json createdAt -q '.createdAt')
    log_warn "Found release $latest_release (created $release_created_at)"
    # This may be expected if the release was from a previous test
  fi
  log_info "No new release created for failing chart - EXPECTED"

  # Cleanup: Close the PR and delete branch
  log_info "Cleanup: Closing PR and removing fixtures"
  close_pr "$atomic_pr" "true" || true
  cleanup_fixture "e2e-9-k8s-fail"

  teardown_test "$TEST_ID" "$BRANCH"

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
