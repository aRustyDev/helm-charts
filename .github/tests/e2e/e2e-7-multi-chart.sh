#!/usr/bin/env bash
# E2E-7: Multiple Charts in Single PR
#
# Objective: Verify that W2 creates separate atomic PRs for each chart changed.
#
# This test:
#   - Modifies multiple charts in a single PR
#   - Verifies W2 creates separate atomic PRs per chart
#   - Validates each chart goes through independent validation
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-7"
TEST_NAME="Multiple Charts"
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

  # Find another chart to modify
  local second_chart=""
  for chart_dir in charts/*/; do
    local chart_name
    chart_name=$(basename "$chart_dir")
    if [[ "$chart_name" != "$CHART" ]] && [[ -f "$chart_dir/Chart.yaml" ]]; then
      second_chart="$chart_name"
      break
    fi
  done

  if [[ -z "$second_chart" ]]; then
    log_warn "Only one chart found in repository"
    log_warn "Skipping multi-chart test (requires 2+ charts)"
    pass "$TEST_ID" "SKIPPED: requires multiple charts"
    return 0
  fi

  log_info "Charts to modify: $CHART, $second_chart"

  # Step 2: Create test branch
  log_info "Step 2: Creating test branch"
  BRANCH=$(create_test_branch "test/e2e-7")

  # Step 3: Modify both charts
  log_info "Step 3: Modifying multiple charts"

  # Modify first chart
  cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-7: Multi-chart test annotation
e2e7Test:
  enabled: false
  chart: "first"
EOF

  # Modify second chart
  cat >> "charts/$second_chart/values.yaml" << 'EOF'

# E2E-7: Multi-chart test annotation
e2e7Test:
  enabled: false
  chart: "second"
EOF

  # Step 4: Commit
  log_info "Step 4: Committing changes to both charts"
  git add .
  git commit -S -m "feat($CHART,$second_chart): multi-chart changes (E2E-7)" || \
    git commit -m "feat($CHART,$second_chart): multi-chart changes (E2E-7)"

  # Step 5: Push and create PR to integration
  log_info "Step 5: Creating PR to integration"
  git push origin "$BRANCH"
  local pr_url
  pr_url=$(create_pr "integration" "Test E2E-7: Multi-Chart" "Testing multi-chart atomization")
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

  # Step 9: Find atomic PRs for each chart
  log_info "Step 9: Finding atomic PRs"
  git fetch origin --prune

  # Check for first chart PR
  local first_chart_pr
  first_chart_pr=$(gh pr list --base main --head "chart/$CHART" --json number -q '.[0].number' || echo "")

  # Check for second chart PR
  local second_chart_pr
  second_chart_pr=$(gh pr list --base main --head "chart/$second_chart" --json number -q '.[0].number' || echo "")

  log_info "Atomic PRs found:"
  log_info "  $CHART PR: ${first_chart_pr:-none}"
  log_info "  $second_chart PR: ${second_chart_pr:-none}"

  # Step 10: Verify separate atomization
  log_info "Step 10: Verifying separate atomization"

  local success=true
  if [[ -z "$first_chart_pr" ]]; then
    log_error "No atomic PR found for $CHART"
    success=false
  else
    log_info "Chart $CHART atomized to PR #$first_chart_pr"
  fi

  if [[ -z "$second_chart_pr" ]]; then
    log_error "No atomic PR found for $second_chart"
    success=false
  else
    log_info "Chart $second_chart atomized to PR #$second_chart_pr"
  fi

  if [[ "$first_chart_pr" == "$second_chart_pr" ]] && [[ -n "$first_chart_pr" ]]; then
    log_warn "Both charts in same PR - atomization may combine related changes"
  fi

  # Step 11: Verify each PR has correct files
  log_info "Step 11: Verifying PR content"

  if [[ -n "$first_chart_pr" ]]; then
    local first_files
    first_files=$(gh pr diff "$first_chart_pr" --name-only 2>/dev/null || echo "")
    if echo "$first_files" | grep -q "^charts/$CHART/"; then
      log_info "First chart PR contains correct files"
    else
      log_warn "First chart PR may have unexpected content"
    fi
  fi

  if [[ -n "$second_chart_pr" ]]; then
    local second_files
    second_files=$(gh pr diff "$second_chart_pr" --name-only 2>/dev/null || echo "")
    if echo "$second_files" | grep -q "^charts/$second_chart/"; then
      log_info "Second chart PR contains correct files"
    else
      log_warn "Second chart PR may have unexpected content"
    fi
  fi

  # Cleanup
  log_info "Cleanup: Closing atomic PRs and reverting changes"
  [[ -n "$first_chart_pr" ]] && close_pr "$first_chart_pr" "true" || true
  [[ -n "$second_chart_pr" ]] && close_pr "$second_chart_pr" "true" || true

  # Revert changes
  git checkout origin/integration -- "charts/$CHART/values.yaml" 2>/dev/null || true
  git checkout origin/integration -- "charts/$second_chart/values.yaml" 2>/dev/null || true

  teardown_test "$TEST_ID" "$BRANCH"

  if [[ "$success" == "true" ]]; then
    pass "$TEST_ID"
  else
    fail "$TEST_ID" "Multi-chart atomization did not create expected PRs"
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
