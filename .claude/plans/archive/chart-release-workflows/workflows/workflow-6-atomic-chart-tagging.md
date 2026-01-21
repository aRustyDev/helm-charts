# Workflow 6: Atomic Chart Tagging

## Goal
When changes merge to main, create immutable annotated tags with attestation lineage, then open a PR to the release branch.

## Trigger
```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'charts/**'
```

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| Merge Commit | `github.sha` | The merge commit on main |
| Changed Charts | `git diff` | Charts that changed |
| Source PR | `gh pr list` | The PR that was merged |
| Attestation Map | PR Body | Full attestation lineage |

## Outputs

| Output | Destination | Description |
|--------|-------------|-------------|
| Tag | `<chart>-v<version>` | Immutable annotated tag |
| Release PR | GitHub PR | `main -> release` PR |
| Tag Annotation | Tag object | Attestation lineage + changelog |

## Controls (Rulesets)

| Control | Setting |
|---------|---------|
| `main` deletion | Blocked (no bypass) |
| `main` push | Blocked (admin bypass) |
| `<chart>-v*` deletion | Blocked (no bypass) |
| `<chart>-v*` update | Blocked (no bypass) |
| `<chart>-v*` creation | Blocked (no bypass, workflow only) |

## Processes

### 1. Detect Changed Charts
```yaml
jobs:
  create-tags:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 2

      - name: Detect changed charts
        id: charts
        run: |
          CHARTS=$(git diff --name-only HEAD~1 HEAD | \
            grep '^charts/' | \
            cut -d'/' -f2 | \
            sort -u)

          echo "list=$CHARTS" >> $GITHUB_OUTPUT
          echo "Changed charts: $CHARTS"
```

### 2. Get Source PR and Attestations
```yaml
      - name: Get source PR
        id: source
        run: |
          # Find the PR that created this merge commit
          PR_DATA=$(gh pr list \
            --state merged \
            --search "${{ github.sha }}" \
            --json number,body,title \
            --limit 1 \
            -q '.[0]')

          PR_NUMBER=$(echo "$PR_DATA" | jq -r '.number')
          PR_BODY=$(echo "$PR_DATA" | jq -r '.body')

          # Extract attestation map
          ATTESTATION_MAP=$(echo "$PR_BODY" | \
            grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | \
            tr -d '\0')

          echo "pr_number=$PR_NUMBER" >> $GITHUB_OUTPUT
          echo "attestation_map<<EOF" >> $GITHUB_OUTPUT
          echo "$ATTESTATION_MAP" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 3. Generate Changelog Diff
```yaml
      - name: Generate changelog
        id: changelog
        run: |
          for chart in ${{ steps.charts.outputs.list }}; do
            if [ -f "charts/$chart/CHANGELOG.md" ]; then
              VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')

              # Extract changelog for this version
              CHANGELOG=$(awk "/^## \\[$VERSION\\]/{flag=1; next} /^## \\[/{flag=0} flag" \
                "charts/$chart/CHANGELOG.md")

              echo "${chart}_changelog<<EOF" >> $GITHUB_OUTPUT
              echo "$CHANGELOG" >> $GITHUB_OUTPUT
              echo "EOF" >> $GITHUB_OUTPUT
            fi
          done
```

### 4. Create Annotated Tags
```yaml
      - name: Create tags
        id: tags
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          CREATED_TAGS=""

          for chart in ${{ steps.charts.outputs.list }}; do
            VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
            TAG_NAME="${chart}-v${VERSION}"

            # Check if tag already exists
            if git rev-parse "$TAG_NAME" >/dev/null 2>&1; then
              echo "Tag $TAG_NAME already exists, skipping"
              continue
            fi

            # Get chart-specific changelog
            CHANGELOG="${{ steps.changelog.outputs[format('{0}_changelog', chart)] }}"

            # Create annotated tag with attestation lineage
            git tag -a "$TAG_NAME" -m "$(cat <<EOF
Release: $chart v$VERSION

Attestation Lineage:
$(echo '${{ steps.source.outputs.attestation_map }}' | jq -r 'to_entries | .[] | "- \(.key): \(.value)"')

Changelog:
$CHANGELOG

Source PR: #${{ steps.source.outputs.pr_number }}
Commit: ${{ github.sha }}
EOF
)"

            echo "Created tag: $TAG_NAME"
            CREATED_TAGS="$CREATED_TAGS $TAG_NAME"
          done

          echo "tags=$CREATED_TAGS" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Push tags
        run: |
          for tag in ${{ steps.tags.outputs.tags }}; do
            git push origin "$tag"
            echo "Pushed tag: $tag"
          done
```

### 5. Create Release PR
```yaml
      - name: Create release PR
        run: |
          # Check for existing PR
          EXISTING=$(gh pr list \
            --head main \
            --base release \
            --state open \
            --json number \
            -q '.[0].number')

          if [ -n "$EXISTING" ]; then
            echo "PR #$EXISTING already exists, it will auto-update"
            exit 0
          fi

          CHARTS="${{ steps.charts.outputs.list }}"
          TAGS="${{ steps.tags.outputs.tags }}"

          gh pr create \
            --head main \
            --base release \
            --title "release: $(echo $TAGS | tr ' ' ', ')" \
            --body "$(cat <<EOF
## Release

### Tags Created
$(for tag in $TAGS; do echo "- \`$tag\`"; done)

### Charts
$(for chart in $CHARTS; do
  version=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
  echo "- **$chart**: v$version"
done)

### Attestation Lineage

<!-- ATTESTATION_MAP
${{ steps.source.outputs.attestation_map }}
-->

### Source
- PR: #${{ steps.source.outputs.pr_number }}
- Commit: \`${{ github.sha }}\`

---
*Auto-generated by Workflow 6: Atomic Chart Tagging*
EOF
)"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Shared Components Used
- `actions/checkout@v4`
- `gh` CLI for PR operations
- Git tagging operations
- Attestation map extraction
- Changelog parsing

## Error Handling
- Tag already exists: Skip (idempotent)
- Push fails: Retry (network issues)
- PR creation fails: Check for existing PR

## Sequence Diagram
```
┌──────────┐     ┌──────────┐     ┌─────────┐     ┌─────────┐
│ Merge to │     │ Workflow │     │  Tags   │     │ Release │
│   main   │     │    6     │     │         │     │   PR    │
└────┬─────┘     └────┬─────┘     └────┬────┘     └────┬────┘
     │                │                 │               │
     │ Merge          │                 │               │
     │───────────────►│                 │               │
     │                │                 │               │
     │                │ Get PR + attest │               │
     │                │─────────────────│               │
     │                │                 │               │
     │                │ Create tags     │               │
     │                │────────────────►│               │
     │                │                 │               │
     │                │ Push tags       │               │
     │                │────────────────►│               │
     │                │                 │               │
     │                │ Create PR       │               │
     │                │────────────────────────────────►│
     │                │                 │               │
     │                │ Done            │               │
     │◄───────────────│                 │               │
```
