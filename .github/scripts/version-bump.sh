#!/usr/bin/env bash
# version-bump.sh - Version bumping and changelog generation for Helm charts
#
# This script analyzes conventional commits to determine the appropriate
# semver bump and generates/updates the chart's CHANGELOG.md.
#
# Usage:
#   source .github/scripts/version-bump.sh
#
# Required tools:
#   - git-cliff (for changelog generation)
#   - yq (for YAML manipulation)
#
# Environment variables:
#   GITHUB_OUTPUT - GitHub Actions output file
#   GITHUB_REPOSITORY - owner/repo format

set -euo pipefail

#######################################
# Determine the semver bump type from conventional commits
#
# Arguments:
#   $1 - chart: Chart name to analyze
#   $2 - base_ref: Base branch/ref for comparison (default: origin/main)
#
# Outputs:
#   Bump type: "major", "minor", or "patch"
#######################################
determine_bump_type() {
    local chart="$1"
    local base_ref="${2:-origin/main}"
    local chart_path="charts/$chart"

    # Get commits affecting this chart since base
    local commits
    commits=$(git log --oneline "$base_ref"..HEAD -- "$chart_path" 2>/dev/null || true)

    if [[ -z "$commits" ]]; then
        echo "patch"
        return 0
    fi

    # Check for breaking changes (major bump)
    if echo "$commits" | grep -qiE '(BREAKING[ -]CHANGE|!:)'; then
        echo "major"
        return 0
    fi

    # Check for features (minor bump)
    if echo "$commits" | grep -qE '^[a-f0-9]+ feat'; then
        echo "minor"
        return 0
    fi

    # Default to patch
    echo "patch"
}

#######################################
# Calculate the next version based on bump type
#
# Arguments:
#   $1 - current_version: Current semver (e.g., "1.2.3")
#   $2 - bump_type: "major", "minor", or "patch"
#
# Outputs:
#   Next version string
#######################################
calculate_next_version() {
    local current_version="$1"
    local bump_type="$2"

    # Remove any leading 'v'
    current_version="${current_version#v}"

    # Parse version components
    local major minor patch
    IFS='.' read -r major minor patch <<< "$current_version"

    # Handle pre-release suffixes (e.g., 1.2.3-beta.1)
    patch="${patch%%-*}"

    case "$bump_type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "$major.$((minor + 1)).0"
            ;;
        patch)
            echo "$major.$minor.$((patch + 1))"
            ;;
        *)
            echo "::error::Unknown bump type: $bump_type"
            return 1
            ;;
    esac
}

#######################################
# Get current version from Chart.yaml
#
# Arguments:
#   $1 - chart: Chart name
#
# Outputs:
#   Current version string
#######################################
get_chart_version() {
    local chart="$1"
    local chart_yaml="charts/$chart/Chart.yaml"

    if [[ ! -f "$chart_yaml" ]]; then
        echo "::error::Chart.yaml not found: $chart_yaml"
        return 1
    fi

    grep '^version:' "$chart_yaml" | awk '{print $2}' | tr -d '"' | tr -d "'"
}

#######################################
# Update version in Chart.yaml
#
# Arguments:
#   $1 - chart: Chart name
#   $2 - new_version: New version to set
#
# Returns:
#   0 on success, 1 on failure
#######################################
update_chart_version() {
    local chart="$1"
    local new_version="$2"
    local chart_yaml="charts/$chart/Chart.yaml"

    if [[ ! -f "$chart_yaml" ]]; then
        echo "::error::Chart.yaml not found: $chart_yaml"
        return 1
    fi

    # Use sed for portability (yq changes formatting)
    sed -i "s/^version: .*/version: $new_version/" "$chart_yaml"

    echo "::notice::Updated $chart_yaml to version $new_version"
}

