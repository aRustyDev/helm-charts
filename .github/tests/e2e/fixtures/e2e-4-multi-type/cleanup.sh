#!/usr/bin/env bash
# E2E-4 Fixture Cleanup
set -euo pipefail

CHART="${E2E_CHART:-cloudflared}"

# Remove chart change
if [[ -f "charts/$CHART/values.yaml" ]]; then
  sed -i.bak '/# E2E-4 Test/d' "charts/$CHART/values.yaml"
  rm -f "charts/$CHART/values.yaml.bak"
fi

# Remove docs
rm -rf "docs/src/test-topic"

# Remove CI workflow
rm -f ".github/workflows/e2e-test-workflow.yaml"

echo "E2E-4 fixtures cleaned up"
