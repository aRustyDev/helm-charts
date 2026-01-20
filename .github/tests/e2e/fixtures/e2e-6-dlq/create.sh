#!/usr/bin/env bash
# E2E-6 Fixture: DLQ Files (Unmatched patterns)
set -euo pipefail

CHART="${E2E_CHART:-test-workflow}"

# Create files that don't match any atomization pattern
mkdir -p scripts misc

cat > "scripts/e2e-test-tool.sh" << 'EOF'
#!/usr/bin/env bash
# E2E-6: This file goes to DLQ (doesn't match any pattern)
echo "This is a test script that doesn't match atomization patterns"
EOF
chmod +x "scripts/e2e-test-tool.sh"

cat > "misc/e2e-notes.txt" << 'EOF'
E2E-6: Unmatched file for DLQ testing

This file is in the misc/ directory which doesn't match:
- charts/* (chart changes)
- docs/src/* (documentation)
- .github/workflows/* (CI changes)

Expected: This file should go to a DLQ branch.
EOF

# Also add a valid chart change (to ensure partial success)
if [[ -d "charts/$CHART" ]]; then
  echo "# E2E-6 Test: Valid chart change alongside DLQ files" >> "charts/$CHART/values.yaml"
  echo "E2E-6: Valid chart change applied"
fi

echo "E2E-6 DLQ fixtures created"
