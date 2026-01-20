#!/usr/bin/env bash
# E2E Test Master Runner
# Runs all E2E tests with proper ordering and dependency handling
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$RESULTS_DIR"

# shellcheck source=lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# =============================================================================
# Configuration
# =============================================================================

PARALLEL=false
TESTS=""
SKIP_PREREQS=false
DRY_RUN=false

# =============================================================================
# Parse Arguments
# =============================================================================

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --parallel        Run independent tests in parallel
  --tests LIST      Comma-separated list of tests to run (e.g., e2e-1,e2e-4)
  --skip-prereqs    Skip prerequisite checks
  --dry-run         Show what would run without executing
  --help            Show this help

Examples:
  $(basename "$0")                           # Run all tests serially
  $(basename "$0") --parallel                # Run independent tests in parallel
  $(basename "$0") --tests e2e-1,e2e-4       # Run specific tests
  $(basename "$0") --dry-run                 # Show execution plan

Test IDs:
  e2e-1   Happy path (full pipeline)
  e2e-2   Untrusted contributor
  e2e-3   Unsigned commit
  e2e-4   Multi-file-type atomization
  e2e-5   Dependabot auto-merge
  e2e-6   DLQ handling
  e2e-7   Multiple charts
  e2e-9   K8s test failure
  e2e-10  Lint failure
  e2e-12  Attestation verification
  e2e-13  Full lineage trace
  e2e-14  Failure recovery
  e2e-15  Fork PR security
  e2e-16  Direct push blocked (negative)
  e2e-17  Bypass integration (negative)
  e2e-19  Release idempotency (negative)
  e2e-20  Invalid commit (negative)
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --parallel)
      PARALLEL=true
      shift
      ;;
    --tests)
      TESTS="$2"
      shift 2
      ;;
    --skip-prereqs)
      SKIP_PREREQS=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      usage
      exit 1
      ;;
  esac
done

# =============================================================================
# Test Definitions
# =============================================================================

# Tests in dependency order
ALL_TESTS=(
  "e2e-1-happy-path"          # Baseline - must run first
  "e2e-2-untrusted"           # Independent
  "e2e-3-unsigned"            # Independent
  "e2e-4-multi-type"          # Independent
  "e2e-6-dlq"                 # Independent
  "e2e-7-multi-chart"         # Independent
  "e2e-9-k8s-fail"            # Independent
  "e2e-10-lint-fail"          # Independent
  "e2e-12-verify-fail"        # Depends on E2E-1
  "e2e-13-lineage"            # Depends on E2E-1
  "e2e-14-recovery"           # Independent
  "e2e-15-fork"               # Independent
  "e2e-16-direct-push"        # Negative test
  "e2e-17-bypass"             # Negative test
  "e2e-19-idempotent"         # Negative test
  "e2e-20-bad-commit"         # Negative test
)

# Tests that can run in parallel (independent)
PARALLEL_GROUP_A=(
  "e2e-2-untrusted"
  "e2e-3-unsigned"
  "e2e-4-multi-type"
)

PARALLEL_GROUP_B=(
  "e2e-6-dlq"
  "e2e-7-multi-chart"
  "e2e-9-k8s-fail"
  "e2e-10-lint-fail"
)

PARALLEL_GROUP_C=(
  "e2e-14-recovery"
  "e2e-15-fork"
)

NEGATIVE_TESTS=(
  "e2e-16-direct-push"
  "e2e-17-bypass"
  "e2e-19-idempotent"
  "e2e-20-bad-commit"
)

# =============================================================================
# Helper Functions
# =============================================================================

log_to_file() {
  echo "[$(date +%H:%M:%S)] $*" >> "$RESULTS_DIR/run.log"
  log "$@"
}

run_test() {
  local test_id="$1"
  local test_script="$SCRIPT_DIR/${test_id}.sh"

  if [[ ! -f "$test_script" ]]; then
    log_to_file "SKIP: $test_id (no script found)"
    echo "$test_id,SKIP,0,No script found" >> "$RESULTS_DIR/summary.csv"
    return 0
  fi

  log_to_file "START: $test_id"
  local start_time
  start_time=$(date +%s)

  local status="FAIL"
  local log_file="$RESULTS_DIR/${test_id}.log"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "DRY RUN: Would execute $test_script"
    status="DRY_RUN"
  elif bash "$test_script" > "$log_file" 2>&1; then
    status="PASS"
  else
    status="FAIL"
  fi

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  log_to_file "$status: $test_id (${duration}s)"
  echo "$test_id,$status,$duration" >> "$RESULTS_DIR/summary.csv"

  return 0
}

