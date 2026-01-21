#!/usr/bin/env bash
# Relationship Determination Library
#
# Implements the 5-tier relationship system for determining how files
# relate to each other in the atomization workflow.
#
# Tiers (in order of precedence):
#   1. Config File - Defined in atomic-branches.json charts[].related
#   2. Frontmatter - YAML frontmatter in markdown files
#   3. Commit Footer - related: trailers in commit messages
#   4. Conventional Commit Scope - feat(scope): ...
#   5. Same Commit - Files changed in the same commit
#
# Usage:
#   source .github/actions/atomize/lib/relationships.sh
#   check_tier1_relationship "docs/file.md" "cloudflared"
#   determine_relationship "docs/file.md" "cloudflared"

set -euo pipefail

# Source the main atomize library if not already loaded
if ! declare -f get_chart_related &>/dev/null; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/atomize.sh"
fi

# =============================================================================
# Tier 1: Config File Relationships
# =============================================================================

# Check if a file is related to a chart via config file (Tier 1)
# Usage: check_tier1_relationship <file_path> <chart_name>
# Returns: "tier1:config" if related, empty string if not
check_tier1_relationship() {
  local file_path="$1"
  local chart_name="$2"
  local config_file="${ATOMIZE_CONFIG_FILE:-.github/actions/configs/atomic-branches.json}"

  # Get related patterns for the chart
  local related_patterns
  related_patterns=$(get_chart_related "$chart_name" "$config_file")

  if [[ -z "$related_patterns" ]]; then
    echo ""
    return 0
  fi

  # Check if file matches any related pattern
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue

    if _matches_glob_pattern "$file_path" "$pattern"; then
      echo "tier1:config"
      return 0
    fi
  done <<< "$related_patterns"

  echo ""
  return 0
}

