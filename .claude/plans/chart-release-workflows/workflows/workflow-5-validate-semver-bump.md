# Workflow 5: Validate & SemVer Bump Atomic Chart PRs

## Goal
Verify the attestation lineage from upstream workflows, determine and apply the semantic version bump using release-please, and generate an overall attestation for the validated state.

## Trigger
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - main
    paths:
      - 'charts/**'
```

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| PR Number | `github.event.pull_request.number` | PR to process |
| PR Body | PR Description | Attestation map from upstream |
| Chart Path | Changed files | Chart being released |
| Commit History | Git log | For version bump determination |

## Outputs

| Output | Destination | Description |
|--------|-------------|-------------|
| Version Bump | Chart.yaml | Updated version |
| Attestation ID | PR Description | SemVer bump attestation |
| Overall Attestation | PR Description | Verification of entire lineage |
| Check Status | GitHub Checks | Pass/fail |

## Controls (Rulesets)

| Control | Setting |
|---------|---------|
| Required checks | All must pass (no bypass) |
| PR required | Yes |
| Review required | Yes |

## Processes

### 1. Extract Attestation Map
```yaml
jobs:
  validate-and-bump:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      id-token: write
      attestations: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Extract attestation map
        id: attestations
        run: |
          PR_BODY=$(gh pr view ${{ github.event.pull_request.number }} --json body -q '.body')

          # Extract JSON from HTML comment
          ATTESTATION_MAP=$(echo "$PR_BODY" | \
            grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | \
            tr -d '\0' | \
            head -c -1)  # Remove trailing newline

          if [ -z "$ATTESTATION_MAP" ]; then
            echo "::error::No attestation map found in PR description"
            exit 1
          fi

          echo "map<<EOF" >> $GITHUB_OUTPUT
          echo "$ATTESTATION_MAP" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

          # Count attestations
          COUNT=$(echo "$ATTESTATION_MAP" | jq 'length')
          echo "Found $COUNT attestations to verify"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 2. Verify Attestations
```yaml
      - name: Verify attestations
        id: verify
        run: |
          ATTESTATION_MAP='${{ steps.attestations.outputs.map }}'
          FAILED=0

          echo "Verifying attestation lineage..."

          # Iterate over each attestation
          for key in $(echo "$ATTESTATION_MAP" | jq -r 'keys[]'); do
            id=$(echo "$ATTESTATION_MAP" | jq -r --arg k "$key" '.[$k]')
            echo "Verifying $key: $id"

            # Verify attestation exists and is valid
            if ! gh attestation verify \
              --repo ${{ github.repository }} \
              --attestation-id "$id" 2>/dev/null; then
              echo "::error::Failed to verify attestation: $key ($id)"
              FAILED=$((FAILED + 1))
            else
              echo "✓ $key verified"
            fi
          done

          if [ $FAILED -gt 0 ]; then
            echo "::error::$FAILED attestation(s) failed verification"
            exit 1
          fi

          echo "All attestations verified successfully"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Attest verification
        id: attest-verify
        uses: actions/attest-build-provenance@v3
        with:
          subject-name: "attestation-verification"
          subject-digest: "sha256:${{ hashFiles('charts/**') }}"
```

### 3. Determine Version Bump
```yaml
      - name: Determine chart
        id: chart
        run: |
          # Find which chart changed
          CHART=$(git diff --name-only origin/main...HEAD | \
            grep '^charts/' | \
            cut -d'/' -f2 | \
            sort -u | \
            head -1)

          echo "name=$CHART" >> $GITHUB_OUTPUT

      - name: Run release-please (dry-run)
        id: release-please
        uses: googleapis/release-please-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          config-file: release-please-config.json
          manifest-file: .release-please-manifest.json
          dry-run: true

      - name: Parse version bump
        id: version
        run: |
          CHART="${{ steps.chart.outputs.name }}"
          CURRENT=$(grep '^version:' "charts/$CHART/Chart.yaml" | awk '{print $2}')

          # Get new version from release-please output or calculate
          NEW_VERSION="${{ steps.release-please.outputs[format('charts/{0}--version', steps.chart.outputs.name)] }}"

          if [ -z "$NEW_VERSION" ]; then
            # Fallback: bump patch
            NEW_VERSION=$(echo "$CURRENT" | awk -F. '{print $1"."$2"."$3+1}')
          fi

          echo "current=$CURRENT" >> $GITHUB_OUTPUT
          echo "new=$NEW_VERSION" >> $GITHUB_OUTPUT
          echo "Version: $CURRENT -> $NEW_VERSION"
```

