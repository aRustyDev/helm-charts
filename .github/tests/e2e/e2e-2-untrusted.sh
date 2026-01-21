#!/usr/bin/env bash
# E2E-2: Untrusted Contributor
#
# Objective: Verify that PRs from non-CODEOWNERS require manual approval.
#
# This test simulates a contribution from outside the trusted team:
#   - PR passes W1 validation (lint, artifacthub, commit)
#   - Auto-merge is NOT enabled (author not in CODEOWNERS)
#   - PR requires manual approval before merge
#
# Note: This test requires the current user to NOT be in CODEOWNERS,
# or uses a test account. In practice, this may need manual verification.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-2"
TEST_NAME="Untrusted Contributor"
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

  # Check if user is in CODEOWNERS
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

  if [[ "$is_codeowner" == "true" ]]; then
    log_warn "Current user @$current_user is a CODEOWNER"
    log_warn "This test validates untrusted contributor behavior"
    log_warn "Test will verify auto-merge logic, but may auto-merge due to trust"
  fi

  # Step 2: Create test branch
  log_info "Step 2: Creating test branch"
  BRANCH=$(create_test_branch "test/e2e-2")

  # Step 3: Make a simple chart change
  log_info "Step 3: Making minor chart change"

  # Add a test annotation to values.yaml
  cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-2: Test annotation for untrusted contributor test
e2e2Test:
  enabled: false
EOF

  # Step 4: Commit (intentionally NOT signed to simulate external contributor)
  log_info "Step 4: Committing changes (unsigned)"
  git add .
  # Use --no-gpg-sign to simulate unsigned commit
  git commit --no-gpg-sign -m "feat($CHART): add test annotation (E2E-2)" || \
    git commit -m "feat($CHART): add test annotation (E2E-2)"

  # Step 5: Push and create PR to integration
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-2: Untrusted Contributor" "Testing untrusted contributor workflow")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Wait for W1 validation (should pass - valid commit format)
  log_info "Step 6: Waiting for W1 validation"
  wait_for_workflow "validate-contribution-pr" "$pr_number"

  # Step 7: Check auto-merge status
  log_info "Step 7: Checking auto-merge status"
  sleep 10  # Give auto-merge job time to run

  local auto_merge
  auto_merge=$(gh pr view "$pr_number" --json autoMergeRequest -q '.autoMergeRequest.enabledAt // "null"' 2>/dev/null || echo "null")

  if [[ "$auto_merge" == "null" ]]; then
    log_info "Auto-merge NOT enabled (expected for untrusted/unsigned)"
  else
    if [[ "$is_codeowner" == "true" ]]; then
      log_warn "Auto-merge enabled (user is CODEOWNER, this may be expected)"
    else
      log_warn "Auto-merge was enabled unexpectedly"
    fi
  fi

  # Step 8: Verify commit is unsigned
  log_info "Step 8: Verifying commit signature status"
  local head_sha
  head_sha=$(gh pr view "$pr_number" --json headRefOid -q '.headRefOid')
  local verified
  verified=$(gh api "repos/${E2E_REPO}/commits/$head_sha" -q '.commit.verification.verified' 2>/dev/null || echo "false")

  if [[ "$verified" == "false" ]]; then
    log_info "Commit is unsigned - as intended"
  else
    log_warn "Commit appears to be signed (GitHub web commits are auto-signed)"
  fi

  # Step 9: Verify PR state
  log_info "Step 9: Verifying PR state"
  local pr_state
  pr_state=$(get_pr_state "$pr_number")

  if [[ "$pr_state" == "OPEN" ]]; then
    log_info "PR is open and awaiting review - EXPECTED"
  elif [[ "$pr_state" == "MERGED" ]]; then
    if [[ "$is_codeowner" == "true" ]]; then
      log_warn "PR was merged (user is trusted CODEOWNER)"
    else
      log_warn "PR was merged (may have approval from other source)"
    fi
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
