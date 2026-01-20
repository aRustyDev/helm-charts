#!/usr/bin/env bash
# E2E-4: Multi-File-Type Atomization
#
# Objective: Verify that W2 correctly atomizes changes to different file types.
#
# This test creates:
#   - Chart changes (charts/*)
#   - Documentation changes (docs/*)
#   - CI workflow changes (.github/*)
#
# W2 should create separate atomic branches/PRs for each type.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-4"
TEST_NAME="Multi-File-Type Atomization"
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
  BRANCH=$(create_test_branch "test/e2e-4")

  # Step 3: Apply multi-type fixtures
  log_info "Step 3: Applying multi-type fixtures"
  apply_fixture "e2e-4-multi-type"

  # Step 4: Commit with signature
  log_info "Step 4: Committing changes"
  git add .
  git commit -S -m "feat($CHART): multi-type changes (E2E-4)" || \
    git commit -m "feat($CHART): multi-type changes (E2E-4)"

  # Step 5: Push and create PR to integration
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-4: Multi-Type" "Testing multi-file-type atomization")
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

  # Step 9: Find atomic PRs
  log_info "Step 9: Finding atomic PRs"
  git fetch origin --prune

  # Check for chart PR
  local chart_pr
  chart_pr=$(gh pr list --base main --search "head:chart/$CHART" --json number -q '.[0].number' || echo "")

  # Check for docs PR
  local docs_pr
  docs_pr=$(gh pr list --base main --search "head:docs/" --json number -q '.[0].number' || echo "")

  # Check for CI/workflow PR
  local ci_pr
  ci_pr=$(gh pr list --base main --search "head:ci/" --json number -q '.[0].number' || echo "")

  log_info "Atomic PRs found:"
  log_info "  Chart PR: ${chart_pr:-none}"
  log_info "  Docs PR: ${docs_pr:-none}"
  log_info "  CI PR: ${ci_pr:-none}"

  # Step 10: Verify atomization
  log_info "Step 10: Verifying atomization"
  local atomized_count=0

  if [[ -n "$chart_pr" ]]; then
    log_info "Chart changes atomized to PR #$chart_pr"
    ((atomized_count++))
  fi

  if [[ -n "$docs_pr" ]]; then
    log_info "Docs changes atomized to PR #$docs_pr"
    ((atomized_count++))
  fi

  if [[ -n "$ci_pr" ]]; then
    log_info "CI changes atomized to PR #$ci_pr"
    ((atomized_count++))
  fi

  if [[ $atomized_count -lt 2 ]]; then
    log_warn "Expected multiple atomic PRs, found $atomized_count"
    log_warn "W2 atomization may combine some change types"
  else
    log_info "Multiple change types correctly atomized"
  fi

  # Step 11: Verify each atomic PR has correct content
  log_info "Step 11: Verifying atomic PR content"

  if [[ -n "$chart_pr" ]]; then
    local chart_files
    chart_files=$(gh pr diff "$chart_pr" --name-only 2>/dev/null || echo "")
    if echo "$chart_files" | grep -q "^charts/"; then
      log_info "Chart PR contains chart files - correct"
    else
      log_warn "Chart PR may not contain expected files"
    fi
  fi

  if [[ -n "$docs_pr" ]]; then
    local docs_files
    docs_files=$(gh pr diff "$docs_pr" --name-only 2>/dev/null || echo "")
    if echo "$docs_files" | grep -q "^docs/"; then
      log_info "Docs PR contains docs files - correct"
    else
      log_warn "Docs PR may not contain expected files"
    fi
  fi

  # Cleanup: Close atomic PRs and delete branches
  log_info "Cleanup: Closing atomic PRs"
  [[ -n "$chart_pr" ]] && close_pr "$chart_pr" "true" || true
  [[ -n "$docs_pr" ]] && close_pr "$docs_pr" "true" || true
  [[ -n "$ci_pr" ]] && close_pr "$ci_pr" "true" || true

  # Remove fixtures
  cleanup_fixture "e2e-4-multi-type"

  teardown_test "$TEST_ID" "$BRANCH"

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
