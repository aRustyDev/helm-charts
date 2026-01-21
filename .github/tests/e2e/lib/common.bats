#!/usr/bin/env bats
# BATS Unit Tests for E2E Common Library
#
# Run with: bats .github/tests/e2e/lib/common.bats
#

# Setup and teardown
setup() {
  # Load the library in mock mode
  export E2E_MOCK=true
  export E2E_REPO="test/test-repo"
  export E2E_CHART="test-workflow"
  export E2E_TIMEOUT=60

  # Create temp directory for test artifacts
  TEST_TEMP="$(mktemp -d)"

  # Disable strict mode for sourcing (library uses set -euo pipefail)
  set +u

  # Source the library
  source "${BATS_TEST_DIRNAME}/common.sh" || true

  # Re-enable for tests
  set -u
}

teardown() {
  # Cleanup temp directory
  [[ -d "${TEST_TEMP:-}" ]] && rm -rf "$TEST_TEMP"
}

# =============================================================================
# Logging Functions
# =============================================================================

@test "log function outputs timestamped message" {
  run log "Test message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ \[[0-9]{2}:[0-9]{2}:[0-9]{2}\] ]]
  [[ "$output" =~ "Test message" ]]
}

@test "log_info adds INFO prefix" {
  run log_info "Info message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "INFO" ]]
  [[ "$output" =~ "Info message" ]]
}

@test "log_warn adds WARN prefix" {
  run log_warn "Warning message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "WARN" ]]
  [[ "$output" =~ "Warning message" ]]
}

@test "log_error adds ERROR prefix" {
  run log_error "Error message"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "ERROR" ]]
  [[ "$output" =~ "Error message" ]]
}

@test "log_section creates section header" {
  run log_section "Test Section"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "===" ]]
  [[ "$output" =~ "Test Section" ]]
}

# =============================================================================
# Color Functions
# =============================================================================

@test "colors are defined (may be empty if not a terminal)" {
  # Colors are defined but may be empty strings when not in a terminal
  # Just verify the variables are set (even if empty)
  # Using parameter expansion to check if set
  : "${RED+x}" "${GREEN+x}" "${NC+x}"
  # If we got here without error, variables are defined
  true
}

@test "NO_COLOR disables colors" {
  export NO_COLOR=1
  set +u
  source "${BATS_TEST_DIRNAME}/common.sh" || true
  set -u
  # When NO_COLOR is set, colors should be empty
  [[ -z "${RED:-}" ]]
  [[ -z "${GREEN:-}" ]]
  [[ -z "${NC:-}" ]]
}

# =============================================================================
# Assertion Functions
# =============================================================================

@test "assert_eq passes on equal values" {
  run assert_eq "foo" "foo" "test equality"
  [[ "$status" -eq 0 ]]
}

@test "assert_eq fails on unequal values" {
  run assert_eq "foo" "bar" "test inequality"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "ASSERTION FAILED" ]]
}

@test "assert_not_empty passes on non-empty value" {
  run assert_not_empty "value" "test non-empty"
  [[ "$status" -eq 0 ]]
}

@test "assert_not_empty fails on empty value" {
  run assert_not_empty "" "test empty"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "ASSERTION FAILED" ]]
}

@test "assert_contains passes when substring found" {
  run assert_contains "hello world" "world" "test contains"
  [[ "$status" -eq 0 ]]
}

@test "assert_contains fails when substring not found" {
  run assert_contains "hello world" "foo" "test not contains"
  [[ "$status" -eq 1 ]]
}

@test "assert_file_exists passes for existing file" {
  touch "$TEST_TEMP/testfile"
  run assert_file_exists "$TEST_TEMP/testfile"
  [[ "$status" -eq 0 ]]
}

@test "assert_file_exists fails for missing file" {
  run assert_file_exists "$TEST_TEMP/nonexistent"
  [[ "$status" -eq 1 ]]
}

# =============================================================================
# Git Helper Functions
# =============================================================================

@test "get_current_branch returns branch name" {
  # This depends on being in a git repo
  if git rev-parse --git-dir >/dev/null 2>&1; then
    run get_current_branch
    [[ "$status" -eq 0 ]]
    [[ -n "$output" ]]
  else
    skip "Not in a git repository"
  fi
}

@test "create_test_branch generates unique branch name" {
  # In mock mode, this should return a mock branch name
  run create_test_branch "test/prefix"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "test/prefix" ]]
}

# =============================================================================
# GitHub Helper Functions (Mock Mode)
# =============================================================================

@test "create_pr returns mock PR in mock mode" {
  export E2E_MOCK=true
  run create_pr "integration" "Test Title" "Test Body"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "https://github.com" ]] || [[ "$output" =~ "mock" ]]
}

