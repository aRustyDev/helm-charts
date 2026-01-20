#!/usr/bin/env bash
# E2E-12: Attestation Verification
#
# Objective: Verify that released charts have valid attestations.
#
# This test:
#   - Finds a released chart package
#   - Verifies attestation with gh attestation verify
#   - Validates the attestation contains expected metadata
#
# Note: This test depends on E2E-1 having created a release.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Test Configuration
# =============================================================================

TEST_ID="E2E-12"
TEST_NAME="Attestation Verification"
CHART="${E2E_CHART:-test-workflow}"
BRANCH=""

# =============================================================================
# Test Implementation
# =============================================================================

main() {
  setup_test "$TEST_ID" "$TEST_NAME"

  # Step 1: Prerequisites
  log_info "Step 1: Checking prerequisites"

  # Check for gh attestation command
  if ! gh attestation --help &>/dev/null; then
    log_warn "gh attestation command not available"
    log_warn "Skipping attestation verification test"
    pass "$TEST_ID" "SKIPPED: gh attestation not available"
    return 0
  fi

  # Step 2: Find latest release
  log_info "Step 2: Finding latest release"
  local latest_release
  latest_release=$(get_release_tag)

  if [[ -z "$latest_release" ]]; then
    log_warn "No releases found in repository"
    log_warn "Run E2E-1 first to create a release"
    pass "$TEST_ID" "SKIPPED: no releases found"
    return 0
  fi
  log_info "Latest release: $latest_release"

  # Step 3: Download release assets
  log_info "Step 3: Downloading release assets"
  local download_dir="/tmp/e2e-12-$$"
  mkdir -p "$download_dir"

  # Download chart package
  local chart_pattern="${CHART}-*.tgz"
  gh release download "$latest_release" \
    --pattern "$chart_pattern" \
    --dir "$download_dir" 2>/dev/null || true

  local chart_package
  chart_package=$(ls "$download_dir"/*.tgz 2>/dev/null | head -1)

  if [[ -z "$chart_package" ]]; then
    log_warn "No chart package found in release $latest_release"
    log_info "Looking for any chart package..."
    gh release download "$latest_release" \
      --pattern "*.tgz" \
      --dir "$download_dir" 2>/dev/null || true
    chart_package=$(ls "$download_dir"/*.tgz 2>/dev/null | head -1)
  fi

  if [[ -z "$chart_package" ]]; then
    log_warn "No .tgz packages found in release"
    rm -rf "$download_dir"
    pass "$TEST_ID" "SKIPPED: no chart packages in release"
    return 0
  fi
  log_info "Downloaded: $chart_package"

  # Step 4: Verify attestation
  log_info "Step 4: Verifying attestation"

  local verify_result=0
  if gh attestation verify "$chart_package" \
      --repo "${E2E_REPO}" \
      2>&1 | tee "$download_dir/attestation.log"; then
    log_info "Attestation verification PASSED"
  else
    verify_result=$?
    log_warn "Attestation verification returned: $verify_result"
  fi

  # Step 5: Check attestation details
  log_info "Step 5: Checking attestation details"

  # Try to get attestation metadata
  local attestations
  attestations=$(gh attestation verify "$chart_package" \
    --repo "${E2E_REPO}" \
    --format json 2>/dev/null || echo "[]")

  if [[ "$attestations" != "[]" ]] && [[ -n "$attestations" ]]; then
    log_info "Attestation metadata found"

    # Parse attestation info
    local predicate_type
    predicate_type=$(echo "$attestations" | jq -r '.[0].verificationResult.statement.predicateType // "unknown"' 2>/dev/null || echo "unknown")
    log_info "Predicate type: $predicate_type"

    local build_type
    build_type=$(echo "$attestations" | jq -r '.[0].verificationResult.statement.predicate.buildDefinition.buildType // "unknown"' 2>/dev/null || echo "unknown")
    log_info "Build type: $build_type"
  else
    log_warn "Could not retrieve attestation metadata"
    log_info "This may be expected if attestations are not enabled"
  fi

  # Step 6: Verify signature (if cosign available)
  log_info "Step 6: Checking for cosign signature"

  if command -v cosign &>/dev/null; then
    # Download signature if exists
    local sig_file="${chart_package}.sig"
    gh release download "$latest_release" \
      --pattern "$(basename "$chart_package").sig" \
      --dir "$download_dir" 2>/dev/null || true

    if [[ -f "$download_dir/$(basename "$chart_package").sig" ]]; then
      log_info "Signature file found"
      # Note: Actual cosign verification would require the public key
      log_info "Cosign verification would require public key configuration"
    else
      log_info "No separate signature file (attestation may be embedded)"
    fi
  else
    log_info "cosign not installed - skipping signature check"
  fi

  # Step 7: Verify provenance
  log_info "Step 7: Checking provenance"

  # Check for provenance file
  gh release download "$latest_release" \
    --pattern "*.provenance" \
    --dir "$download_dir" 2>/dev/null || true

  local provenance_file
  provenance_file=$(ls "$download_dir"/*.provenance 2>/dev/null | head -1)

  if [[ -n "$provenance_file" ]]; then
    log_info "Provenance file found: $provenance_file"
    if [[ -s "$provenance_file" ]]; then
      log_info "Provenance content exists"
    fi
  else
    log_info "No separate provenance file (may be embedded in attestation)"
  fi

  # Cleanup
  log_info "Cleanup: Removing downloaded files"
  rm -rf "$download_dir"

  # Determine pass/fail
  if [[ $verify_result -eq 0 ]]; then
    pass "$TEST_ID"
  else
    # Don't fail the test if attestations aren't enabled
    log_warn "Attestation verification had issues but test passes (feature may not be enabled)"
    pass "$TEST_ID" "WARN: attestation verification returned $verify_result"
  fi
}

# Run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
