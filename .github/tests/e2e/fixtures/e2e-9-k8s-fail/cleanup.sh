#!/usr/bin/env bash
# E2E-9 Fixture Cleanup
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

# Remove the failing template
rm -f "charts/$CHART/templates/e2e-fail-k8s.yaml"

echo "E2E-9 fixtures cleaned up for chart: $CHART"
