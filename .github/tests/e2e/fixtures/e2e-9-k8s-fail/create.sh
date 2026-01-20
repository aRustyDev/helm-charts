#!/usr/bin/env bash
# E2E-9 Fixture: K8s-Failing Chart (passes lint, fails install)
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

if [[ ! -d "charts/$CHART" ]]; then
  echo "ERROR: Chart not found: charts/$CHART"
  exit 1
fi

# Add template that fails K8s install (requires undefined value)
# This will pass lint but fail during helm install --dry-run
cat > "charts/$CHART/templates/e2e-fail-k8s.yaml" << 'EOF'
# E2E-9: Template that fails K8s install
# The 'required' function will fail because e2eFail.value is not defined
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "test-workflow.fullname" . }}-e2e-fail
  labels:
    {{- include "test-workflow.labels" . | nindent 4 }}
data:
  # This will fail: required value not provided
  required-value: {{ required "e2eFail.value is required for E2E-9 test" .Values.e2eFail.value }}
EOF

echo "E2E-9 K8s-fail fixtures created for chart: $CHART"
echo "NOTE: This will pass lint but fail helm install tests"
