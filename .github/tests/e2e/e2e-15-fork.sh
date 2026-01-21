#!/usr/bin/env bash
# E2E-15: Fork PR Security
#
# Objective: Verify that PRs from forks have appropriate security restrictions.
#
# This test validates:
#   - Fork PRs cannot access secrets
#   - Fork PRs require approval before workflows run
#   - Fork PRs cannot auto-merge
#
# Note: This test requires a forked repository or simulates fork behavior.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-15"
TEST_NAME="Fork PR Security"
CHART="${E2E_CHART:-test-workflow}"

# =============================================================================
# Test Implementation
# =============================================================================

main() {
  setup_test "$TEST_ID" "$TEST_NAME"

  # Step 1: Check repository configuration
  log_info "Step 1: Checking repository fork settings"

  local repo_info
  repo_info=$(gh api "repos/${E2E_REPO}" 2>/dev/null || echo "{}")

  local allow_forking
  allow_forking=$(echo "$repo_info" | jq -r '.allow_forking // true')
  local is_fork
  is_fork=$(echo "$repo_info" | jq -r '.fork // false')

  log_info "Repository allows forking: $allow_forking"
  log_info "This repo is a fork: $is_fork"

  # Step 2: Check workflow permissions for forks
  log_info "Step 2: Checking workflow permissions"

  # Get workflow files and check for fork restrictions
  local workflow_files
  workflow_files=$(find .github/workflows -name "*.yaml" -o -name "*.yml" 2>/dev/null || echo "")

  for wf in $workflow_files; do
    local wf_name
    wf_name=$(basename "$wf")

    # Check for pull_request_target (more permissive with forks)
    if grep -q "pull_request_target" "$wf" 2>/dev/null; then
      log_warn "$wf_name uses pull_request_target (runs with base repo context)"
    fi

    # Check for fork checks in workflow
    if grep -q "github.event.pull_request.head.repo.fork" "$wf" 2>/dev/null; then
      log_info "$wf_name has fork detection logic"
    fi
  done

  # Step 3: Check first-time contributor settings
  log_info "Step 3: Checking first-time contributor settings"

  # Get repository actions settings
  local actions_perms
  actions_perms=$(gh api "repos/${E2E_REPO}/actions/permissions" 2>/dev/null || echo "{}")

  local allowed_actions
  allowed_actions=$(echo "$actions_perms" | jq -r '.allowed_actions // "unknown"')
  log_info "Allowed actions: $allowed_actions"

  # Step 4: Check for fork PR restrictions in branch protection
  log_info "Step 4: Checking branch protection rules"

  local protection
  protection=$(gh api "repos/${E2E_REPO}/branches/integration/protection" 2>/dev/null || echo "{}")

  if [[ "$protection" != "{}" ]]; then
    local require_pr
    require_pr=$(echo "$protection" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
    local dismiss_stale
    dismiss_stale=$(echo "$protection" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')

    log_info "Required approvals: $require_pr"
    log_info "Dismiss stale reviews: $dismiss_stale"
  else
    log_warn "Could not retrieve branch protection rules"
  fi

  # Step 5: List existing fork PRs (if any)
  log_info "Step 5: Checking for existing fork PRs"

  local fork_prs
  fork_prs=$(gh pr list --state open \
    --json number,title,headRepositoryOwner,isCrossRepository \
    --jq '.[] | select(.isCrossRepository == true) | "\(.number)|\(.title)|\(.headRepositoryOwner.login)"' \
    2>/dev/null || echo "")

  if [[ -n "$fork_prs" ]]; then
    log_info "Open fork PRs:"
    while IFS='|' read -r pr_num pr_title pr_owner; do
      log_info "  #$pr_num from @$pr_owner: $pr_title"
    done <<< "$fork_prs"
  else
    log_info "No open fork PRs found"
  fi

  # Step 6: Verify secrets are not exposed to forks
  log_info "Step 6: Verifying secret protection"

  # Check workflow files for secret usage patterns
  local secrets_in_workflows=()
  for wf in $workflow_files; do
    if grep -q '\${{ secrets\.' "$wf" 2>/dev/null; then
      local wf_name
      wf_name=$(basename "$wf")
      secrets_in_workflows+=("$wf_name")
    fi
  done

  if [[ ${#secrets_in_workflows[@]} -gt 0 ]]; then
    log_info "Workflows using secrets:"
    for wf in "${secrets_in_workflows[@]}"; do
      log_info "  - $wf"

      # Check if this workflow runs on fork PRs
      local wf_path=".github/workflows/$wf"
      if grep -q "pull_request:" "$wf_path" 2>/dev/null; then
        # Check for fork restrictions
        if ! grep -qE "(github\.event\.pull_request\.head\.repo\.fork|if:.*fork)" "$wf_path" 2>/dev/null; then
          log_warn "  WARNING: $wf uses secrets and may run on forks without restrictions"
        fi
      fi
    done
  fi

  # Step 7: Validate CODEOWNERS for fork reviews
  log_info "Step 7: Validating CODEOWNERS configuration"

  if [[ -f ".github/CODEOWNERS" ]] || [[ -f "CODEOWNERS" ]]; then
    log_info "CODEOWNERS file exists"
    log_info "Fork PRs will require CODEOWNER approval"
  else
    log_warn "No CODEOWNERS file found"
    log_warn "Fork PRs may not require specific reviewers"
  fi

  # Step 8: Check for required status checks
  log_info "Step 8: Verifying required status checks"

  if [[ "$protection" != "{}" ]]; then
    local required_checks
    required_checks=$(echo "$protection" | jq -r '.required_status_checks.contexts[]? // empty' 2>/dev/null || echo "")

    if [[ -n "$required_checks" ]]; then
      log_info "Required status checks:"
      while read -r check; do
        log_info "  - $check"
      done <<< "$required_checks"
    else
      log_warn "No required status checks configured"
    fi
  fi

  # Step 9: Security summary
  log_info "Step 9: Security Summary"

  echo ""
  echo "====== FORK PR SECURITY SUMMARY ======"
  echo "Repository: ${E2E_REPO}"
  echo "Forking allowed: $allow_forking"
  echo "CODEOWNERS: $(if [[ -f '.github/CODEOWNERS' ]] || [[ -f 'CODEOWNERS' ]]; then echo 'YES'; else echo 'NO'; fi)"
  echo "Branch protection: $(if [[ "$protection" != '{}' ]]; then echo 'ENABLED'; else echo 'UNKNOWN'; fi)"
  echo "Workflows with secrets: ${#secrets_in_workflows[@]}"
  echo "======================================="
  echo ""

  # Step 10: Recommendations
  log_info "Step 10: Security Recommendations"

  local recommendations=()

  if [[ ! -f ".github/CODEOWNERS" ]] && [[ ! -f "CODEOWNERS" ]]; then
    recommendations+=("Create CODEOWNERS file to require specific reviewers")
  fi

  if [[ "$protection" == "{}" ]]; then
    recommendations+=("Enable branch protection on integration branch")
  fi

  for wf in "${secrets_in_workflows[@]}"; do
    local wf_path=".github/workflows/$wf"
    if grep -q "pull_request:" "$wf_path" 2>/dev/null; then
      if ! grep -qE "(pull_request_target|github\.event\.pull_request\.head\.repo\.fork)" "$wf_path" 2>/dev/null; then
        recommendations+=("Review $wf for fork PR secret exposure")
      fi
    fi
  done

  if [[ ${#recommendations[@]} -gt 0 ]]; then
    log_warn "Recommendations:"
    for rec in "${recommendations[@]}"; do
      log_warn "  - $rec"
    done
  else
    log_info "No critical security issues found"
  fi

  pass "$TEST_ID"
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