# Get all charts that a file is related to via config (Tier 1)
# Usage: get_related_charts_for_file <file_path>
# Returns: Space-separated list of chart names
get_related_charts_for_file() {
  local file_path="$1"
  local config_file="${ATOMIZE_CONFIG_FILE:-.github/actions/configs/atomic-branches.json}"

  local related_charts=()

  # Get all chart names
  local chart_names
  chart_names=$(jq -r '.charts[].name // empty' "$config_file")

  while IFS= read -r chart_name; do
    [[ -z "$chart_name" ]] && continue

    local result
    result=$(check_tier1_relationship "$file_path" "$chart_name")

    if [[ -n "$result" ]]; then
      related_charts+=("$chart_name")
    fi
  done <<< "$chart_names"

  if [[ ${#related_charts[@]} -gt 0 ]]; then
    printf '%s\n' "${related_charts[@]}"
  else
    echo ""
  fi
}

# =============================================================================
# Tier 2: Frontmatter Relationships
# =============================================================================

# Parse frontmatter from a markdown file
# Usage: parse_frontmatter <file_path>
# Returns: YAML frontmatter content (without delimiters)
parse_frontmatter() {
  local file_path="$1"

  if [[ ! -f "$file_path" ]]; then
    echo ""
    return 0
  fi

  # Extract content between --- delimiters
  sed -n '/^---$/,/^---$/p' "$file_path" | sed '1d;$d'
}

# Check if a file is related to a chart via frontmatter (Tier 2)
# Usage: check_tier2_relationship <file_path> <chart_name>
# Returns: "tier2:frontmatter" if related, empty string if not
check_tier2_relationship() {
  local file_path="$1"
  local chart_name="$2"

  # Only process markdown files
  if [[ "$file_path" != *.md ]]; then
    echo ""
    return 0
  fi

  local frontmatter
  frontmatter=$(parse_frontmatter "$file_path")

  if [[ -z "$frontmatter" ]]; then
    echo ""
    return 0
  fi

  # Check if related.charts contains the chart name
  # Uses yq if available, falls back to grep
  if command -v yq &>/dev/null; then
    local related_charts
    related_charts=$(echo "$frontmatter" | yq '.related.charts[]' 2>/dev/null || echo "")

    if echo "$related_charts" | grep -qx "$chart_name"; then
      echo "tier2:frontmatter"
      return 0
    fi
  else
    # Fallback: simple grep for the chart name in related section
    if echo "$frontmatter" | grep -q "related:" && echo "$frontmatter" | grep -q "$chart_name"; then
      echo "tier2:frontmatter"
      return 0
    fi
  fi

  echo ""
  return 0
}

# Get related charts from frontmatter
# Usage: get_frontmatter_related_charts <file_path>
# Returns: Newline-separated list of chart names
get_frontmatter_related_charts() {
  local file_path="$1"

  local frontmatter
  frontmatter=$(parse_frontmatter "$file_path")

  if [[ -z "$frontmatter" ]]; then
    echo ""
    return 0
  fi

  if command -v yq &>/dev/null; then
    echo "$frontmatter" | yq '.related.charts[]' 2>/dev/null || echo ""
  else
    echo ""
  fi
}

# =============================================================================
# Tier 3: Commit Footer Relationships
# =============================================================================

# Parse related footers from a commit message
# Usage: parse_commit_footer_related <commit_message>
# Returns: Newline-separated list of related paths/patterns
parse_commit_footer_related() {
  local commit_message="$1"

  # Extract related: trailers (case-insensitive)
  echo "$commit_message" | grep -iE '^related:[[:space:]]*' | sed -E 's/^[Rr]elated:[[:space:]]*//'
}

# Check if a file is related via commit footer (Tier 3)
# Usage: check_tier3_relationship <file_path> <commit_message>
# Returns: "tier3:footer" if related, empty string if not
check_tier3_relationship() {
  local file_path="$1"
  local commit_message="$2"

  local related_patterns
  related_patterns=$(parse_commit_footer_related "$commit_message")

  if [[ -z "$related_patterns" ]]; then
    echo ""
    return 0
  fi

  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue

    if _matches_glob_pattern "$file_path" "$pattern"; then
      echo "tier3:footer"
      return 0
    fi
  done <<< "$related_patterns"

  echo ""
  return 0
}

# Parse requires: footer from commit message
# Usage: parse_commit_footer_requires <commit_message>
# Returns: UUID if present, empty string if not
parse_commit_footer_requires() {
  local commit_message="$1"

  # Extract requires: trailer value
  local requires_value
  requires_value=$(echo "$commit_message" | grep -iE '^requires:[[:space:]]*' | sed -E 's/^[Rr]equires:[[:space:]]*//' | head -1)

  if [[ -z "$requires_value" ]]; then
    echo ""
    return 0
  fi

  # Validate UUID format
  if validate_uuid "$requires_value"; then
    echo "$requires_value"
  else
    echo ""
  fi
}

# Parse requires(<file>): footer from commit message
# Usage: parse_commit_footer_requires_file <commit_message>
# Returns: JSON array of {file, requires} pairs
parse_commit_footer_requires_file() {
  local commit_message="$1"

  local result="[]"

  # Match requires(<file>): <required_file> patterns
  # Use a regex variable to avoid bash parsing issues with parentheses
  local requires_pattern='^[Rr]equires\(([^)]+)\):[[:space:]]*(.+)$'
  while IFS= read -r line; do
    if [[ "$line" =~ $requires_pattern ]]; then
      local file="${BASH_REMATCH[1]}"
      local requires="${BASH_REMATCH[2]}"
      result=$(echo "$result" | jq --arg f "$file" --arg r "$requires" '. + [{"file": $f, "requires": $r}]')
    fi
  done <<< "$commit_message"

  echo "$result"
}

# =============================================================================
# Tier 4: Conventional Commit Scope
# =============================================================================

# Parse scope from conventional commit message
# Usage: parse_commit_scope <commit_message>
# Returns: Scope string if present, empty string if not
parse_commit_scope() {
  local commit_message="$1"

  # Get first line (subject)
  local subject
  subject=$(echo "$commit_message" | head -1)

  # Match conventional commit format: type(scope)!?: description
  # The !? handles optional breaking change marker
  # Use a regex variable to avoid bash parsing issues with parentheses
  local scope_pattern='^[a-z]+\(([^)]+)\)!?:[[:space:]]'
  if [[ "$subject" =~ $scope_pattern ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo ""
  fi
}

# Check if scope matches a chart name (Tier 4)
# Usage: check_tier4_relationship <commit_message> <chart_name>
# Returns: "tier4:scope" if related, empty string if not
check_tier4_relationship() {
  local commit_message="$1"
  local chart_name="$2"

  local scope
  scope=$(parse_commit_scope "$commit_message")

  if [[ "$scope" == "$chart_name" ]]; then
    echo "tier4:scope"
    return 0
  fi

  echo ""
  return 0
}

# =============================================================================
# Tier 5: Same Commit Grouping
# =============================================================================

# Group files from the same commit (Tier 5)
# Usage: get_tier5_grouping <commit_sha>
# Returns: Newline-separated list of files in the commit
get_tier5_grouping() {
  local commit_sha="$1"

  git diff-tree --no-commit-id --name-only -r "$commit_sha" 2>/dev/null || echo ""
}

# Check if two files are in the same commit (Tier 5)
# Usage: check_tier5_relationship <file1> <file2> <commit_sha>
# Returns: "tier5:commit" if both in same commit, empty string if not
check_tier5_relationship() {
  local file1="$1"
  local file2="$2"
  local commit_sha="$3"

  local files_in_commit
  files_in_commit=$(get_tier5_grouping "$commit_sha")

  if echo "$files_in_commit" | grep -qFx "$file1" && \
     echo "$files_in_commit" | grep -qFx "$file2"; then
    echo "tier5:commit"
    return 0
  fi

  echo ""
  return 0
}

# =============================================================================
# Unified Relationship Determination
# =============================================================================

# Determine relationship tier between a file and a chart
# Usage: determine_relationship <file_path> <chart_name> [commit_message] [commit_sha]
# Returns: Highest tier relationship found (e.g., "tier1:config")
determine_relationship() {
  local file_path="$1"
  local chart_name="$2"
  local commit_message="${3:-}"
  local commit_sha="${4:-}"

  # Tier 1: Config file
  local tier1
  tier1=$(check_tier1_relationship "$file_path" "$chart_name")
  if [[ -n "$tier1" ]]; then
    echo "$tier1"
    return 0
  fi

  # Tier 2: Frontmatter
  local tier2
  tier2=$(check_tier2_relationship "$file_path" "$chart_name")
  if [[ -n "$tier2" ]]; then
    echo "$tier2"
    return 0
  fi

  # Tier 3: Commit footer (requires commit message)
  if [[ -n "$commit_message" ]]; then
    local tier3
    tier3=$(check_tier3_relationship "$file_path" "$commit_message")
    if [[ -n "$tier3" ]]; then
      echo "$tier3"
      return 0
    fi
  fi

  # Tier 4: Conventional commit scope (requires commit message)
  if [[ -n "$commit_message" ]]; then
    local tier4
    tier4=$(check_tier4_relationship "$commit_message" "$chart_name")
    if [[ -n "$tier4" ]]; then
      echo "$tier4"
      return 0
    fi
  fi

  # Tier 5 is handled separately (compares two files, not file-to-chart)

  echo ""
  return 0
}

# =============================================================================
# Internal Helpers
# =============================================================================

# Check if a file path matches a glob pattern
# Usage: _matches_glob_pattern <file_path> <pattern>
# Returns: 0 if matches, 1 if not
_matches_glob_pattern() {
  local file_path="$1"
  local pattern="$2"

  # Convert glob to regex:
  # - * becomes [^/]* (match within directory)
  # - ** becomes .* (match across directories)
  # - . becomes \. (literal dot)
  local regex
  regex=$(echo "$pattern" | sed -E 's/\./\\./g; s/\*\*/.*/g; s/\*/[^\/]*/g')
  regex="^${regex}$"

  if [[ "$file_path" =~ $regex ]]; then
    return 0
  else
    return 1
  fi
}

# =============================================================================
# Exports
# =============================================================================

export -f check_tier1_relationship
export -f get_related_charts_for_file
export -f parse_frontmatter
export -f check_tier2_relationship
export -f get_frontmatter_related_charts
export -f parse_commit_footer_related
export -f check_tier3_relationship
export -f parse_commit_footer_requires
export -f parse_commit_footer_requires_file
export -f parse_commit_scope
export -f check_tier4_relationship
export -f get_tier5_grouping
export -f check_tier5_relationship
export -f determine_relationship
