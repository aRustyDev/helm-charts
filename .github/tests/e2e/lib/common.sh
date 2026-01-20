#!/usr/bin/env bash
# E2E Test Common Library
# Provides shared functions for E2E test automation

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

export E2E_TIMEOUT=${E2E_TIMEOUT:-600}      # Default 10 minute timeout
export E2E_INTERVAL=${E2E_INTERVAL:-30}      # Default 30 second poll interval
export E2E_REPO=${E2E_REPO:-aRustyDev/helm-charts}
export E2E_CHART=${E2E_CHART:-test-workflow} # Default chart for testing
export E2E_LOG_LEVEL=${E2E_LOG_LEVEL:-INFO}  # DEBUG, INFO, WARN, ERROR
export E2E_MOCK=${E2E_MOCK:-false}           # Enable mock mode for local testing

# =============================================================================
# Colors (disabled if NO_COLOR is set or not a terminal)
# =============================================================================

if [[ -z "${NO_COLOR:-}" ]] && [[ -t 1 ]]; then
  export RED='\033[0;31m'
  export GREEN='\033[0;32m'
  export YELLOW='\033[0;33m'
  export BLUE='\033[0;34m'
  export NC='\033[0m'  # No Color
else
  export RED=''
  export GREEN=''
  export YELLOW=''
  export BLUE=''
  export NC=''
fi

# =============================================================================
# Logging Functions
# =============================================================================

_log_level_num() {
  case "$1" in
    DEBUG) echo 0 ;;
    INFO)  echo 1 ;;
    WARN)  echo 2 ;;
    ERROR) echo 3 ;;
    *)     echo 1 ;;
  esac
}

_should_log() {
  local level="$1"
  local current=$(_log_level_num "$E2E_LOG_LEVEL")
  local requested=$(_log_level_num "$level")
  [[ $requested -ge $current ]]
}

log() {
  echo "[$(date +%H:%M:%S)] $*"
}

log_debug() {
  _should_log "DEBUG" && echo "[$(date +%H:%M:%S)] DEBUG: $*" || true
}

log_info() {
  _should_log "INFO" && echo "[$(date +%H:%M:%S)] INFO: $*" || true
}

log_warn() {
  _should_log "WARN" && echo "[$(date +%H:%M:%S)] WARN: $*" >&2 || true
}

log_error() {
  _should_log "ERROR" && echo "[$(date +%H:%M:%S)] ERROR: $*" >&2 || true
}

log_section() {
  local title="$1"
  echo ""
  echo "================================================================"
  echo " $title"
  echo "================================================================"
  echo ""
}

# =============================================================================
# Assertion Functions
# =============================================================================

assert_on_branch() {
  local expected="$1"
  local current
  current=$(git branch --show-current)
  if [[ "$current" != "$expected" ]]; then
    log_error "Expected branch '$expected' but on '$current'"
    return 1
  fi
}

assert_on_integration() {
  assert_on_branch "integration"
}

assert_on_main() {
  assert_on_branch "main"
}

assert_clean_working_tree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    log_error "Working tree not clean"
    git status --short >&2
    return 1
  fi
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="${3:-Values should be equal}"
  if [[ "$actual" != "$expected" ]]; then
    log_error "ASSERTION FAILED: $message"
    log_error "  Expected: '$expected'"
    log_error "  Actual:   '$actual'"
    return 1
  fi
}

assert_not_empty() {
  local value="$1"
  local name="${2:-value}"
  if [[ -z "$value" ]]; then
    log_error "ASSERTION FAILED: $name is empty"
    return 1
  fi
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  local message="${3:-String should contain substring}"
  if [[ "$haystack" != *"$needle"* ]]; then
    log_error "ASSERTION FAILED: $message"
    log_error "  Looking for: '$needle'"
    log_error "  In string:   '$haystack'"
    return 1
  fi
}

assert_file_exists() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    log_error "File not found: $file"
    return 1
  fi
}

