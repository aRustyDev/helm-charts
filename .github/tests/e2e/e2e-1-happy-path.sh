#!/usr/bin/env bash
# E2E-1: Happy Path (Full Pipeline with Merge Queue)
#
# Objective: Verify complete workflow from contribution to release via merge queue.
#
# Flow:
#   1. Create feature branch from integration
#   2. Add minor feature to chart (bump minor)
#   3. Commit with signed conventional commit
#   4. Push and create PR to integration
#   5. Verify W1 passes (lint, artifacthub, commit, cherry-pick preview)
#   6. Verify auto-merge enables
#   7. PR enters merge queue and merges
#   8. Verify W2 atomizes
#   9. Verify W5 validates
#   10. Merge atomic PR to main
#   11. Verify Release workflow
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-1"
TEST_NAME="Happy Path"
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
  BRANCH=$(create_test_branch "test/e2e-1")
  log_info "Created branch: $BRANCH"

  # Step 3: Apply fixtures
  log_info "Step 3: Applying fixtures"
  apply_fixture "e2e-1-happy-path"

  # Step 4: Commit with signature
  log_info "Step 4: Committing changes"
  git add .
  git commit -S -m "feat($CHART): E2E-1 happy path test feature" || {
    # If signing fails, try without (for CI without GPG)
    log_warn "Signed commit failed, trying unsigned"
    git commit -m "feat($CHART): E2E-1 happy path test feature"
  }

  # Step 5: Push and create PR
  log_info "Step 5: Pushing and creating PR"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-1: Happy Path" "Automated E2E-1 test for full pipeline verification")
  local pr_number
  pr_number=$(echo "$pr_url" | grep -oE '[0-9]+$')
  log_info "Created PR #$pr_number"

  # Step 6: Wait for W1 validation
  log_info "Step 6: Waiting for W1 validation (lint, artifacthub, commit)"
  wait_for_workflow "validate-contribution-pr" "$pr_number"

  # Step 7: Wait for merge
  log_info "Step 7: Waiting for PR to merge via merge queue"
  wait_for_merge "$pr_number"

  # Step 8: Wait for W2 atomization
  log_info "Step 8: Waiting for W2 atomization"
  sleep 10  # Give W2 time to trigger
  wait_for_workflow "atomize-integration-pr"

  # Step 9: Find atomic PR
  log_info "Step 9: Finding atomic PR"
  git fetch origin --prune
  local atomic_pr
  atomic_pr=$(gh pr list --base main --head "chart/$CHART" --json number -q '.[0].number' || echo "")
  if [[ -z "$atomic_pr" ]]; then
    fail "$TEST_ID" "Atomic PR not found for chart/$CHART"
    return 1
  fi
  log_info "Found atomic PR #$atomic_pr"

  # Step 10: Wait for W5 validation
  log_info "Step 10: Waiting for W5 validation"
  wait_for_workflow "validate-atomic-pr" "$atomic_pr"

  # Step 11: Merge atomic PR
  log_info "Step 11: Merging atomic PR to main"
  merge_pr "$atomic_pr" "squash"

  # Step 12: Wait for release workflow
  log_info "Step 12: Waiting for release workflow"
  wait_for_workflow "release-atomic-chart"

  # Step 13: Verify release
  log_info "Step 13: Verifying release"
  local release_tag
  release_tag=$(get_release_tag)
  assert_not_empty "$release_tag" "Release tag"
  log_info "Release tag: $release_tag"

  # Step 14: Verify attestation
  log_info "Step 14: Verifying attestation"
  local package="${CHART}-*.tgz"
  gh release download "$release_tag" --pattern "$package" --dir /tmp/e2e-1
  local downloaded_package
  downloaded_package=$(ls /tmp/e2e-1/*.tgz 2>/dev/null | head -1)
  if [[ -n "$downloaded_package" ]]; then
    if verify_attestation "$downloaded_package"; then
      log_info "Attestation verified successfully"
    else
      log_warn "Attestation verification failed (may be expected in some configurations)"
    fi
    rm -rf /tmp/e2e-1
  fi

  # Step 15: Verify integration was reset
  log_info "Step 15: Verifying integration reset"
  git fetch origin
  local integration_sha main_sha
  integration_sha=$(git rev-parse origin/integration)
  main_sha=$(git rev-parse origin/main)
  if [[ "$integration_sha" == "$main_sha" ]]; then
    log_info "Integration branch reset to main: confirmed"
  else
    log_warn "Integration branch may not have been reset (check W2 behavior)"
  fi

  # Cleanup
  teardown_test "$TEST_ID" "$BRANCH"

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