run_tests_serial() {
  local tests=("$@")
  for test in "${tests[@]}"; do
    run_test "$test"
  done
}

run_tests_parallel() {
  local tests=("$@")
  local pids=()

  for test in "${tests[@]}"; do
    run_test "$test" &
    pids+=($!)
  done

  # Wait for all
  for pid in "${pids[@]}"; do
    wait "$pid" || true
  done
}

check_prerequisites() {
  log_section "Checking Prerequisites"

  local errors=0

  # Check gh CLI
  if ! command -v gh &>/dev/null; then
    log_error "GitHub CLI (gh) not found"
    ((errors++))
  elif ! gh auth status &>/dev/null; then
    log_error "GitHub CLI not authenticated"
    ((errors++))
  else
    log_info "GitHub CLI: OK"
  fi

  # Check git
  if ! command -v git &>/dev/null; then
    log_error "Git not found"
    ((errors++))
  else
    log_info "Git: OK"
  fi

  # Check we're in a git repo
  if ! git rev-parse --git-dir &>/dev/null; then
    log_error "Not in a git repository"
    ((errors++))
  else
    log_info "Git repository: OK"
  fi

  # Check current branch
  local current_branch
  current_branch=$(git branch --show-current)
  log_info "Current branch: $current_branch"

  # Check for clean working tree
  if [[ -n "$(git status --porcelain)" ]]; then
    log_warn "Working tree has uncommitted changes"
  else
    log_info "Working tree: clean"
  fi

  if [[ $errors -gt 0 ]]; then
    log_error "Prerequisites check failed with $errors errors"
    return 1
  fi

  log_info "All prerequisites OK"
  return 0
}

# =============================================================================
# Main Execution
# =============================================================================

log_section "E2E Test Suite"
log_to_file "Results directory: $RESULTS_DIR"
log_to_file "Parallel mode: $PARALLEL"

# Initialize summary CSV
echo "test_id,status,duration_seconds" > "$RESULTS_DIR/summary.csv"

# Check prerequisites
if [[ "$SKIP_PREREQS" != "true" ]]; then
  if ! check_prerequisites; then
    log_error "Aborting due to prerequisite failures"
    exit 1
  fi
fi

# Determine which tests to run
declare -a SELECTED_TESTS
if [[ -n "$TESTS" ]]; then
  IFS=',' read -ra SELECTED_TESTS <<< "$TESTS"
else
  SELECTED_TESTS=("${ALL_TESTS[@]}")
fi

log_to_file "Tests to run: ${SELECTED_TESTS[*]}"

# Run tests
if [[ "$PARALLEL" == "true" ]]; then
  log_section "Running Tests (Parallel Mode)"

  # Phase 1: E2E-1 (baseline)
  log_info "Phase 1: Baseline test"
  run_test "e2e-1-happy-path"

  # Phase 2: Independent tests (parallel)
  log_info "Phase 2: Independent tests (parallel)"
  run_tests_parallel "${PARALLEL_GROUP_A[@]}"
  run_tests_parallel "${PARALLEL_GROUP_B[@]}"

  # Phase 3: Tests depending on E2E-1
  log_info "Phase 3: Dependent tests"
  run_tests_parallel "e2e-12-verify-fail" "e2e-13-lineage"

  # Phase 4: Remaining tests (parallel)
  log_info "Phase 4: Remaining tests"
  run_tests_parallel "${PARALLEL_GROUP_C[@]}"

  # Phase 5: Negative tests
  log_info "Phase 5: Negative tests"
  run_tests_parallel "${NEGATIVE_TESTS[@]}"
else
  log_section "Running Tests (Serial Mode)"
  run_tests_serial "${SELECTED_TESTS[@]}"
fi

# =============================================================================
# Summary
# =============================================================================

log_section "Test Summary"

# Count results
total=0
passed=0
failed=0
skipped=0

while IFS=',' read -r test_id status duration; do
  [[ "$test_id" == "test_id" ]] && continue  # Skip header
  ((total++))
  case "$status" in
    PASS) ((passed++)) ;;
    FAIL) ((failed++)) ;;
    SKIP|DRY_RUN) ((skipped++)) ;;
  esac
done < "$RESULTS_DIR/summary.csv"

echo ""
echo "Results:"
echo "  Total:   $total"
echo "  Passed:  $passed"
echo "  Failed:  $failed"
echo "  Skipped: $skipped"
echo ""
echo "Details: $RESULTS_DIR/summary.csv"
echo "Logs:    $RESULTS_DIR/*.log"
echo ""

# Exit with failure if any tests failed
if [[ $failed -gt 0 ]]; then
  log_error "$failed test(s) failed"
  exit 1
fi

log_info "All tests passed!"