assert_dir_exists() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    log_error "Directory not found: $dir"
    return 1
  fi
}

assert_codeowners_member() {
  local user
  user=$(gh api user --jq '.login' 2>/dev/null || echo "")
  if [[ -z "$user" ]]; then
    log_warn "Could not determine GitHub user"
    return 0
  fi

  local codeowners=""
  if [[ -f ".github/CODEOWNERS" ]]; then
    codeowners=".github/CODEOWNERS"
  elif [[ -f "CODEOWNERS" ]]; then
    codeowners="CODEOWNERS"
  fi

  if [[ -n "$codeowners" ]] && ! grep -q "@$user" "$codeowners" 2>/dev/null; then
    log_warn "$user may not be in CODEOWNERS - auto-merge may not enable"
  fi
}

assert_gh_cli_available() {
  if ! command -v gh &>/dev/null; then
    log_error "GitHub CLI (gh) not found"
    return 1
  fi
  if ! gh auth status &>/dev/null; then
    log_error "GitHub CLI not authenticated"
    return 1
  fi
}

assert_gpg_available() {
  if ! command -v gpg &>/dev/null; then
    log_warn "GPG not found - signed commits may fail"
    return 0
  fi
}

# =============================================================================
# Git Helper Functions
# =============================================================================

get_current_branch() {
  git branch --show-current
}

get_current_sha() {
  git rev-parse HEAD
}

get_short_sha() {
  git rev-parse --short HEAD
}

branch_exists() {
  local branch="$1"
  local scope="${2:-local}"  # local, remote, or all

  case "$scope" in
    local)
      git show-ref --verify --quiet "refs/heads/$branch"
      ;;
    remote)
      git show-ref --verify --quiet "refs/remotes/origin/$branch"
      ;;
    all)
      git show-ref --quiet "refs/heads/$branch" || git show-ref --quiet "refs/remotes/origin/$branch"
      ;;
  esac
}

tag_exists() {
  local tag="$1"
  git rev-parse "$tag" >/dev/null 2>&1
}

create_test_branch() {
  local prefix="$1"
  local branch="${prefix}-$(date +%Y%m%d%H%M%S)"
  git checkout -b "$branch"
  echo "$branch"
}

delete_branch() {
  local branch="$1"
  local scope="${2:-both}"  # local, remote, or both

  case "$scope" in
    local)
      git branch -D "$branch" 2>/dev/null || true
      ;;
    remote)
      git push origin --delete "$branch" 2>/dev/null || true
      ;;
    both)
      git branch -D "$branch" 2>/dev/null || true
      git push origin --delete "$branch" 2>/dev/null || true
      ;;
  esac
}

# =============================================================================
# GitHub API Functions
# =============================================================================

create_pr() {
  local base="$1"
  local title="$2"
  local body="${3:-Automated E2E test}"

  # Mock mode for local testing
  if [[ "${E2E_MOCK:-false}" == "true" ]]; then
    echo "https://github.com/$E2E_REPO/pull/999"
    return 0
  fi

  gh pr create --base "$base" --title "$title" --body "$body"
}

get_pr_number() {
  local branch="$1"
  gh pr list --head "$branch" --json number -q '.[0].number'
}

get_pr_state() {
  local pr_number="$1"

  # Mock mode for local testing
  if [[ "${E2E_MOCK:-false}" == "true" ]]; then
    echo "OPEN"
    return 0
  fi

  gh pr view "$pr_number" --json state -q '.state'
}

get_pr_checks() {
  local pr_number="$1"
  gh pr view "$pr_number" --json statusCheckRollup -q '.statusCheckRollup'
}

get_check_conclusion() {
  local pr_number="$1"
  local check_name="$2"

  # Mock mode for local testing
  if [[ "${E2E_MOCK:-false}" == "true" ]]; then
    echo "success"
    return 0
  fi

  gh pr view "$pr_number" --json statusCheckRollup \
    --jq ".statusCheckRollup[] | select(.name | contains(\"$check_name\")) | .conclusion" | head -1
}