#######################################
# Generate changelog for a chart using git-cliff
#
# Arguments:
#   $1 - chart: Chart name
#   $2 - new_version: Version for the changelog entry
#   $3 - base_ref: Base branch/ref for comparison (default: origin/main)
#
# Returns:
#   0 on success, 1 on failure
#######################################
generate_changelog() {
    local chart="$1"
    local new_version="$2"
    local base_ref="${3:-origin/main}"
    local chart_path="charts/$chart"
    local changelog_file="$chart_path/CHANGELOG.md"

    echo "::group::Generating changelog for $chart v$new_version"

    # Create changelog directory entry if it doesn't exist
    if [[ ! -f "$changelog_file" ]]; then
        cat > "$changelog_file" << 'EOF'
# Changelog

All notable changes to this chart will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

EOF
        echo "::notice::Created new CHANGELOG.md for $chart"
    fi

    # Generate changelog entry for unreleased changes
    local changelog_entry
    changelog_entry=$(git-cliff \
        --config cliff.toml \
        --include-path "$chart_path/**" \
        --unreleased \
        --tag "$chart-v$new_version" \
        --strip header \
        --strip footer \
        2>/dev/null || true)

    if [[ -z "$changelog_entry" || "$changelog_entry" == *"No commits"* ]]; then
        # Fallback: generate simple entry from commits
        echo "::warning::git-cliff produced no output, generating simple changelog"
        local commits
        commits=$(git log --oneline "$base_ref"..HEAD -- "$chart_path" 2>/dev/null | head -20)

        changelog_entry="## [$new_version] - $(date +%Y-%m-%d)

### Changed
$(echo "$commits" | sed 's/^[a-f0-9]* /- /')
"
    fi

    # Prepend new entry after the header (after first blank line following header)
    local temp_file
    temp_file=$(mktemp)

    # Find where to insert (after the header section)
    awk -v entry="$changelog_entry" '
        /^# Changelog/ { header=1 }
        header && /^$/ && !inserted {
            print
            print entry
            inserted=1
            next
        }
        { print }
    ' "$changelog_file" > "$temp_file"

    mv "$temp_file" "$changelog_file"

    echo "::notice::Updated CHANGELOG.md for $chart"
    echo "::endgroup::"
}

#######################################
# Check if version was already bumped in this PR
#
# Arguments:
#   $1 - chart: Chart name
#   $2 - base_ref: Base branch/ref for comparison
#
# Returns:
#   0 if already bumped, 1 if not
#######################################
is_version_already_bumped() {
    local chart="$1"
    local base_ref="${2:-origin/main}"
    local chart_yaml="charts/$chart/Chart.yaml"

    # Check if Chart.yaml version differs from base
    local current_version base_version
    current_version=$(get_chart_version "$chart")
    base_version=$(git show "$base_ref:$chart_yaml" 2>/dev/null | grep '^version:' | awk '{print $2}' | tr -d '"' | tr -d "'" || echo "")

    if [[ -z "$base_version" ]]; then
        # New chart, no base version
        return 1
    fi

    if [[ "$current_version" != "$base_version" ]]; then
        echo "::notice::Version already bumped: $base_version -> $current_version"
        return 0
    fi

    return 1
}

#######################################
# Main function to bump version and generate changelog
#
# Arguments:
#   $1 - chart: Chart name
#   $2 - base_ref: Base branch/ref for comparison (default: origin/main)
#
# Outputs (via GITHUB_OUTPUT):
#   bumped: "true" or "false"
#   version: New version string
#   bump_type: "major", "minor", or "patch"
#######################################
bump_chart_version() {
    local chart="$1"
    local base_ref="${2:-origin/main}"

    echo "::group::Processing version bump for $chart"

    # Check if already bumped
    if is_version_already_bumped "$chart" "$base_ref"; then
        local current_version
        current_version=$(get_chart_version "$chart")
        echo "bumped=false" >> "${GITHUB_OUTPUT:-/dev/null}"
        echo "version=$current_version" >> "${GITHUB_OUTPUT:-/dev/null}"
        echo "bump_type=none" >> "${GITHUB_OUTPUT:-/dev/null}"
        echo "::endgroup::"
        return 0
    fi

    # Determine bump type
    local bump_type
    bump_type=$(determine_bump_type "$chart" "$base_ref")
    echo "::notice::Determined bump type: $bump_type"

    # Get current and calculate next version
    local current_version next_version
    current_version=$(get_chart_version "$chart")
    next_version=$(calculate_next_version "$current_version" "$bump_type")
    echo "::notice::Version bump: $current_version -> $next_version"

    # Update Chart.yaml
    update_chart_version "$chart" "$next_version"

    # Generate changelog
    generate_changelog "$chart" "$next_version" "$base_ref"

    # Output results
    echo "bumped=true" >> "${GITHUB_OUTPUT:-/dev/null}"
    echo "version=$next_version" >> "${GITHUB_OUTPUT:-/dev/null}"
    echo "bump_type=$bump_type" >> "${GITHUB_OUTPUT:-/dev/null}"

    echo "::endgroup::"
}

# Export functions for use in workflows
export -f determine_bump_type
export -f calculate_next_version
export -f get_chart_version
export -f update_chart_version
export -f generate_changelog
export -f is_version_already_bumped
export -f bump_chart_version
