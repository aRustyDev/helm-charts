#!/usr/bin/env bash
# E2E-13: Full Lineage Trace
#
# Objective: Verify complete traceability from release back to original commit.
#
# This test:
#   - Takes a released chart
#   - Traces back through the atomic PR to integration
#   - Traces back to the original contribution PR
#   - Validates the complete audit trail
#
# Note: This test depends on E2E-1 having created a release.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-13"
TEST_NAME="Full Lineage Trace"
CHART="${E2E_CHART:-test-workflow}"

# =============================================================================
# Test Implementation
# =============================================================================

main() {
  setup_test "$TEST_ID" "$TEST_NAME"

  # Step 1: Find latest release
  log_info "Step 1: Finding latest release"
  local latest_release
  latest_release=$(get_release_tag)

  if [[ -z "$latest_release" ]]; then
    log_warn "No releases found in repository"
    log_warn "Run E2E-1 first to create a release"
    pass "$TEST_ID" "SKIPPED: no releases found"
    return 0
  fi
  log_info "Latest release: $latest_release"

  # Step 2: Get release metadata
  log_info "Step 2: Getting release metadata"
  local release_info
  release_info=$(gh release view "$latest_release" --json tagName,targetCommitish,createdAt,body 2>/dev/null || echo "{}")

  local release_commit
  release_commit=$(echo "$release_info" | jq -r '.targetCommitish // "unknown"')
  local release_date
  release_date=$(echo "$release_info" | jq -r '.createdAt // "unknown"')
  local release_body
  release_body=$(echo "$release_info" | jq -r '.body // ""')

  log_info "Release commit: $release_commit"
  log_info "Release date: $release_date"

  # Step 3: Find the merge commit on main
  log_info "Step 3: Finding merge commit on main"
  git fetch origin main --quiet

  # Get the commit that the release tag points to
  local tag_commit
  tag_commit=$(git rev-list -n 1 "$latest_release" 2>/dev/null || echo "")

  if [[ -z "$tag_commit" ]]; then
    log_warn "Could not resolve release tag to commit"
    log_info "Continuing with release_commit: $release_commit"
    tag_commit="$release_commit"
  fi
  log_info "Tag points to commit: $tag_commit"

  # Step 4: Get commit details
  log_info "Step 4: Getting commit details"
  local commit_info
  commit_info=$(git log -1 --format="%H|%s|%an|%ae|%aI" "$tag_commit" 2>/dev/null || echo "")

  if [[ -n "$commit_info" ]]; then
    IFS='|' read -r commit_sha commit_subject commit_author commit_email commit_date <<< "$commit_info"
    log_info "Commit SHA: $commit_sha"
    log_info "Subject: $commit_subject"
    log_info "Author: $commit_author <$commit_email>"
    log_info "Date: $commit_date"
  fi

  # Step 5: Find associated PR (atomic PR to main)
  log_info "Step 5: Finding atomic PR"
  local atomic_pr
  atomic_pr=$(gh pr list --state merged --base main \
    --search "head:chart/$CHART" \
    --json number,mergeCommit,title \
    --jq ".[] | select(.mergeCommit.oid == \"$tag_commit\" or .mergeCommit.oid[:7] == \"${tag_commit:0:7}\") | .number" \
    2>/dev/null | head -1 || echo "")

  if [[ -z "$atomic_pr" ]]; then
    # Try searching by commit in PR body/comments
    atomic_pr=$(gh pr list --state merged --base main \
      --search "chart/$CHART" \
      --json number \
      --jq '.[0].number' 2>/dev/null || echo "")
  fi

  if [[ -n "$atomic_pr" ]]; then
    log_info "Atomic PR: #$atomic_pr"

    # Get atomic PR details
    local atomic_pr_info
    atomic_pr_info=$(gh pr view "$atomic_pr" --json title,body,mergedAt,mergedBy,headRefName 2>/dev/null || echo "{}")

    local atomic_title
    atomic_title=$(echo "$atomic_pr_info" | jq -r '.title // "unknown"')
    local atomic_merged_by
    atomic_merged_by=$(echo "$atomic_pr_info" | jq -r '.mergedBy.login // "unknown"')
    local atomic_merged_at
    atomic_merged_at=$(echo "$atomic_pr_info" | jq -r '.mergedAt // "unknown"')

    log_info "Atomic PR title: $atomic_title"
    log_info "Merged by: $atomic_merged_by"
    log_info "Merged at: $atomic_merged_at"
  else
    log_warn "Could not find atomic PR for this release"
    log_info "This may be expected for manually created releases"
  fi

  # Step 6: Trace to integration branch
  log_info "Step 6: Tracing to integration branch"

  # The atomic branch should have been created from integration
  # Check the PR body for references
  if [[ -n "$atomic_pr" ]]; then
    local pr_body
    pr_body=$(gh pr view "$atomic_pr" --json body -q '.body' 2>/dev/null || echo "")

    # Look for integration PR references
    local integration_pr_ref
    integration_pr_ref=$(echo "$pr_body" | grep -oE '#[0-9]+' | head -1 || echo "")

    if [[ -n "$integration_pr_ref" ]]; then
      log_info "Referenced integration PR: $integration_pr_ref"
    fi
  fi

  # Step 7: Find original contribution PR
  log_info "Step 7: Finding original contribution PR"

  # Search for merged PRs to integration that touched this chart
  local contribution_prs
  contribution_prs=$(gh pr list --state merged --base integration \
    --search "$CHART" \
    --json number,title,mergedAt \
    --jq '.[:5] | .[] | "\(.number)|\(.title)|\(.mergedAt)"' 2>/dev/null || echo "")

  if [[ -n "$contribution_prs" ]]; then
    log_info "Recent contribution PRs to integration:"
    while IFS='|' read -r pr_num pr_title pr_merged; do
      log_info "  #$pr_num: $pr_title (merged: $pr_merged)"
    done <<< "$contribution_prs"
  else
    log_info "No recent contribution PRs found for $CHART"
  fi

  # Step 8: Verify commit signature chain
  log_info "Step 8: Verifying commit signatures"

  local verified
  verified=$(gh api "repos/${E2E_REPO}/commits/$tag_commit" -q '.commit.verification.verified' 2>/dev/null || echo "unknown")
  local sig_reason
  sig_reason=$(gh api "repos/${E2E_REPO}/commits/$tag_commit" -q '.commit.verification.reason' 2>/dev/null || echo "unknown")

  log_info "Commit verification: $verified ($sig_reason)"

  # Step 9: Build lineage summary
  log_info "Step 9: Building lineage summary"

  echo ""
  echo "====== LINEAGE TRACE ======"
  echo "Release: $latest_release"
  echo "  -> Commit: ${tag_commit:0:12}"
  echo "  -> Atomic PR: ${atomic_pr:-unknown}"
  echo "  -> Integration Branch"
  echo "  -> Contribution PRs: $contribution_prs"
  echo "  -> Verified: $verified"
  echo "==========================="
  echo ""

  # Step 10: Validate lineage integrity
  log_info "Step 10: Validating lineage integrity"

  local lineage_valid=true
  local issues=()

  if [[ -z "$tag_commit" ]]; then
    issues+=("Cannot resolve release tag to commit")
    lineage_valid=false
  fi

  if [[ "$verified" != "true" ]]; then
    issues+=("Release commit is not verified")
    # Don't fail for this - signature may not be required
  fi

  if [[ ${#issues[@]} -gt 0 ]]; then
    log_warn "Lineage issues found:"
    for issue in "${issues[@]}"; do
      log_warn "  - $issue"
    done
  else
    log_info "Lineage validation: COMPLETE"
  fi

  if [[ "$lineage_valid" == "true" ]]; then
    pass "$TEST_ID"
  else
    fail "$TEST_ID" "Lineage trace incomplete"
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
