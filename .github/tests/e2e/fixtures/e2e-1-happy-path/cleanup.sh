#!/usr/bin/env bash
# E2E-1 Fixture Cleanup
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

# Remove the template file
rm -f "charts/$CHART/templates/e2e-test-configmap.yaml"

# Restore values.yaml (remove the e2eTest section)
if [[ -f "charts/$CHART/values.yaml" ]]; then
  # Remove lines from "# E2E-1 Test" to end of e2eTest block
  sed -i.bak '/# E2E-1 Test/,/message:/d' "charts/$CHART/values.yaml"
  rm -f "charts/$CHART/values.yaml.bak"
fi

echo "E2E-1 fixtures cleaned up for chart: $CHART"
