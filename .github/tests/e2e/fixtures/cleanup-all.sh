#!/usr/bin/env bash
# Master Cleanup Script for All E2E Fixtures
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Cleaning up all E2E fixtures..."

# Run cleanup for each fixture directory
for fixture_dir in "$SCRIPT_DIR"/*/; do
  fixture_name=$(basename "$fixture_dir")
  cleanup_script="$fixture_dir/cleanup.sh"

  if [[ -f "$cleanup_script" ]]; then
    echo "Cleaning: $fixture_name"
    bash "$cleanup_script" || echo "WARNING: Cleanup failed for $fixture_name"
  fi
done

echo ""
echo "All E2E fixtures cleaned up"
