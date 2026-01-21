#!/usr/bin/env bash
# Atomization Library
#
# Core functions for the atomization workflow that extracts content from
# integration PRs into atomic branches.
#
# Usage:
#   source .github/actions/atomize/lib/atomize.sh
#   validate_config "path/to/config.json"
#   match_branch_pattern "charts/cloudflared/values.yaml"

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

# Default paths
ATOMIZE_CONFIG_FILE="${ATOMIZE_CONFIG_FILE:-.github/actions/configs/atomic-branches.json}"
ATOMIZE_SCHEMA_FILE="${ATOMIZE_SCHEMA_FILE:-.github/actions/configs/atomic-branches.schema.json}"

# =============================================================================
# Validation Functions
# =============================================================================

# Validate a config file against the JSON schema
# Usage: validate_config <config_file> [schema_file]
# Returns: 0 if valid, 1 if invalid
validate_config() {
  local config_file="${1:-$ATOMIZE_CONFIG_FILE}"
  local schema_file="${2:-$ATOMIZE_SCHEMA_FILE}"

  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: Config file not found: $config_file" >&2
    return 1
  fi

  if [[ ! -f "$schema_file" ]]; then
    echo "ERROR: Schema file not found: $schema_file" >&2
    return 1
  fi

  # Validate JSON syntax first
  if ! jq empty "$config_file" 2>/dev/null; then
    echo "ERROR: Invalid JSON syntax in: $config_file" >&2
    return 1
  fi

  # Use check-jsonschema if available (preferred)
  if command -v check-jsonschema &>/dev/null; then
    if ! check-jsonschema --schemafile "$schema_file" "$config_file" 2>&1; then
      return 1
    fi
    return 0
  fi

  # Fallback to ajv if available
  if command -v ajv &>/dev/null; then
    if ! ajv validate -s "$schema_file" -d "$config_file" 2>&1; then
      return 1
    fi
    return 0
  fi

  # Manual validation as last resort
  echo "WARN: No JSON schema validator found, performing basic validation" >&2
  _validate_config_manual "$config_file"
}