close_pr() {
  local pr_number="$1"
  local delete_branch="${2:-true}"

  if [[ "$delete_branch" == "true" ]]; then
    gh pr close "$pr_number" --delete-branch
  else
    gh pr close "$pr_number"
  fi
}

merge_pr() {
  local pr_number="$1"
  local method="${2:-squash}"  # merge, squash, or rebase

  gh pr merge "$pr_number" "--$method"
}

# =============================================================================
# Workflow Functions
# =============================================================================

get_latest_workflow_run() {
  local workflow="$1"
  gh run list --workflow="$workflow" --limit 1 --json databaseId,status,conclusion \
    -q '.[0]'
}

get_workflow_status() {
  local run_id="$1"
  gh run view "$run_id" --json status,conclusion -q '.status + ":" + (.conclusion // "pending")'
}

wait_for_workflow() {
  local workflow="$1"
  local pr_number="${2:-}"
  local timeout="${3:-$E2E_TIMEOUT}"
  local interval="${4:-$E2E_INTERVAL}"

  # Mock mode for local testing
  if [[ "${E2E_MOCK:-false}" == "true" ]]; then
    log_info "MOCK: Workflow $workflow completed successfully"
    return 0
  fi

  log_info "Waiting for workflow: $workflow"

  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local status=""

    if [[ -n "$pr_number" ]]; then
      # Get status from PR checks
      status=$(gh pr view "$pr_number" --json statusCheckRollup \
        --jq ".statusCheckRollup[] | select(.name | contains(\"$workflow\")) | .conclusion" 2>/dev/null | head -1)
    else
      # Get status from latest workflow run
      status=$(gh run list --workflow="$workflow.yaml" --limit 1 --json conclusion -q '.[0].conclusion' 2>/dev/null)
    fi

    case "$status" in
      success|SUCCESS)
        log_info "$workflow completed successfully"
        return 0
        ;;
      failure|FAILURE)
        log_error "$workflow failed"
        return 1
        ;;
      cancelled|CANCELLED)
        log_error "$workflow was cancelled"
        return 1
        ;;
    esac

    sleep "$interval"
    elapsed=$((elapsed + interval))
    log_debug "Waiting for $workflow... ($elapsed/${timeout}s)"
  done

  log_error "Timeout waiting for $workflow"
  return 1
}

wait_for_merge() {
  local pr_number="$1"
  local timeout="${2:-$E2E_TIMEOUT}"
  local interval="${3:-$E2E_INTERVAL}"

  # Mock mode for local testing
  if [[ "${E2E_MOCK:-false}" == "true" ]]; then
    log_info "MOCK: PR #$pr_number merged"
    return 0
  fi

  log_info "Waiting for PR #$pr_number to merge..."

  local elapsed=0
  while [[ $elapsed -lt $timeout ]]; do
    local state
    state=$(gh pr view "$pr_number" --json state -q '.state')

    case "$state" in
      MERGED)
        log_info "PR #$pr_number merged"
        return 0
        ;;
      CLOSED)
        log_error "PR #$pr_number was closed without merge"
        return 1
        ;;
    esac

    sleep "$interval"
    elapsed=$((elapsed + interval))
    log_debug "Waiting for merge... ($elapsed/${timeout}s) - state: $state"
  done

  log_error "Timeout waiting for merge"
  return 1
}

# =============================================================================
# Release Functions
# =============================================================================

get_latest_release() {
  gh release list --limit 1 --json tagName,name -q '.[0]'
}

get_release_tag() {
  gh release list --limit 1 --json tagName -q '.[0].tagName'
}

release_exists() {
  local tag="$1"
  gh release view "$tag" &>/dev/null
}

verify_attestation() {
  local package="$1"
  local repo="${2:-$E2E_REPO}"

  gh attestation verify "$package" --repo "$repo"
}

