#!/usr/bin/env bash
# Trust Check Library
#
# Core functions for validating contributor trust based on CODEOWNERS
# and commit signature verification.
#
# Usage:
#   source .github/actions/trust-check/lib/trust-check.sh
#   check_codeowners_trust "username"
#   is_dependabot_pr "username"
#   verify_commit_signature "sha"

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# CODEOWNERS file locations to check (in order of precedence)
CODEOWNERS_LOCATIONS=(
  "CODEOWNERS"
  ".github/CODEOWNERS"
  "docs/CODEOWNERS"
)

# =============================================================================
# CODEOWNERS Trust Functions
# =============================================================================

# Check if a user is listed in CODEOWNERS
# Usage: check_codeowners_trust <username> [codeowners_file]
# Returns: 0 if trusted, 1 if not trusted
check_codeowners_trust() {
  local username="$1"
  local codeowners_file="${2:-}"

  if [[ -z "$username" ]]; then
    echo "ERROR: Username is required" >&2
    return 1
  fi

  # If specific file provided, check only that
  if [[ -n "$codeowners_file" ]]; then
    if [[ -f "$codeowners_file" ]]; then
      if grep -q "@${username}" "$codeowners_file" 2>/dev/null; then
        return 0
      fi
    fi
    return 1
  fi

  # Check all standard CODEOWNERS locations
  for location in "${CODEOWNERS_LOCATIONS[@]}"; do
    if [[ -f "$location" ]]; then
      if grep -q "@${username}" "$location" 2>/dev/null; then
        return 0
      fi
    fi
  done

  return 1
}

# Find and return the CODEOWNERS file path
# Usage: find_codeowners_file
# Returns: Path to CODEOWNERS file or empty string
find_codeowners_file() {
  for location in "${CODEOWNERS_LOCATIONS[@]}"; do
    if [[ -f "$location" ]]; then
      echo "$location"
      return 0
    fi
  done
  echo ""
  return 1
}

# Parse CODEOWNERS file and return all listed usernames
# Usage: get_codeowners_users [codeowners_file]
# Returns: Newline-separated list of usernames (without @)
get_codeowners_users() {
  local codeowners_file="${1:-}"

  if [[ -z "$codeowners_file" ]]; then
    codeowners_file=$(find_codeowners_file) || return 1
  fi

  if [[ ! -f "$codeowners_file" ]]; then
    return 1
  fi

  # Extract all @mentions, remove @ prefix, remove duplicates
  grep -oE '@[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)?' "$codeowners_file" 2>/dev/null | \
    sed 's/^@//' | \
    sort -u
}

# Check if a user is in a specific CODEOWNERS team
# Usage: check_team_membership <username> <team> [org]
# Returns: 0 if member, 1 if not (requires gh CLI)
check_team_membership() {
  local username="$1"
  local team="$2"
  local org="${3:-}"

  if [[ -z "$org" ]]; then
    # Try to extract org from current repo
    if command -v gh &>/dev/null; then
      org=$(gh repo view --json owner -q '.owner.login' 2>/dev/null) || true
    fi
  fi

  if [[ -z "$org" ]]; then
    echo "ERROR: Organization is required for team membership check" >&2
    return 1
  fi

  # Check via GitHub API
  if command -v gh &>/dev/null; then
    if gh api "orgs/${org}/teams/${team}/memberships/${username}" &>/dev/null; then
      return 0
    fi
  fi

  return 1
}

# =============================================================================
# Dependabot Detection Functions
# =============================================================================

# Check if the PR author is dependabot
# Usage: is_dependabot_pr <author>
# Returns: 0 if dependabot, 1 if not
is_dependabot_pr() {
  local author="$1"

  case "$author" in
    "dependabot[bot]"|"dependabot-preview[bot]")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Check if the PR is from a known bot
# Usage: is_bot_pr <author>
# Returns: 0 if bot, 1 if not
is_bot_pr() {
  local author="$1"

  # Check for common bot patterns
  if [[ "$author" == *"[bot]" ]]; then
    return 0
  fi

  # Known bots
  case "$author" in
    "dependabot[bot]"|"dependabot-preview[bot]"|"github-actions[bot]"|"renovate[bot]")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# =============================================================================
# Commit Signature Verification Functions
# =============================================================================

