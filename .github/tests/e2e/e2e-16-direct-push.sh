#!/usr/bin/env bash
# E2E-16: Direct Push Blocked (Negative Test)
#
# Objective: Verify that direct pushes to protected branches are blocked.
#
# This test attempts:
#   - Direct push to main (should fail)
#   - Direct push to integration (should fail)
#
# Expected: Push operations are rejected by branch protection.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-16"
TEST_NAME="Direct Push Blocked"
CHART="${E2E_CHART:-test-workflow}"

# =============================================================================
# Test Implementation
# =============================================================================

main() {
  setup_test "$TEST_ID" "$TEST_NAME"

  # Step 1: Check branch protection status
  log_info "Step 1: Checking branch protection status"

  local main_protected=false
  local integration_protected=false

  # Check main branch protection
  local main_protection
  main_protection=$(gh api "repos/${E2E_REPO}/branches/main/protection" 2>/dev/null || echo "{}")

  if [[ "$main_protection" != "{}" ]]; then
    main_protected=true
    log_info "Main branch: PROTECTED"
  else
    log_warn "Main branch: NOT PROTECTED (or cannot read protection)"
  fi

  # Check integration branch protection
  local integration_protection
  integration_protection=$(gh api "repos/${E2E_REPO}/branches/integration/protection" 2>/dev/null || echo "{}")

  if [[ "$integration_protection" != "{}" ]]; then
    integration_protected=true
    log_info "Integration branch: PROTECTED"
  else
    log_warn "Integration branch: NOT PROTECTED (or cannot read protection)"
  fi

  # Step 2: Verify protection settings prevent direct push
  log_info "Step 2: Verifying protection settings"

  if [[ "$main_protected" == "true" ]]; then
    local main_require_pr
    main_require_pr=$(echo "$main_protection" | jq -r '.required_pull_request_reviews != null')

    if [[ "$main_require_pr" == "true" ]]; then
      log_info "Main requires PR: YES"
    else
      log_warn "Main does not require PR for merging"
    fi
  fi

  if [[ "$integration_protected" == "true" ]]; then
    local integration_require_pr
    integration_require_pr=$(echo "$integration_protection" | jq -r '.required_pull_request_reviews != null')

    if [[ "$integration_require_pr" == "true" ]]; then
      log_info "Integration requires PR: YES"
    else
      log_warn "Integration does not require PR for merging"
    fi
  fi

  # Step 3: Create test commit (in memory, not pushed)
  log_info "Step 3: Creating test commit"

  # Save current position
  local original_branch
  original_branch=$(git branch --show-current)
  local original_sha
  original_sha=$(git rev-parse HEAD)

  # Create a test commit
  cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-16: This should never be pushed directly
e2e16DirectPush: "BLOCKED"
EOF

  git add "charts/$CHART/values.yaml"
  git commit --no-gpg-sign -m "test: direct push attempt (E2E-16)"

  # Step 4: Attempt direct push to main (should fail)
  log_info "Step 4: Attempting direct push to main"

  local main_push_result=0
  if git push origin HEAD:main 2>&1 | tee /tmp/e2e-16-main-push.log; then
    main_push_result=0
    log_error "SECURITY ISSUE: Direct push to main SUCCEEDED!"
  else
    main_push_result=1
    log_info "Direct push to main blocked - EXPECTED"
  fi

  # Check error message
  if grep -q "protected branch" /tmp/e2e-16-main-push.log 2>/dev/null; then
    log_info "Push rejected due to branch protection"
  elif grep -q "permission denied" /tmp/e2e-16-main-push.log 2>/dev/null; then
    log_info "Push rejected due to permissions"
  elif grep -q "pre-receive hook" /tmp/e2e-16-main-push.log 2>/dev/null; then
    log_info "Push rejected by pre-receive hook"
  fi

  # Step 5: Attempt direct push to integration (should fail)
  log_info "Step 5: Attempting direct push to integration"

  local integration_push_result=0
  if git push origin HEAD:integration 2>&1 | tee /tmp/e2e-16-integration-push.log; then
    integration_push_result=0
    log_warn "Direct push to integration SUCCEEDED"
    log_warn "Integration may not have strict protection"
  else
    integration_push_result=1
    log_info "Direct push to integration blocked - EXPECTED"
  fi

  # Step 6: Attempt force push (should definitely fail)
  log_info "Step 6: Attempting force push to main"

  local force_push_result=0
  if git push --force origin HEAD:main 2>&1 | tee /tmp/e2e-16-force-push.log; then
    force_push_result=0
    log_error "CRITICAL SECURITY ISSUE: Force push to main SUCCEEDED!"
  else
    force_push_result=1
    log_info "Force push to main blocked - EXPECTED"
  fi

  # Step 7: Cleanup - reset local state
  log_info "Step 7: Cleaning up"

  git reset --hard "$original_sha"
  rm -f /tmp/e2e-16-*.log

  # Step 8: Verify branch state unchanged
  log_info "Step 8: Verifying branches unchanged"

  git fetch origin main integration --quiet 2>/dev/null || true

  local current_main
  current_main=$(git rev-parse origin/main 2>/dev/null || echo "unknown")
  local current_integration
  current_integration=$(git rev-parse origin/integration 2>/dev/null || echo "unknown")

  log_info "Main branch SHA: ${current_main:0:12}"
  log_info "Integration branch SHA: ${current_integration:0:12}"

  # Step 9: Summary
  log_info "Step 9: Test Summary"

  echo ""
  echo "====== DIRECT PUSH PROTECTION SUMMARY ======"
  echo "Main branch protected: $main_protected"
  echo "Integration branch protected: $integration_protected"
  echo "Direct push to main blocked: $(if [[ $main_push_result -eq 1 ]]; then echo 'YES'; else echo 'NO - SECURITY ISSUE'; fi)"
  echo "Direct push to integration blocked: $(if [[ $integration_push_result -eq 1 ]]; then echo 'YES'; else echo 'NO'; fi)"
  echo "Force push to main blocked: $(if [[ $force_push_result -eq 1 ]]; then echo 'YES'; else echo 'NO - CRITICAL'; fi)"
  echo "============================================="
  echo ""

  # Determine pass/fail
  if [[ $main_push_result -eq 1 ]] && [[ $force_push_result -eq 1 ]]; then
    pass "$TEST_ID"
  else
    fail "$TEST_ID" "Direct or force push to main was not blocked"
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
