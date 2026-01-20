#!/usr/bin/env bash
# E2E-4 Fixture: Multi-Type Change (Chart + Docs + CI)
set -euo pipefail

CHART="${E2E_CHART:-cloudflared}"

# 1. Chart change
if [[ -d "charts/$CHART" ]]; then
  echo "# E2E-4 Test: Multi-type change" >> "charts/$CHART/values.yaml"
  echo "E2E-4: Chart change applied to $CHART"
else
  echo "WARNING: Chart $CHART not found, skipping chart change"
fi

# 2. Docs change
mkdir -p "docs/src/test-topic"
cat > "docs/src/test-topic/e2e-test.md" << 'EOF'
# E2E-4 Test Document

This document tests multi-type atomization.

## Purpose

Verify that the atomization workflow correctly handles:
- Chart changes (to `chart/*` branch)
- Documentation changes (to `docs/*` branch)
- CI changes (to `ci/*` branch)

## Expected Behavior

Each file type should be routed to its appropriate atomic branch.
EOF
echo "E2E-4: Docs change applied"

# 3. CI change
cat > ".github/workflows/e2e-test-workflow.yaml" << 'EOF'
name: E2E Test Workflow

on:
  workflow_dispatch:
    inputs:
      message:
        description: 'Test message'
        required: false
        default: 'E2E-4 test'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Print message
        run: echo "${{ inputs.message }}"
EOF
echo "E2E-4: CI change applied"

echo "E2E-4 multi-type fixtures created"