# Verify a single commit signature (local git)
# Usage: verify_commit_signature_local <sha>
# Returns: 0 if verified, 1 if not
verify_commit_signature_local() {
  local sha="$1"

  if [[ -z "$sha" ]]; then
    echo "ERROR: Commit SHA is required" >&2
    return 1
  fi

  # Check if commit is signed and valid
  local verify_output
  if verify_output=$(git verify-commit "$sha" 2>&1); then
    return 0
  else
    return 1
  fi
}

# Verify commit signature via GitHub API
# Usage: verify_commit_signature_api <sha> [repo]
# Returns: 0 if verified, 1 if not
verify_commit_signature_api() {
  local sha="$1"
  local repo="${2:-}"

  if [[ -z "$sha" ]]; then
    echo "ERROR: Commit SHA is required" >&2
    return 1
  fi

  if [[ -z "$repo" ]]; then
    if command -v gh &>/dev/null; then
      repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null) || true
    fi
  fi

  if [[ -z "$repo" ]]; then
    echo "ERROR: Repository is required for API verification" >&2
    return 1
  fi

  # Check via GitHub API
  if command -v gh &>/dev/null; then
    local verified
    verified=$(gh api "repos/${repo}/commits/${sha}" --jq '.commit.verification.verified' 2>/dev/null) || return 1

    if [[ "$verified" == "true" ]]; then
      return 0
    fi
  fi

  return 1
}

# Verify all commits in a range are signed
# Usage: verify_commit_range <base_sha> <head_sha>
# Returns: 0 if all verified, 1 if any unverified
verify_commit_range() {
  local base_sha="$1"
  local head_sha="$2"

  if [[ -z "$base_sha" || -z "$head_sha" ]]; then
    echo "ERROR: Base and head SHA are required" >&2
    return 1
  fi

  # Get all commits in range
  local commits
  commits=$(git rev-list "${base_sha}..${head_sha}" 2>/dev/null) || return 1

  if [[ -z "$commits" ]]; then
    # No commits in range
    return 0
  fi

  # Verify each commit
  while IFS= read -r sha; do
    if ! verify_commit_signature_local "$sha"; then
      echo "Unverified commit: $sha" >&2
      return 1
    fi
  done <<< "$commits"

  return 0
}

# =============================================================================
# Branch Filtering Functions
# =============================================================================

# Check if a branch is in the allowed list
# Usage: is_branch_allowed <branch> <allowed_branches_csv>
# Returns: 0 if allowed, 1 if not
is_branch_allowed() {
  local branch="$1"
  local allowed_csv="${2:-integration}"

  if [[ -z "$branch" ]]; then
    echo "ERROR: Branch name is required" >&2
    return 1
  fi

  # Convert CSV to array
  IFS=',' read -ra allowed_branches <<< "$allowed_csv"

  for allowed in "${allowed_branches[@]}"; do
    # Trim whitespace
    allowed=$(echo "$allowed" | xargs)
    if [[ "$branch" == "$allowed" ]]; then
      return 0
    fi
  done

  return 1
}

# =============================================================================
# Combined Trust Check
# =============================================================================

# Perform full trust check for a PR
# Usage: full_trust_check <author> <commits_verified>
# Returns: 0 if trusted, 1 if not
# Output: "TRUSTED" or "UNTRUSTED:<reason>"
full_trust_check() {
  local author="$1"
  local commits_verified="${2:-false}"

  # Step 1: Check signatures first
  if [[ "$commits_verified" != "true" ]]; then
    echo "UNTRUSTED:signatures_not_verified"
    return 1
  fi

  # Step 2: Check if dependabot (special case - skip CODEOWNERS)
  if is_dependabot_pr "$author"; then
    echo "TRUSTED:dependabot"
    return 0
  fi

  # Step 3: Check CODEOWNERS
  if check_codeowners_trust "$author"; then
    echo "TRUSTED:codeowners"
    return 0
  fi

  echo "UNTRUSTED:not_in_codeowners"
  return 1
}

# =============================================================================
# Exports
# =============================================================================

export -f check_codeowners_trust
export -f find_codeowners_file
export -f get_codeowners_users
export -f check_team_membership
export -f is_dependabot_pr
export -f is_bot_pr
export -f verify_commit_signature_local
export -f verify_commit_signature_api
export -f verify_commit_range
export -f is_branch_allowed
export -f full_trust_check