verify_cosign() {
  local image="$1"
  local issuer="${2:-https://token.actions.githubusercontent.com}"

  cosign verify "$image" \
    --certificate-oidc-issuer "$issuer" \
    --certificate-identity-regexp "github.com/$E2E_REPO"
}

# =============================================================================
# Test Lifecycle Functions
# =============================================================================

setup_test() {
  local test_id="$1"
  local test_name="$2"

  log_section "Starting $test_id: $test_name"

  # Prerequisites
  assert_gh_cli_available
  assert_clean_working_tree
}

teardown_test() {
  local test_id="$1"
  local branch="${2:-}"

  log_info "Cleaning up $test_id..."

  # Return to integration branch
  git checkout integration 2>/dev/null || true

  # Delete test branch if specified
  if [[ -n "$branch" ]]; then
    delete_branch "$branch" "both"
  fi
}

pass() {
  local test_id="$1"
  log_section "$test_id: PASSED"
  return 0
}

fail() {
  local test_id="$1"
  local message="$2"
  log_error "$message"
  log_section "$test_id: FAILED"
  return 1
}

skip() {
  local test_id="$1"
  local reason="$2"
  log_warn "Skipping: $reason"
  log_section "$test_id: SKIPPED"
  return 0
}

# =============================================================================
# Fixture Functions
# =============================================================================

apply_fixture() {
  local fixture_name="$1"
  local fixture_dir
  fixture_dir="$(dirname "${BASH_SOURCE[0]}")/../fixtures/$fixture_name"

  if [[ ! -d "$fixture_dir" ]]; then
    log_error "Fixture not found: $fixture_name"
    return 1
  fi

  local create_script="$fixture_dir/create.sh"
  if [[ -f "$create_script" ]]; then
    log_info "Applying fixture: $fixture_name"
    bash "$create_script"
  else
    log_warn "No create.sh found for fixture: $fixture_name"
  fi
}

cleanup_fixture() {
  local fixture_name="$1"
  local fixture_dir
  fixture_dir="$(dirname "${BASH_SOURCE[0]}")/../fixtures/$fixture_name"

  local cleanup_script="$fixture_dir/cleanup.sh"
  if [[ -f "$cleanup_script" ]]; then
    log_info "Cleaning up fixture: $fixture_name"
    bash "$cleanup_script"
  fi
}

# =============================================================================
# Validation Functions
# =============================================================================

validate_chart_exists() {
  local chart="$1"
  assert_dir_exists "charts/$chart"
  assert_file_exists "charts/$chart/Chart.yaml"
}

validate_release_created() {
  local tag="$1"

  if ! release_exists "$tag"; then
    log_error "Release not found: $tag"
    return 1
  fi

  log_info "Release verified: $tag"
}

validate_branch_created() {
  local branch="$1"

  git fetch origin --prune

  if ! branch_exists "$branch" "remote"; then
    log_error "Branch not found: $branch"
    return 1
  fi

  log_info "Branch verified: $branch"
}

validate_pr_created() {
  local base="$1"
  local head="$2"

  local pr_number
  pr_number=$(gh pr list --base "$base" --head "$head" --json number -q '.[0].number')

  if [[ -z "$pr_number" ]]; then
    log_error "PR not found: $head -> $base"
    return 1
  fi

  log_info "PR verified: #$pr_number ($head -> $base)"
  echo "$pr_number"
}

# =============================================================================
# Mock Functions (for local testing without GitHub)
# =============================================================================

mock_gh_available() {
  export E2E_MOCK_MODE=true
}

mock_workflow_success() {
  local workflow="$1"
  export "E2E_MOCK_${workflow//-/_}_RESULT"=success
}

mock_workflow_failure() {
  local workflow="$1"
  export "E2E_MOCK_${workflow//-/_}_RESULT"=failure
}

is_mock_mode() {
  [[ "${E2E_MOCK_MODE:-false}" == "true" ]]
}
