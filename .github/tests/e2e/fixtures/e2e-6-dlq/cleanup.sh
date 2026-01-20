#!/usr/bin/env bash
# E2E-6 Fixture Cleanup
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

# Remove DLQ test directories
rm -rf scripts misc

# Remove chart change
if [[ -f "charts/$CHART/values.yaml" ]]; then
  sed -i.bak '/# E2E-6 Test/d' "charts/$CHART/values.yaml"
  rm -f "charts/$CHART/values.yaml.bak"
fi

echo "E2E-6 fixtures cleaned up"
