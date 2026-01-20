#!/usr/bin/env bash
# E2E-10 Fixture Cleanup
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

# Restore original Chart.yaml from backup
if [[ -f "charts/$CHART/Chart.yaml.e2e-10-backup" ]]; then
  mv "charts/$CHART/Chart.yaml.e2e-10-backup" "charts/$CHART/Chart.yaml"
  echo "E2E-10: Chart.yaml restored from backup"
else
  echo "WARNING: No backup found at charts/$CHART/Chart.yaml.e2e-10-backup"
  echo "You may need to manually restore Chart.yaml"
fi

echo "E2E-10 fixtures cleaned up for chart: $CHART"
