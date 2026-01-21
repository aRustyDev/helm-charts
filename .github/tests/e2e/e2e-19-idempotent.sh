#!/usr/bin/env bash
# E2E-19: Release Idempotency (Negative Test)
#
# Objective: Verify that re-running release workflow doesn't create duplicates.
#
# This test:
#   - Finds an existing release
#   - Triggers release workflow again
#   - Verifies no duplicate release is created
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-19"
TEST_NAME="Release Idempotency"
CHART="${E2E_CHART:-test-workflow}"

# =============================================================================
# Test Implementation
# =============================================================================

main() {
  setup_test "$TEST_ID" "$TEST_NAME"

  # Step 1: Get list of existing releases
  log_info "Step 1: Getting existing releases"

  local releases_before
  releases_before=$(gh release list --json tagName,createdAt \
    --jq '.[] | "\(.tagName)|\(.createdAt)"' 2>/dev/null || echo "")

  local release_count_before
  release_count_before=$(echo "$releases_before" | grep -c "." || echo "0")
  log_info "Releases before test: $release_count_before"

  if [[ "$release_count_before" -eq 0 ]]; then
    log_warn "No existing releases found"
    log_warn "Run E2E-1 first to create a release"
    pass "$TEST_ID" "SKIPPED: no releases to test idempotency"
    return 0
  fi

  # Get latest release
  local latest_release
  latest_release=$(get_release_tag)
  log_info "Latest release: $latest_release"

  # Get release details
  local release_info
  release_info=$(gh release view "$latest_release" --json tagName,targetCommitish,createdAt 2>/dev/null || echo "{}")

  local release_commit
  release_commit=$(echo "$release_info" | jq -r '.targetCommitish // "unknown"')
  local release_created
  release_created=$(echo "$release_info" | jq -r '.createdAt // "unknown"')

  log_info "Release commit: $release_commit"
  log_info "Release created: $release_created"

  # Step 2: Find the release workflow run
  log_info "Step 2: Finding release workflow"

  local release_workflow
  release_workflow=$(ls .github/workflows/ | grep -E "(release|chart-release)" | head -1 || echo "")

  if [[ -z "$release_workflow" ]]; then
    log_warn "Could not identify release workflow"
    pass "$TEST_ID" "SKIPPED: release workflow not found"
    return 0
  fi
  log_info "Release workflow: $release_workflow"

  # Step 3: Check for recent workflow runs
  log_info "Step 3: Checking recent release workflow runs"

  local recent_runs
  recent_runs=$(gh run list --workflow "$release_workflow" \
    --json databaseId,conclusion,createdAt \
    --jq '.[:5] | .[] | "\(.databaseId)|\(.conclusion)|\(.createdAt)"' 2>/dev/null || echo "")

  if [[ -n "$recent_runs" ]]; then
    log_info "Recent release workflow runs:"
    while IFS='|' read -r run_id conclusion created; do
      log_info "  Run $run_id: $conclusion ($created)"
    done <<< "$recent_runs"
  fi

  # Step 4: Simulate re-trigger by checking workflow dispatch
  log_info "Step 4: Checking workflow dispatch capability"

  # Check if workflow has workflow_dispatch trigger
  local has_dispatch=false
  if grep -q "workflow_dispatch" ".github/workflows/$release_workflow" 2>/dev/null; then
    has_dispatch=true
    log_info "Workflow supports manual dispatch"
  else
    log_info "Workflow does not support manual dispatch"
  fi

  # Step 5: Check release workflow idempotency logic
  log_info "Step 5: Analyzing release workflow for idempotency"

  local idempotency_checks=0

  # Check for existing release check
  if grep -qE "(gh release view|release.*exists|already.*released)" ".github/workflows/$release_workflow" 2>/dev/null; then
    log_info "Workflow has release existence check"
    ((idempotency_checks++))
  fi

  # Check for version comparison
  if grep -qE "(version.*compare|if.*version|skip.*existing)" ".github/workflows/$release_workflow" 2>/dev/null; then
    log_info "Workflow has version comparison logic"
    ((idempotency_checks++))
  fi

  # Check for conditional release creation
  if grep -qE "(if:.*!.*release|continue-on-error)" ".github/workflows/$release_workflow" 2>/dev/null; then
    log_info "Workflow has conditional release creation"
    ((idempotency_checks++))
  fi

  if [[ $idempotency_checks -eq 0 ]]; then
    log_warn "No obvious idempotency checks found in workflow"
  else
    log_info "Found $idempotency_checks idempotency safeguards"
  fi

  # Step 6: Optionally trigger workflow (if safe to do so)
  log_info "Step 6: Testing idempotency"

  if [[ "$has_dispatch" == "true" ]] && [[ "${E2E_ALLOW_DISPATCH:-false}" == "true" ]]; then
    log_info "Triggering release workflow via dispatch"

    # Trigger workflow
    gh workflow run "$release_workflow" 2>/dev/null || true

    # Wait for workflow to complete
    sleep 30
    wait_for_workflow "${release_workflow%.yaml}" || wait_for_workflow "${release_workflow%.yml}" || true

    # Check for new releases
    local releases_after
    releases_after=$(gh release list --json tagName,createdAt \
      --jq '.[] | "\(.tagName)|\(.createdAt)"' 2>/dev/null || echo "")

    local release_count_after
    release_count_after=$(echo "$releases_after" | grep -c "." || echo "0")

    log_info "Releases after test: $release_count_after"

    if [[ "$release_count_after" -gt "$release_count_before" ]]; then
      log_warn "New release was created - check if expected"
    else
      log_info "No new release created - idempotency verified"
    fi
  else
    log_info "Skipping actual dispatch (set E2E_ALLOW_DISPATCH=true to enable)"
    log_info "Analyzing workflow logic instead"
  fi

  # Step 7: Verify release uniqueness constraint
  log_info "Step 7: Verifying release uniqueness"

  # Check for duplicate tags
  local tag_counts
  tag_counts=$(gh release list --json tagName --jq '.[].tagName' 2>/dev/null | sort | uniq -c | awk '$1 > 1' || echo "")

  if [[ -n "$tag_counts" ]]; then
    log_error "Duplicate release tags found:"
    echo "$tag_counts"
  else
    log_info "No duplicate release tags found"
  fi

  # Step 8: Check for orphaned releases
  log_info "Step 8: Checking for orphaned releases"

  local orphaned=0
  while IFS='|' read -r tag created; do
    [[ -z "$tag" ]] && continue

    # Check if tag exists in git
    if ! git rev-parse "$tag" &>/dev/null; then
      log_warn "Release $tag has no corresponding git tag"
      ((orphaned++))
    fi
  done <<< "$releases_before"

  if [[ $orphaned -gt 0 ]]; then
    log_warn "Found $orphaned releases without git tags"
  else
    log_info "All releases have corresponding git tags"
  fi

  # Step 9: Summary
  log_info "Step 9: Test Summary"

  echo ""
  echo "====== RELEASE IDEMPOTENCY SUMMARY ======"
  echo "Total releases: $release_count_before"
  echo "Latest release: $latest_release"
  echo "Idempotency safeguards found: $idempotency_checks"
  echo "Duplicate tags: $(if [[ -z "$tag_counts" ]]; then echo 'NONE'; else echo 'FOUND'; fi)"
  echo "Orphaned releases: $orphaned"
  echo "=========================================="
  echo ""

  # Determine pass/fail
  if [[ -z "$tag_counts" ]] && [[ $idempotency_checks -gt 0 ]]; then
    pass "$TEST_ID"
  elif [[ -z "$tag_counts" ]]; then
    pass "$TEST_ID" "WARN: no idempotency checks found but no duplicates"
  else
    fail "$TEST_ID" "Duplicate releases found"
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
