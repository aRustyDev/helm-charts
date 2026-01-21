#!/usr/bin/env bash
# E2E-1 Fixture: Valid Chart Change for Happy Path Test
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

# Check if chart exists
if [[ ! -d "charts/$CHART" ]]; then
  echo "ERROR: Chart not found: charts/$CHART"
  exit 1
fi

# Add a valid feature to the chart values
cat >> "charts/$CHART/values.yaml" << 'EOF'

# E2E-1 Test: Valid feature addition
e2eTest:
  enabled: false
  replicas: 1
  message: "Hello from E2E-1"
EOF

# Add corresponding template
cat > "charts/$CHART/templates/e2e-test-configmap.yaml" << 'EOF'
{{- if .Values.e2eTest.enabled }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ include "test-workflow.fullname" . }}-e2e
  labels:
    {{- include "test-workflow.labels" . | nindent 4 }}
data:
  replicas: "{{ .Values.e2eTest.replicas }}"
  message: {{ .Values.e2eTest.message | quote }}
{{- end }}
EOF

echo "E2E-1 fixtures created for chart: $CHART"
