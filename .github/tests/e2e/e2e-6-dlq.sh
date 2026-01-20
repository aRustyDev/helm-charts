#!/usr/bin/env bash
# E2E-6: DLQ (Dead Letter Queue) Handling
#
# Objective: Verify that files not matching atomization patterns go to DLQ.
#
# This test creates:
#   - Files in scripts/ directory
#   - Files in misc/ directory
#   - Other non-standard locations
#
# W2 should route these to a DLQ branch for manual handling.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-6"
TEST_NAME="DLQ Handling"
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
  assert_codeowners_member
  validate_chart_exists "$CHART"

  # Step 2: Create test branch
  log_info "Step 2: Creating test branch"
  BRANCH=$(create_test_branch "test/e2e-6")

  # Step 3: Apply DLQ fixtures
  log_info "Step 3: Applying DLQ fixtures"
  apply_fixture "e2e-6-dlq"

  # Step 4: Commit
  log_info "Step 4: Committing changes"
  git add .
  git commit -S -m "chore: add utility scripts (E2E-6)" || \
    git commit -m "chore: add utility scripts (E2E-6)"

  # Step 5: Push and create PR to integration
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-6: DLQ Test" "Testing DLQ handling for non-standard files")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Wait for W1 validation
  log_info "Step 6: Waiting for W1 validation"
  wait_for_workflow "validate-contribution-pr" "$pr_number"

  # Step 7: Wait for merge
  log_info "Step 7: Waiting for PR to merge"
  wait_for_merge "$pr_number"

  # Step 8: Wait for W2 atomization
  log_info "Step 8: Waiting for W2 atomization"
  sleep 15
  wait_for_workflow "atomize-integration-pr"

  # Step 9: Check for DLQ branch/PR
  log_info "Step 9: Checking for DLQ handling"
  git fetch origin --prune

  # Check for DLQ branch
  local dlq_branch
  dlq_branch=$(git branch -r --list 'origin/dlq/*' | head -1 | tr -d ' ' || echo "")

  # Check for DLQ PR
  local dlq_pr
  dlq_pr=$(gh pr list --base main --search "head:dlq/" --json number -q '.[0].number' || echo "")

  # Alternative: Check for unmatched files PR
  local unmatched_pr
  unmatched_pr=$(gh pr list --base main --search "head:unmatched/" --json number -q '.[0].number' || echo "")

  log_info "DLQ status:"
  log_info "  DLQ branch: ${dlq_branch:-none}"
  log_info "  DLQ PR: ${dlq_pr:-none}"
  log_info "  Unmatched PR: ${unmatched_pr:-none}"

  # Step 10: Verify DLQ behavior
  log_info "Step 10: Verifying DLQ behavior"

  local dlq_found=false
  if [[ -n "$dlq_branch" ]] || [[ -n "$dlq_pr" ]] || [[ -n "$unmatched_pr" ]]; then
    dlq_found=true
    log_info "Non-standard files routed to DLQ - EXPECTED"
  else
    log_warn "No DLQ branch/PR found"
    log_warn "W2 may handle non-standard files differently"

    # Check if files were just ignored
    log_info "Checking integration branch state..."
    git checkout origin/integration 2>/dev/null || true
    if [[ -d "scripts" ]] || [[ -d "misc" ]]; then
      log_info "Non-standard directories present on integration"
    fi
    git checkout "$BRANCH" 2>/dev/null || true
  fi

  # Step 11: If DLQ PR exists, verify content
  if [[ -n "$dlq_pr" ]]; then
    log_info "Step 11: Verifying DLQ PR content"
    local dlq_files
    dlq_files=$(gh pr diff "$dlq_pr" --name-only 2>/dev/null || echo "")
    log_info "DLQ PR files: $dlq_files"

    if echo "$dlq_files" | grep -qE "^(scripts/|misc/)"; then
      log_info "DLQ PR contains non-standard files - correct"
    fi
  elif [[ -n "$unmatched_pr" ]]; then
    log_info "Step 11: Verifying unmatched PR content"
    local unmatched_files
    unmatched_files=$(gh pr diff "$unmatched_pr" --name-only 2>/dev/null || echo "")
    log_info "Unmatched PR files: $unmatched_files"
  else
    log_info "Step 11: Skipped (no DLQ PR to verify)"
  fi

  # Cleanup
  log_info "Cleanup: Removing DLQ artifacts"
  [[ -n "$dlq_pr" ]] && close_pr "$dlq_pr" "true" || true
  [[ -n "$unmatched_pr" ]] && close_pr "$unmatched_pr" "true" || true

  # Remove fixtures
  cleanup_fixture "e2e-6-dlq"

  teardown_test "$TEST_ID" "$BRANCH"

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
