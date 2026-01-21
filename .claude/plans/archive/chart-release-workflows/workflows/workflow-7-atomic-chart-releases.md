# Workflow 7: Atomic Chart Releases

## Goal
Verify attestations at the tag level, build the chart package, and generate attestations for the built artifacts. Prepare for final publishing.

## Trigger
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - release
```

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| PR Number | `github.event.pull_request.number` | PR to process |
| Tags | Tag annotations | Created in Workflow 6 |
| Attestation Map | PR Body / Tag annotations | Lineage to verify |
| Chart Sources | `charts/` | Chart directories |

## Outputs

| Output | Destination | Description |
|--------|-------------|-------------|
| Chart Packages | `.cr-release-packages/` | Built .tgz files |
| Build Attestations | PR Description | Attestation IDs for packages |
| Overall Attestation | PR Description | Release preparation attestation |

## Controls (Rulesets)

| Control | Setting |
|---------|---------|
| Only `main` can merge to `release` | Workflow-enforced |
| All required checks must pass | No bypass |

## Processes

### 1. Validate Source Branch
```yaml
jobs:
  build-and-attest:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
      attestations: write
    steps:
      - name: Validate source branch
        run: |
          if [[ "${{ github.head_ref }}" != "main" ]]; then
            echo "::error::Only 'main' branch can merge to 'release'"
            echo "Source: ${{ github.head_ref }}"
            exit 1
          fi
```

### 2. Checkout and Setup
```yaml
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set up Helm
        uses: azure/setup-helm@v4
        with:
          version: v3.14.0

      - name: Install Cosign
        uses: sigstore/cosign-installer@v3
```

### 3. Detect Charts to Release
```yaml
      - name: Detect charts
        id: charts
        run: |
          # Get charts changed between release and main
          CHARTS=$(git diff --name-only origin/release...HEAD | \
            grep '^charts/' | \
            cut -d'/' -f2 | \
            sort -u)

          echo "list=$CHARTS" >> $GITHUB_OUTPUT
          echo "Charts to release: $CHARTS"
```

### 4. Verify Tag Attestations
```yaml
      - name: Verify tag attestations
        run: |
          for chart in ${{ steps.charts.outputs.list }}; do
            VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
            TAG="${chart}-v${VERSION}"

            echo "Verifying attestations for tag: $TAG"

            # Get tag annotation
            ANNOTATION=$(git tag -l --format='%(contents)' "$TAG")

            if [ -z "$ANNOTATION" ]; then
              echo "::error::Tag $TAG not found or has no annotation"
              exit 1
            fi

            # Extract and verify attestation IDs from annotation
            echo "$ANNOTATION" | grep -oP '- \K[^:]+: \d+' | while read line; do
              key=$(echo "$line" | cut -d: -f1)
              id=$(echo "$line" | cut -d: -f2 | tr -d ' ')

              echo "Verifying $key: $id"
              if ! gh attestation verify \
                --repo ${{ github.repository }} \
                --attestation-id "$id" 2>/dev/null; then
                echo "::warning::Could not verify attestation $key ($id)"
              fi
            done
          done
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Attest verification
        id: attest-verify
        uses: actions/attest-build-provenance@v3
        with:
          subject-name: "tag-verification"
          subject-digest: "sha256:${{ hashFiles('charts/**') }}"
```

### 5. Build Chart Packages
```yaml
      - name: Build charts
        id: build
        run: |
          mkdir -p .cr-release-packages

          for chart in ${{ steps.charts.outputs.list }}; do
            echo "Packaging $chart..."
            helm package "charts/$chart" -d .cr-release-packages/

            VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
            echo "${chart}_package=.cr-release-packages/${chart}-${VERSION}.tgz" >> $GITHUB_OUTPUT
          done

          ls -la .cr-release-packages/

      - name: Attest chart packages
        id: attest-build
        run: |
          ATTESTATION_IDS=""

          for tgz in .cr-release-packages/*.tgz; do
            CHART_NAME=$(basename "$tgz" | sed 's/-[0-9].*\.tgz$//')
            echo "Attesting $tgz..."

            # Generate attestation
            RESULT=$(gh attestation create \
              --repo ${{ github.repository }} \
              --subject-path "$tgz" \
              --type slsa-provenance \
              2>&1)

            ID=$(echo "$RESULT" | grep -oP 'attestation-id=\K\d+')
            echo "Attestation ID for $CHART_NAME: $ID"

            ATTESTATION_IDS="$ATTESTATION_IDS ${CHART_NAME}-build:$ID"
          done

          echo "attestation_ids=$ATTESTATION_IDS" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 6. Generate Overall Attestation
```yaml
      - name: Create attestation manifest
        run: |
          cat > release-attestation-manifest.json <<EOF
          {
            "version": "1.0",
            "stage": "release-build",
            "charts": [
              $(for chart in ${{ steps.charts.outputs.list }}; do
                version=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
                echo "{\"name\": \"$chart\", \"version\": \"$version\"},"
              done | sed '$ s/,$//')
            ],
            "pr": ${{ github.event.pull_request.number }},
            "attestations": {
              "verification": "${{ steps.attest-verify.outputs.attestation-id }}",
              "builds": "${{ steps.attest-build.outputs.attestation_ids }}"
            }
          }
          EOF

      - name: Overall attestation
        id: attest-overall
        uses: actions/attest-build-provenance@v3
        with:
          subject-path: "release-attestation-manifest.json"

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        with:
          name: chart-packages
          path: .cr-release-packages/*.tgz
```

### 7. Update PR Description
```yaml
      - name: Update PR description
        run: |
          update_attestation_map "workflow-7-verify" "${{ steps.attest-verify.outputs.attestation-id }}"
          update_attestation_map "workflow-7-overall" "${{ steps.attest-overall.outputs.attestation-id }}"

          # Add build attestations
          for pair in ${{ steps.attest-build.outputs.attestation_ids }}; do
            key=$(echo "$pair" | cut -d: -f1)
            id=$(echo "$pair" | cut -d: -f2)
            update_attestation_map "workflow-7-$key" "$id"
          done
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Shared Components Used
- `actions/attest-build-provenance@v3`
- `actions/upload-artifact@v4`
- `azure/setup-helm@v4`
- `sigstore/cosign-installer@v3`
- `gh attestation verify/create`
- `update_attestation_map` function
- Tag annotation parsing

## Error Handling
- Source branch invalid: Fail immediately
- Tag not found: Fail with clear error
- Attestation verification fails: Log warning, continue (or fail based on policy)
- Build fails: Fail the workflow

## Sequence Diagram
```
┌────────┐     ┌──────────┐     ┌───────────┐     ┌──────────┐
│   PR   │     │ Workflow │     │   Tags    │     │ Packages │
│ opened │     │    7     │     │           │     │          │
└───┬────┘     └────┬─────┘     └─────┬─────┘     └────┬─────┘
    │               │                  │                │
    │ PR opened     │                  │                │
    │──────────────►│                  │                │
    │               │                  │                │
    │               │ Validate source  │                │
    │               │──────────┐       │                │
    │               │          │       │                │
    │               │◄─────────┘       │                │
    │               │                  │                │
    │               │ Get tag annots   │                │
    │               │─────────────────►│                │
    │               │                  │                │
    │               │ Verify attests   │                │
    │               │─────────────────►│                │
    │               │                  │                │
    │               │ Build packages   │                │
    │               │─────────────────────────────────►│
    │               │                  │                │
    │               │ Attest builds    │                │
    │               │─────────────────────────────────►│
    │               │                  │                │
    │ Update desc   │                  │                │
    │◄──────────────│                  │                │
```
