#!/usr/bin/env bash
# attestation-lib.sh - Shared library for attestation operations
#
# This library provides functions for managing attestation maps in PR descriptions,
# verifying attestation chains, and detecting changed charts.
#
# Usage:
#   source .github/scripts/attestation-lib.sh
#
# Required environment variables:
#   GITHUB_REPOSITORY - The owner/repo (e.g., aRustyDev/helm-charts)
#
# Optional environment variables:
#   GH_TOKEN or GITHUB_TOKEN - For API authentication

set -euo pipefail

# Attestation map markers
readonly ATTESTATION_MAP_START="<!-- ATTESTATION_MAP"
readonly ATTESTATION_MAP_END="-->"

#######################################
# Update the attestation map in a PR description
#
# Adds or updates an attestation ID for a given check name in the PR description.
# Uses exponential backoff retry for concurrent updates.
#
# Arguments:
#   $1 - check_name: Name of the check (e.g., "lint-test-v1.32.11")
#   $2 - attestation_id: The attestation ID to store
#   $3 - pr_number: PR number to update (optional, uses PR_NUMBER env var if not provided)
#
# Returns:
#   0 on success, 1 on failure
#######################################
update_attestation_map() {
    local check_name="$1"
    local attestation_id="$2"
    local pr_number="${3:-${PR_NUMBER:-}}"

    if [[ -z "$pr_number" ]]; then
        echo "::error::PR number not provided and PR_NUMBER not set"
        return 1
    fi

    if [[ -z "$check_name" || -z "$attestation_id" ]]; then
        echo "::error::check_name and attestation_id are required"
        return 1
    fi

    local max_retries=5
    local retry_delay=1

    for ((attempt = 1; attempt <= max_retries; attempt++)); do
        echo "::debug::Updating attestation map (attempt $attempt/$max_retries)"

        # Get current PR body
        local body
        body=$(gh pr view "$pr_number" --json body -q '.body' 2>/dev/null) || {
            echo "::warning::Failed to fetch PR body, retrying..."
            sleep "$retry_delay"
            retry_delay=$((retry_delay * 2))
            continue
        }

        # Extract existing map or create new one
        local existing_map
        existing_map=$(extract_attestation_map_from_body "$body")
        if [[ -z "$existing_map" || "$existing_map" == "null" ]]; then
            existing_map='{}'
        fi

        # Update map with new attestation
        local updated_map
        updated_map=$(echo "$existing_map" | jq -c --arg k "$check_name" --arg v "$attestation_id" '. + {($k): $v}')

        # Build new body
        local new_body
        if echo "$body" | grep -qF "<!-- ATTESTATION_MAP"; then
            # Replace existing map using awk for robustness
            new_body=$(echo "$body" | awk -v map="$updated_map" '
                /<!-- ATTESTATION_MAP/,/-->/ {
                    if (/<!-- ATTESTATION_MAP/) {
                        print "<!-- ATTESTATION_MAP"
                        print map
                        next
                    }
                    if (/-->/) {
                        print "-->"
                        next
                    }
                    next
                }
                { print }
            ')
        else
            # Append new map
            new_body="$body

<!-- ATTESTATION_MAP
$updated_map
-->"
        fi

        # Update PR
        if gh pr edit "$pr_number" --body "$new_body" 2>/dev/null; then
            echo "::notice::Updated attestation map: $check_name = $attestation_id"
            return 0
        fi

        echo "::warning::Failed to update PR body, retrying..."
        sleep "$retry_delay"
        retry_delay=$((retry_delay * 2))
    done

    echo "::error::Failed to update attestation map after $max_retries attempts"
    return 1
}

#######################################
# Extract attestation map from PR description
#
# Arguments:
#   $1 - pr_number: PR number to read from
#
# Outputs:
#   JSON object containing attestation IDs, or empty object if none found
#######################################
extract_attestation_map() {
    local pr_number="$1"

    if [[ -z "$pr_number" ]]; then
        echo "::error::PR number is required"
        return 1
    fi

    local body
    body=$(gh pr view "$pr_number" --json body -q '.body' 2>/dev/null) || {
        echo "::error::Failed to fetch PR body"
        return 1
    }

    extract_attestation_map_from_body "$body"
}

#######################################
# Extract attestation map from a body string
#
# Arguments:
#   $1 - body: PR body content
#
# Outputs:
#   JSON object containing attestation IDs, or {} if none found
#######################################
extract_attestation_map_from_body() {
    local body="$1"

    if [[ -z "$body" ]]; then
        echo '{}'
        return 0
    fi

    # Extract content between markers using awk for robustness
    local map_content
    map_content=$(echo "$body" | awk '
        /<!-- ATTESTATION_MAP/,/-->/ {
            if (!/<!-- ATTESTATION_MAP/ && !/-->/) print
        }
    ' | tr -d '\n' | xargs)

    if [[ -z "$map_content" ]]; then
        echo '{}'
        return 0
    fi

    # Validate it's valid JSON
    if echo "$map_content" | jq -e . >/dev/null 2>&1; then
        echo "$map_content"
    else
        echo "::warning::Invalid JSON in attestation map, returning empty" >&2
        echo '{}'
    fi
}

#######################################
# Verify all attestations in a map
#
# Arguments:
#   $1 - attestation_map: JSON object of check_name -> attestation_id
#   $2 - repo: Repository in owner/repo format (optional, uses GITHUB_REPOSITORY)
#
# Returns:
#   0 if all attestations are valid, 1 if any fail
#######################################
verify_attestation_chain() {
    local attestation_map="$1"
    local repo="${2:-${GITHUB_REPOSITORY:-}}"

    if [[ -z "$repo" ]]; then
        echo "::error::Repository not provided and GITHUB_REPOSITORY not set"
        return 1
    fi

    if [[ -z "$attestation_map" || "$attestation_map" == "{}" ]]; then
        echo "::error::Empty attestation map provided"
        return 1
    fi

    local failed=0
    local total=0
    local verified=0

    # Iterate through all attestations
    while IFS='=' read -r key value; do
        ((total++))
        local check_name
        local attestation_id
        check_name=$(echo "$key" | tr -d '"')
        attestation_id=$(echo "$value" | tr -d '"')

        echo "::group::Verifying attestation: $check_name"
        echo "Attestation ID: $attestation_id"

        if gh attestation verify \
            --repo "$repo" \
            --bundle-from-oci "oci://ghcr.io/$repo/attestations:$attestation_id" 2>/dev/null; then
            echo "::notice::Verified: $check_name"
            ((verified++))
        else
            # Try alternative verification method
            if gh api "/repos/$repo/attestations/$attestation_id" >/dev/null 2>&1; then
                echo "::notice::Verified via API: $check_name"
                ((verified++))
            else
                echo "::error::Failed to verify: $check_name ($attestation_id)"
                ((failed++))
            fi
        fi
        echo "::endgroup::"
    done < <(echo "$attestation_map" | jq -r 'to_entries[] | "\(.key)=\(.value)"')

    echo "::notice::Attestation verification complete: $verified/$total verified, $failed failed"

    if [[ $failed -gt 0 ]]; then
        return 1
    fi
    return 0
}

#######################################
# Detect charts that changed in a commit range
#
# Arguments:
#   $1 - range: Git commit range (optional, defaults to HEAD~1..HEAD)
#   $2 - base_branch: Base branch for comparison (optional, for PR context)
#
# Outputs:
#   Space-separated list of chart names that changed
#######################################
detect_changed_charts() {
    local range="${1:-HEAD~1..HEAD}"
    local base_branch="${2:-}"

    # If base_branch is provided, use it for comparison
    if [[ -n "$base_branch" ]]; then
        range="origin/$base_branch...HEAD"
    fi

    local charts
    charts=$(git diff --name-only "$range" 2>/dev/null | \
        grep '^charts/' | \
        cut -d'/' -f2 | \
        sort -u | \
        tr '\n' ' ' | \
        xargs)

    if [[ -z "$charts" ]]; then
        echo "::notice::No chart changes detected in range: $range" >&2
    else
        echo "::notice::Changed charts: $charts" >&2
    fi

    echo "$charts"
}

#######################################
# Validate source branch for a PR
#
# Arguments:
#   $1 - source_branch: The source branch of the PR
#   $2 - allowed_pattern: Allowed branch pattern (exact match or glob)
#
# Returns:
#   0 if valid, 1 if invalid
#######################################
validate_source_branch() {
    local source_branch="$1"
    local allowed_pattern="$2"

    if [[ -z "$source_branch" || -z "$allowed_pattern" ]]; then
        echo "::error::source_branch and allowed_pattern are required"
        return 1
    fi

    # Check for exact match or glob pattern
    # shellcheck disable=SC2053
    if [[ "$source_branch" == $allowed_pattern ]]; then
        echo "::notice::Source branch '$source_branch' matches allowed pattern '$allowed_pattern'"
        return 0
    fi

    echo "::error::Invalid source branch: '$source_branch' (expected: '$allowed_pattern')"
    return 1
}

#######################################
# Get the source PR number from a merge commit
#
# Arguments:
#   $1 - commit_sha: Commit SHA to check (optional, defaults to HEAD)
#
# Outputs:
#   PR number if found, empty otherwise
#######################################
get_source_pr() {
    local commit_sha="${1:-HEAD}"

    # Try to extract PR number from merge commit message
    local pr_number
    pr_number=$(git log -1 --format="%s" "$commit_sha" | grep -oE '#[0-9]+' | head -1 | tr -d '#')

    if [[ -n "$pr_number" ]]; then
        echo "$pr_number"
        return 0
    fi

    # Try GitHub API as fallback
    local repo="${GITHUB_REPOSITORY:-}"
    if [[ -n "$repo" ]]; then
        pr_number=$(gh api "/repos/$repo/commits/$commit_sha/pulls" --jq '.[0].number' 2>/dev/null || true)
        if [[ -n "$pr_number" && "$pr_number" != "null" ]]; then
            echo "$pr_number"
            return 0
        fi
    fi

    echo ""
}

#######################################
# Generate a subject digest for attestation
#
# Arguments:
#   $1 - subject_content: Content to hash (file path or string)
#   $2 - type: "file" or "string" (default: "string")
#
# Outputs:
#   SHA256 digest in format "sha256:..."
#######################################
generate_subject_digest() {
    local subject_content="$1"
    local type="${2:-string}"

    local digest
    if [[ "$type" == "file" ]]; then
        if [[ ! -f "$subject_content" ]]; then
            echo "::error::File not found: $subject_content"
            return 1
        fi
        digest=$(sha256sum "$subject_content" | cut -d' ' -f1)
    else
        digest=$(echo -n "$subject_content" | sha256sum | cut -d' ' -f1)
    fi

    echo "sha256:$digest"
}

#######################################
# Log attestation details for debugging
#
# Arguments:
#   $1 - subject_name: The attestation subject name
#   $2 - subject_digest: The subject digest
#   $3 - attestation_id: The resulting attestation ID (optional)
#######################################
log_attestation() {
    local subject_name="$1"
    local subject_digest="$2"
    local attestation_id="${3:-pending}"

    echo "::group::Attestation Details"
    echo "Subject Name: $subject_name"
    echo "Subject Digest: $subject_digest"
    echo "Attestation ID: $attestation_id"
    echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "::endgroup::"
}

#######################################
# Extract changelog entries for a specific version
#
# Reads the CHANGELOG.md file for a chart and extracts the section
# for the specified version. Expects Keep-a-Changelog format.
#
# Arguments:
#   $1 - chart: Chart name
#   $2 - version: Version to extract (e.g., "1.0.0")
#
# Outputs:
#   Changelog content for the specified version, or fallback message
#######################################
extract_changelog_for_version() {
    local chart="$1"
    local version="$2"
    local changelog_file="charts/$chart/CHANGELOG.md"

    if [[ -z "$chart" || -z "$version" ]]; then
        echo "No changelog available (missing chart or version)"
        return 0
    fi

    if [[ ! -f "$changelog_file" ]]; then
        echo "No changelog available for $chart"
        return 0
    fi

    # Extract section from ## [VERSION] until next ## [ or end of file
    # Using awk to handle the Keep-a-Changelog format
    local changelog_content
    changelog_content=$(awk -v ver="$version" '
        /^## \[/ {
            if (found) exit
            if ($0 ~ "\\[" ver "\\]") found=1
        }
        found { print }
    ' "$changelog_file")

    if [[ -z "$changelog_content" ]]; then
        echo "No changelog entries found for version $version"
        return 0
    fi

    echo "$changelog_content"
}

# Export functions for use in subshells
export -f update_attestation_map
export -f extract_attestation_map
export -f extract_attestation_map_from_body
export -f verify_attestation_chain
export -f detect_changed_charts
export -f validate_source_branch
export -f get_source_pr
export -f generate_subject_digest
export -f log_attestation
export -f extract_changelog_for_version
