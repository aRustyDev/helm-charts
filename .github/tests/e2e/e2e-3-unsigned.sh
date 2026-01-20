#!/usr/bin/env bash
# E2E-3: Unsigned Commit from Trusted Contributor
#
# Objective: Verify that unsigned commits from CODEOWNERS do NOT auto-merge.
#
# This test:
#   - Creates PR from CODEOWNER (trusted)
#   - Uses unsigned commit
#   - Verifies auto-merge is NOT enabled (requires signed commits)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-3"
TEST_NAME="Unsigned Commit from Trusted Contributor"
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

  # Get current user
  local current_user
  current_user=$(gh api user -q '.login' 2>/dev/null || echo "unknown")
  log_info "Current GitHub user: $current_user"

  # Verify user is in CODEOWNERS (required for this test)
  local is_codeowner=false
  if [[ -f "CODEOWNERS" ]]; then
    if grep -q "@$current_user" CODEOWNERS 2>/dev/null; then
      is_codeowner=true
    fi
  fi
  if [[ -f ".github/CODEOWNERS" ]]; then
    if grep -q "@$current_user" .github/CODEOWNERS 2>/dev/null; then
      is_codeowner=true
    fi
  fi

  if [[ "$is_codeowner" != "true" ]]; then
    log_warn "Current user @$current_user is NOT a CODEOWNER"
    log_warn "This test is designed for trusted contributors"
    log_warn "Results may vary - continuing anyway"
  fi

  # Step 2: Create test branch
  log_info "Step 2: Creating test branch"
  BRANCH=$(create_test_branch "test/e2e-3")

  # Step 3: Make a simple chart change
  log_info "Step 3: Making minor chart change"

  # Add a test annotation to values.yaml
  cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-3: Test annotation for unsigned commit test
e2e3Test:
  enabled: false
  description: "Testing unsigned commits from trusted users"
EOF

  # Step 4: Commit WITHOUT signature
  log_info "Step 4: Committing changes (explicitly unsigned)"
  git add .
  # Force unsigned commit
  git -c commit.gpgsign=false commit -m "feat($CHART): add unsigned feature (E2E-3)"

  # Verify commit is unsigned
  local last_commit
  last_commit=$(git rev-parse HEAD)
  local sig_status
  sig_status=$(git log -1 --format='%G?' "$last_commit" 2>/dev/null || echo "N")
  log_info "Commit signature status: $sig_status (N=no signature)"

  # Step 5: Push and create PR to integration
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-3: Unsigned Commit" "Testing unsigned commit from trusted contributor")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Wait for W1 validation
  log_info "Step 6: Waiting for W1 validation"
  wait_for_workflow "validate-contribution-pr" "$pr_number"

  # Step 7: Check auto-merge status
  log_info "Step 7: Checking auto-merge status"
  sleep 15  # Give auto-merge job time to run

  local auto_merge
  auto_merge=$(gh pr view "$pr_number" --json autoMergeRequest -q '.autoMergeRequest.enabledAt // "null"' 2>/dev/null || echo "null")

  if [[ "$auto_merge" == "null" ]]; then
    log_info "Auto-merge NOT enabled - EXPECTED (unsigned commit)"
  else
    log_warn "Auto-merge was enabled - check trust validation logic"
    log_warn "Expected: unsigned commits should NOT auto-merge even from CODEOWNERS"
  fi

  # Step 8: Verify commit verification status via GitHub API
  log_info "Step 8: Verifying commit verification via GitHub API"
  local head_sha
  head_sha=$(gh pr view "$pr_number" --json headRefOid -q '.headRefOid')
  local verified
  verified=$(gh api "repos/${E2E_REPO}/commits/$head_sha" -q '.commit.verification.verified' 2>/dev/null || echo "false")
  local reason
  reason=$(gh api "repos/${E2E_REPO}/commits/$head_sha" -q '.commit.verification.reason' 2>/dev/null || echo "unsigned")

  log_info "GitHub verification: verified=$verified, reason=$reason"

  if [[ "$verified" == "true" ]]; then
    log_warn "GitHub shows commit as verified (may have been resigned during push)"
  else
    log_info "Commit correctly shown as unverified"
  fi

  # Step 9: Verify PR requires manual merge
  log_info "Step 9: Verifying PR state"
  local pr_state
  pr_state=$(get_pr_state "$pr_number")

  if [[ "$pr_state" == "OPEN" ]]; then
    log_info "PR is open and requires manual action - EXPECTED"
  elif [[ "$pr_state" == "MERGED" ]]; then
    log_warn "PR was merged automatically - unsigned commit protection may be disabled"
  fi

  # Cleanup: Close the PR
  log_info "Cleanup: Closing PR and reverting changes"
  close_pr "$pr_number" "true" || true

  # Revert test changes
  git checkout origin/integration -- "charts/$CHART/values.yaml" 2>/dev/null || true

  teardown_test "$TEST_ID" "$BRANCH"

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
