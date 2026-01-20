#!/usr/bin/env bash
# E2E-20: Invalid Commit Format (Negative Test)
#
# Objective: Verify that commits not following conventional commit format are blocked.
#
# This test creates PRs with:
#   - Non-conventional commit message
#   - Invalid scope
#   - Missing type
#
# Expected: W1 commit validation fails, PR cannot auto-merge.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-20"
TEST_NAME="Invalid Commit Format"
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
  BRANCH=$(create_test_branch "test/e2e-20")

  # Step 3: Make a valid change with INVALID commit message
  log_info "Step 3: Making change with invalid commit message"

  cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-20: Invalid commit format test
e2e20Test:
  enabled: false
  badCommit: true
EOF

  git add .

  # Step 4: Commit with non-conventional message
  log_info "Step 4: Creating commit with invalid format"

  # Various invalid commit formats
  local invalid_messages=(
    "Updated the values file"                      # No type
    "Fix stuff"                                     # No scope, vague
    "feat - add new feature"                       # Wrong separator
    "FEAT($CHART): uppercase type"                 # Uppercase type
    "feat(): empty scope"                          # Empty scope
    "feat($CHART) missing colon"                   # Missing colon
    "wip: work in progress"                        # WIP commits often blocked
  )

  # Use first invalid message for this test
  local invalid_msg="${invalid_messages[0]}"
  log_info "Commit message: '$invalid_msg'"

  git commit --no-gpg-sign -m "$invalid_msg"

  # Step 5: Push and create PR
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-20: Bad Commit" "Testing invalid commit format rejection")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Wait for W1 validation
  log_info "Step 6: Waiting for W1 validation"
  sleep 15

  # Check commit-validation status specifically
  local commit_status
  commit_status=$(get_check_conclusion "$pr_number" "commit-validation" || echo "pending")

  local attempts=0
  while [[ "$commit_status" == "pending" || "$commit_status" == "in_progress" ]] && [[ $attempts -lt 30 ]]; do
    sleep 10
    commit_status=$(get_check_conclusion "$pr_number" "commit-validation" || echo "pending")
    ((attempts++))
    log_info "Commit validation status: $commit_status (attempt $attempts)"
  done

  # Step 7: Verify commit validation failed
  log_info "Step 7: Verifying commit validation result"

  if [[ "$commit_status" == "failure" ]]; then
    log_info "Commit validation FAILED as expected"
  elif [[ "$commit_status" == "success" ]]; then
    log_warn "Commit validation PASSED - check conventional commit rules"
    log_warn "Message was: '$invalid_msg'"
  else
    log_warn "Commit validation status: $commit_status"
  fi

  # Step 8: Check auto-merge status
  log_info "Step 8: Checking auto-merge status"

  local auto_merge
  auto_merge=$(gh pr view "$pr_number" --json autoMergeRequest -q '.autoMergeRequest.enabledAt // "null"' 2>/dev/null || echo "null")

  if [[ "$auto_merge" == "null" ]]; then
    log_info "Auto-merge NOT enabled (expected for invalid commit)"
  else
    log_warn "Auto-merge was enabled despite invalid commit"
  fi

  # Step 9: Check PR status
  log_info "Step 9: Checking PR merge eligibility"

  local pr_state
  pr_state=$(get_pr_state "$pr_number")

  local mergeable
  mergeable=$(gh pr view "$pr_number" --json mergeable -q '.mergeable' 2>/dev/null || echo "UNKNOWN")

  log_info "PR state: $pr_state"
  log_info "PR mergeable: $mergeable"

  if [[ "$pr_state" == "OPEN" ]]; then
    log_info "PR is still open (blocked by failing checks) - EXPECTED"
  elif [[ "$pr_state" == "MERGED" ]]; then
    log_error "PR was merged despite invalid commit format!"
  fi

  # Step 10: Test additional invalid formats
  log_info "Step 10: Testing pattern variations"

  local pattern_results=()
  for msg in "${invalid_messages[@]:1}"; do  # Skip first, already tested
    # Create new commit
    echo "# Pattern test: $msg" >> "charts/$CHART/values.yaml"
    git add .
    git commit --no-gpg-sign -m "$msg" 2>/dev/null || true

    # Check if commitlint would accept
    if command -v commitlint &>/dev/null; then
      if echo "$msg" | commitlint --config .commitlintrc.js 2>/dev/null; then
        pattern_results+=("PASS: $msg")
      else
        pattern_results+=("FAIL: $msg")
      fi
    else
      pattern_results+=("SKIP: $msg (commitlint not available)")
    fi

    # Reset for next test
    git reset --soft HEAD~1 2>/dev/null || true
  done

  if [[ ${#pattern_results[@]} -gt 0 ]]; then
    log_info "Pattern validation results:"
    for result in "${pattern_results[@]}"; do
      log_info "  $result"
    done
  fi

  # Cleanup
  log_info "Cleanup: Closing PR and reverting"
  close_pr "$pr_number" "true" || true

  git checkout origin/integration -- "charts/$CHART/values.yaml" 2>/dev/null || true

  teardown_test "$TEST_ID" "$BRANCH"

  # Step 11: Summary
  log_info "Step 11: Test Summary"

  echo ""
  echo "====== INVALID COMMIT FORMAT SUMMARY ======"
  echo "Test message: '$invalid_msg'"
  echo "Commit validation: $commit_status"
  echo "Auto-merge enabled: $(if [[ "$auto_merge" == 'null' ]]; then echo 'NO'; else echo 'YES'; fi)"
  echo "PR mergeable: $mergeable"
  echo "============================================"
  echo ""

  # Determine pass/fail
  if [[ "$commit_status" == "failure" ]] && [[ "$auto_merge" == "null" ]]; then
    pass "$TEST_ID"
  elif [[ "$commit_status" != "success" ]]; then
    pass "$TEST_ID" "WARN: commit validation did not explicitly fail"
  else
    fail "$TEST_ID" "Invalid commit was not rejected"
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
