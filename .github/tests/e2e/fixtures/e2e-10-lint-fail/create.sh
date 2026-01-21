#!/usr/bin/env bash
# E2E-10 Fixture: Lint-Failing Chart (fails ct lint or ArtifactHub)
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

if [[ ! -f "charts/$CHART/Chart.yaml" ]]; then
  echo "ERROR: Chart.yaml not found: charts/$CHART/Chart.yaml"
  exit 1
fi

# Backup original Chart.yaml
cp "charts/$CHART/Chart.yaml" "charts/$CHART/Chart.yaml.e2e-10-backup"

# Remove required fields that will cause lint failure
# ArtifactHub requires: description, maintainers, home
# ct lint requires: version, description

# Create a Chart.yaml missing required fields
cat > "charts/$CHART/Chart.yaml" << EOF
apiVersion: v2
name: $CHART
version: 0.1.0
# Missing: description (required by ArtifactHub and ct lint)
# This will cause lint to fail
EOF

echo "E2E-10 lint-fail fixtures created for chart: $CHART"
echo "NOTE: Original Chart.yaml backed up to Chart.yaml.e2e-10-backup"
echo "NOTE: This will fail lint validation due to missing description"