# Manual validation when no schema validator is available
_validate_config_manual() {
  local config_file="$1"

  # Check required 'branches' field exists and is array
  if ! jq -e '.branches | type == "array"' "$config_file" >/dev/null 2>&1; then
    echo "ERROR: missing required property: branches" >&2
    return 1
  fi

  # Check branches array is not empty
  if ! jq -e '.branches | length > 0' "$config_file" >/dev/null 2>&1; then
    echo "ERROR: branches array must not be empty" >&2
    return 1
  fi

  # Validate each branch entry
  local branch_count
  branch_count=$(jq '.branches | length' "$config_file")

  for ((i=0; i<branch_count; i++)); do
    # Check required fields
    if ! jq -e ".branches[$i].name" "$config_file" >/dev/null 2>&1; then
      echo "ERROR: branches[$i] missing required property: name" >&2
      return 1
    fi
    if ! jq -e ".branches[$i].prefix" "$config_file" >/dev/null 2>&1; then
      echo "ERROR: branches[$i] missing required property: prefix" >&2
      return 1
    fi
    if ! jq -e ".branches[$i].pattern" "$config_file" >/dev/null 2>&1; then
      echo "ERROR: branches[$i] missing required property: pattern" >&2
      return 1
    fi

    # Validate name pattern (must start with $ for variables or be lowercase)
    local name
    name=$(jq -r ".branches[$i].name" "$config_file")
    if [[ ! "$name" =~ ^(\$[a-z_]+|[a-z][a-z0-9_-]*)$ ]]; then
      echo "ERROR: branches[$i].name invalid pattern: $name" >&2
      return 1
    fi

    # Check consistency between capture groups and name variables
    local pattern
    pattern=$(jq -r ".branches[$i].pattern" "$config_file")

    # If pattern has a named capture group, name should reference it with $
    if [[ "$pattern" =~ \(\?P\<([a-z_]+)\> ]]; then
      local capture_name="${BASH_REMATCH[1]}"
      # If pattern has capture group, name should start with $ to use it
      if [[ "$name" != \$* ]]; then
        echo "ERROR: branches[$i].name should be '\$$capture_name' to match capture group in pattern" >&2
        return 1
      fi
    fi

    # Validate prefix pattern (must end with /)
    local prefix
    prefix=$(jq -r ".branches[$i].prefix" "$config_file")
    if [[ ! "$prefix" =~ /$ ]]; then
      echo "ERROR: branches[$i].prefix must end with /: $prefix" >&2
      return 1
    fi
  done

  # Validate charts if present
  if jq -e '.charts' "$config_file" >/dev/null 2>&1; then
    local chart_count
    chart_count=$(jq '.charts | length' "$config_file")

    for ((i=0; i<chart_count; i++)); do
      # Check required name field
      if ! jq -e ".charts[$i].name" "$config_file" >/dev/null 2>&1; then
        echo "ERROR: charts[$i] missing required property: name" >&2
        return 1
      fi

      # Validate priority if present (must be >= 1)
      if jq -e ".charts[$i].priority" "$config_file" >/dev/null 2>&1; then
        local priority
        priority=$(jq ".charts[$i].priority" "$config_file")
        if [[ "$priority" -lt 1 ]]; then
          echo "ERROR: charts[$i].priority must be >= 1: $priority" >&2
          return 1
        fi
      fi
    done
  fi

  return 0
}

# =============================================================================
# Pattern Matching Functions
# =============================================================================

# Match a file path against configured branch patterns
# Usage: match_branch_pattern <file_path> [config_file]
# Returns: Branch name on stdout, or empty string if no match
match_branch_pattern() {
  local file_path="$1"
  local config_file="${2:-$ATOMIZE_CONFIG_FILE}"

  if [[ ! -f "$config_file" ]]; then
    echo "ERROR: Config file not found: $config_file" >&2
    return 1
  fi

  # Read branch patterns from config
  # Use tab as delimiter since | appears in regex patterns
  local patterns
  patterns=$(jq -r '.branches[] | "\(.pattern)\t\(.prefix)\t\(.name)"' "$config_file")

  while IFS=$'\t' read -r pattern prefix name; do
    [[ -z "$pattern" ]] && continue

    # Try to match with the pattern
    local branch_name
    branch_name=$(_try_pattern_match "$file_path" "$pattern" "$prefix" "$name")

    if [[ -n "$branch_name" ]]; then
      echo "$branch_name"
      return 0
    fi
  done <<< "$patterns"

  # No match found
  echo ""
  return 0
}

# Internal: Try to match a file path against a single pattern
_try_pattern_match() {
  local file_path="$1"
  local pattern="$2"
  local prefix="$3"
  local name="$4"

  # Extract named capture group name from pattern (e.g., (?P<chart>...) -> chart)
  # Use regex variable to avoid bash parsing issues with angle brackets
  local capture_name=""
  local capture_regex='\(\?P<([^>]+)>'
  if [[ "$pattern" =~ $capture_regex ]]; then
    capture_name="${BASH_REMATCH[1]}"
  fi

  # Convert Python-style regex to bash-compatible:
  # 1. Convert (?P<name>...) to (...) - keep the capture group content
  # 2. Convert ** to .* for glob-like matching
  local bash_pattern
  # Replace (?P<name> with just ( to convert Python named groups to bash groups
  bash_pattern=$(echo "$pattern" | sed -E 's/\(\?P<[^>]+>/(/g')
  bash_pattern=$(echo "$bash_pattern" | sed 's/\*\*/.*/g')

  # Try to match
  if [[ "$file_path" =~ $bash_pattern ]]; then
    local captured="${BASH_REMATCH[1]:-}"

    if [[ -n "$captured" ]] && [[ "$name" == \$* ]]; then
      # Variable substitution - use captured value
      echo "${prefix}${captured}"
      return 0
    elif [[ "$name" != \$* ]]; then
      # Static name
      echo "${prefix}${name}"
      return 0
    fi
  fi

  # No match
  echo ""
  return 0
}

# Get all branch patterns from config
# Usage: get_branch_patterns [config_file]
# Returns: JSON array of patterns
get_branch_patterns() {
  local config_file="${1:-$ATOMIZE_CONFIG_FILE}"
  jq '.branches' "$config_file"
}

# Get all chart configurations from config
# Usage: get_chart_configs [config_file]
# Returns: JSON array of charts
get_chart_configs() {
  local config_file="${1:-$ATOMIZE_CONFIG_FILE}"
  jq '.charts // []' "$config_file"
}

# Get related paths for a specific chart
# Usage: get_chart_related <chart_name> [config_file]
# Returns: Array of related path patterns
get_chart_related() {
  local chart_name="$1"
  local config_file="${2:-$ATOMIZE_CONFIG_FILE}"

  jq -r --arg name "$chart_name" \
    '.charts[] | select(.name == $name) | .related // [] | .[]' \
    "$config_file"
}

# Get priority for a specific chart
# Usage: get_chart_priority <chart_name> [config_file]
# Returns: Priority number (default 100 if not set)
get_chart_priority() {
  local chart_name="$1"
  local config_file="${2:-$ATOMIZE_CONFIG_FILE}"

  local priority
  priority=$(jq -r --arg name "$chart_name" \
    '.charts[] | select(.name == $name) | .priority // 100' \
    "$config_file")

  echo "${priority:-100}"
}

# =============================================================================
# File Categorization Functions
# =============================================================================

# Categorize a list of files into their respective branches
# Usage: categorize_files <file_list> [config_file]
# Input: Newline-separated list of file paths
# Returns: JSON object mapping branch names to file arrays
categorize_files() {
  local file_list="$1"
  local config_file="${2:-$ATOMIZE_CONFIG_FILE}"

  local result="{}"

  while IFS= read -r file; do
    [[ -z "$file" ]] && continue

    local branch
    branch=$(match_branch_pattern "$file" "$config_file")

    if [[ -n "$branch" ]]; then
      # Add file to branch's array
      result=$(echo "$result" | jq --arg branch "$branch" --arg file "$file" \
        '.[$branch] = ((.[$branch] // []) + [$file])')
    else
      # No match - goes to DLQ
      result=$(echo "$result" | jq --arg file "$file" \
        '.["dlq"] = ((.["dlq"] // []) + [$file])')
    fi
  done <<< "$file_list"

  echo "$result"
}

# =============================================================================
# UUID Validation
# =============================================================================

# Validate a UUID format
# Usage: validate_uuid <uuid>
# Returns: 0 if valid, 1 if invalid
validate_uuid() {
  local uuid="$1"
  local uuid_regex='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'

  if [[ "$uuid" =~ $uuid_regex ]]; then
    return 0
  else
    return 1
  fi
}

# =============================================================================
# Exports
# =============================================================================

# Export all public functions
export -f validate_config
export -f match_branch_pattern
export -f get_branch_patterns
export -f get_chart_configs
export -f get_chart_related
export -f get_chart_priority
export -f categorize_files
export -f validate_uuid