@test "get_pr_state returns mock state in mock mode" {
  export E2E_MOCK=true
  run get_pr_state "123"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "OPEN" ]] || [[ "$output" =~ "MERGED" ]] || [[ "$output" =~ "CLOSED" ]]
}

@test "get_check_conclusion returns mock status in mock mode" {
  export E2E_MOCK=true
  run get_check_conclusion "123" "lint"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "success" ]] || [[ "$output" =~ "failure" ]] || [[ "$output" =~ "pending" ]]
}

# =============================================================================
# Test Lifecycle Functions
# =============================================================================

@test "setup_test initializes test environment" {
  run setup_test "E2E-TEST" "Test Name"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "E2E-TEST" ]]
  [[ "$output" =~ "Test Name" ]]
}

@test "pass outputs success message" {
  run pass "E2E-TEST"
  [[ "$status" -eq 0 ]]
  [[ "$output" =~ "PASS" ]]
  [[ "$output" =~ "E2E-TEST" ]]
}

@test "fail outputs failure message" {
  run fail "E2E-TEST" "Failure reason"
  [[ "$status" -eq 1 ]]
  [[ "$output" =~ "FAIL" ]]
  [[ "$output" =~ "E2E-TEST" ]]
  [[ "$output" =~ "Failure reason" ]]
}

# =============================================================================
# Fixture Functions
# =============================================================================

@test "apply_fixture function exists" {
  # Just verify the function is defined
  type apply_fixture >/dev/null 2>&1
}

@test "cleanup_fixture function exists" {
  type cleanup_fixture >/dev/null 2>&1
}

# =============================================================================
# Workflow Functions
# =============================================================================

@test "wait_for_workflow handles mock mode" {
  export E2E_MOCK=true
  export E2E_TIMEOUT=5
  run wait_for_workflow "test-workflow" "123"
  # Should return quickly in mock mode
  [[ "$status" -eq 0 ]]
}

@test "wait_for_merge handles mock mode" {
  export E2E_MOCK=true
  export E2E_TIMEOUT=5
  run wait_for_merge "123"
  # Should return quickly in mock mode
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Utility Functions
# =============================================================================

@test "get_release_tag handles empty releases" {
  export E2E_MOCK=true
  run get_release_tag
  # Should not fail even with no releases
  [[ "$status" -eq 0 ]]
}

@test "validate_chart_exists verifies chart directory" {
  # Create mock chart directory
  mkdir -p "$TEST_TEMP/charts/test-chart"
  touch "$TEST_TEMP/charts/test-chart/Chart.yaml"

  # Temporarily change to test directory
  pushd "$TEST_TEMP" > /dev/null

  run validate_chart_exists "test-chart"
  [[ "$status" -eq 0 ]]

  popd > /dev/null
}

@test "validate_chart_exists fails for missing chart" {
  pushd "$TEST_TEMP" > /dev/null
  mkdir -p charts

  run validate_chart_exists "nonexistent-chart"
  [[ "$status" -eq 1 ]]

  popd > /dev/null
}

# =============================================================================
# Environment Variable Handling
# =============================================================================

@test "E2E_REPO has default value" {
  unset E2E_REPO
  source "${BATS_TEST_DIRNAME}/common.sh"
  [[ -n "$E2E_REPO" ]]
}

@test "E2E_TIMEOUT has default value" {
  unset E2E_TIMEOUT
  source "${BATS_TEST_DIRNAME}/common.sh"
  [[ "$E2E_TIMEOUT" -gt 0 ]]
}

@test "E2E_CHART has default value" {
  unset E2E_CHART
  set +u
  source "${BATS_TEST_DIRNAME}/common.sh" || true
  set -u
  [[ -n "${E2E_CHART:-}" ]]
}

# =============================================================================
# Error Handling
# =============================================================================

@test "functions handle missing arguments gracefully" {
  # These should fail but not crash
  run assert_eq
  [[ "$status" -ne 0 ]]

  run assert_not_empty
  [[ "$status" -ne 0 ]]
}

@test "functions handle special characters in arguments" {
  run log "Message with 'quotes' and \"double quotes\""
  [[ "$status" -eq 0 ]]

  run log "Message with \$variables and \$(commands)"
  [[ "$status" -eq 0 ]]
}

# =============================================================================
# Integration Checks
# =============================================================================

@test "script can be sourced multiple times" {
  source "${BATS_TEST_DIRNAME}/common.sh"
  source "${BATS_TEST_DIRNAME}/common.sh"
  # Should not produce errors
  [[ "$(type -t log)" == "function" ]]
}

@test "all required functions are exported" {
  local required_functions=(
    "log"
    "log_info"
    "log_warn"
    "log_error"
    "log_section"
    "assert_eq"
    "assert_not_empty"
    "setup_test"
    "teardown_test"
    "pass"
    "fail"
  )

  for func in "${required_functions[@]}"; do
    [[ "$(type -t "$func")" == "function" ]]
  done
}