### 4. Apply Version Bump
```yaml
      - name: Update Chart.yaml
        run: |
          CHART="${{ steps.chart.outputs.name }}"
          NEW_VERSION="${{ steps.version.outputs.new }}"

          # Update version in Chart.yaml
          sed -i "s/^version: .*/version: $NEW_VERSION/" "charts/$CHART/Chart.yaml"

          echo "Updated charts/$CHART/Chart.yaml to version $NEW_VERSION"

      - name: Commit version bump
        run: |
          CHART="${{ steps.chart.outputs.name }}"
          NEW_VERSION="${{ steps.version.outputs.new }}"

          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git add "charts/$CHART/Chart.yaml"
          git commit -m "chore($CHART): bump version to $NEW_VERSION

Attestation verification: ${{ steps.attest-verify.outputs.attestation-id }}"

          git push origin HEAD:${{ github.head_ref }}

      - name: Attest version bump
        id: attest-semver
        uses: actions/attest-build-provenance@v3
        with:
          subject-path: "charts/${{ steps.chart.outputs.name }}/Chart.yaml"
```

### 5. Generate Overall Attestation
```yaml
      - name: Generate attestation manifest
        run: |
          cat > attestation-manifest.json <<EOF
          {
            "version": "1.0",
            "chart": "${{ steps.chart.outputs.name }}",
            "new_version": "${{ steps.version.outputs.new }}",
            "pr": ${{ github.event.pull_request.number }},
            "commit": "${{ github.sha }}",
            "lineage": ${{ steps.attestations.outputs.map }},
            "this_stage": {
              "verification": "${{ steps.attest-verify.outputs.attestation-id }}",
              "semver-bump": "${{ steps.attest-semver.outputs.attestation-id }}"
            }
          }
          EOF

      - name: Overall attestation
        id: attest-overall
        uses: actions/attest-build-provenance@v3
        with:
          subject-path: "attestation-manifest.json"

      - name: Update PR description
        run: |
          # Add this stage's attestations to the map
          update_attestation_map "workflow-5-verify" "${{ steps.attest-verify.outputs.attestation-id }}"
          update_attestation_map "workflow-5-semver" "${{ steps.attest-semver.outputs.attestation-id }}"
          update_attestation_map "workflow-5-overall" "${{ steps.attest-overall.outputs.attestation-id }}"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Shared Components Used
- `actions/attest-build-provenance@v3`
- `googleapis/release-please-action@v4`
- `gh attestation verify`
- `update_attestation_map` function
- Attestation map parsing
- Version bump logic

## Error Handling
- Missing attestation map: Fail with clear error
- Attestation verification failure: Fail and list which failed
- Version bump conflict: Alert and require manual resolution

## Sequence Diagram
```
┌────────┐     ┌──────────┐     ┌─────────────┐     ┌────────────┐
│   PR   │     │ Workflow │     │ Attestation │     │ Chart.yaml │
│ opened │     │    5     │     │    API      │     │            │
└───┬────┘     └────┬─────┘     └──────┬──────┘     └─────┬──────┘
    │               │                   │                  │
    │ PR opened     │                   │                  │
    │──────────────►│                   │                  │
    │               │                   │                  │
    │               │ Extract map       │                  │
    │◄──────────────│                   │                  │
    │ (body)        │                   │                  │
    │──────────────►│                   │                  │
    │               │                   │                  │
    │               │ Verify each       │                  │
    │               │──────────────────►│                  │
    │               │                   │                  │
    │               │ Results           │                  │
    │               │◄──────────────────│                  │
    │               │                   │                  │
    │               │ Bump version      │                  │
    │               │─────────────────────────────────────►│
    │               │                   │                  │
    │               │ Attest bump       │                  │
    │               │──────────────────►│                  │
    │               │                   │                  │
    │               │ Overall attest    │                  │
    │               │──────────────────►│                  │
    │               │                   │                  │
    │ Update desc   │                   │                  │
    │◄──────────────│                   │                  │
```
