# Workflow 8: Atomic Release Publishing

## Goal
When changes merge to release, publish chart packages to GHCR and GitHub Releases with full attestation lineage, signatures, and release assets.

## Trigger
```yaml
on:
  push:
    branches:
      - release
    paths:
      - 'charts/**'
```

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| Merge Commit | `github.sha` | Merge commit on release |
| Tags | Git tags | `<chart>-v<version>` tags |
| Chart Packages | Build or regenerate | `.tgz` files |
| Attestation Lineage | PR Body / Tags | Full chain |

## Outputs

| Output | Destination | Description |
|--------|-------------|-------------|
| GHCR Packages | `ghcr.io/<owner>/charts/<chart>` | OCI artifacts |
| GHCR Signatures | GHCR | Cosign signatures |
| GitHub Releases | Releases page | Release with assets |
| Release Assets | GitHub Release | tgz, sig, changelog, etc. |

## Controls (Rulesets)

| Control | Setting |
|---------|---------|
| `release` deletion | Blocked (no bypass) |
| `release` push | Blocked (no bypass) |

## Processes

### 1. Setup
```yaml
jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      id-token: write
      attestations: write
    steps:
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

      - name: Set registry
        run: |
          echo "REGISTRY=ghcr.io/${GITHUB_REPOSITORY_OWNER,,}/charts" >> $GITHUB_ENV

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
```

### 2. Detect Charts to Publish
```yaml
      - name: Detect charts
        id: charts
        run: |
          CHARTS=$(git diff --name-only HEAD~1 HEAD | \
            grep '^charts/' | \
            cut -d'/' -f2 | \
            sort -u)

          echo "list=$CHARTS" >> $GITHUB_OUTPUT
```

### 3. Get Attestation Lineage
```yaml
      - name: Get source PR attestations
        id: attestations
        run: |
          # Find the PR that created this merge
          PR_DATA=$(gh pr list \
            --state merged \
            --search "${{ github.sha }}" \
            --json number,body \
            --limit 1 \
            -q '.[0]')

          PR_BODY=$(echo "$PR_DATA" | jq -r '.body')

          # Extract attestation map
          ATTESTATION_MAP=$(echo "$PR_BODY" | \
            grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | \
            tr -d '\0')

          echo "map<<EOF" >> $GITHUB_OUTPUT
          echo "$ATTESTATION_MAP" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 4. Build and Publish to GHCR
```yaml
      - name: Build and publish to GHCR
        id: ghcr
        run: |
          mkdir -p .cr-release-packages

          for chart in ${{ steps.charts.outputs.list }}; do
            VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
            TGZ=".cr-release-packages/${chart}-${VERSION}.tgz"

            echo "📦 Packaging $chart:$VERSION..."
            helm package "charts/$chart" -d .cr-release-packages/

            echo "🚀 Pushing to GHCR..."
            PUSH_OUTPUT=$(helm push "$TGZ" oci://$REGISTRY 2>&1)
            echo "$PUSH_OUTPUT"

            # Extract digest
            DIGEST=$(echo "$PUSH_OUTPUT" | grep -oP 'Digest: \Ksha256:[a-f0-9]+')
            echo "✅ Published $chart:$VERSION (digest: $DIGEST)"

            # Sign by digest
            if [ -n "$DIGEST" ]; then
              echo "🔏 Signing $REGISTRY/${chart}@${DIGEST}..."
              cosign sign --yes "$REGISTRY/${chart}@${DIGEST}"
              echo "✅ Signed"
            fi

            # Store digest for later
            echo "${chart}_digest=$DIGEST" >> $GITHUB_OUTPUT
            echo "${chart}_tgz=$TGZ" >> $GITHUB_OUTPUT
          done
```

### 5. Create GitHub Releases
```yaml
      - name: Create GitHub Releases
        run: |
          for chart in ${{ steps.charts.outputs.list }}; do
            VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
            TAG="${chart}-v${VERSION}"
            TGZ=".cr-release-packages/${chart}-${VERSION}.tgz"

            # Check if release already exists
            if gh release view "$TAG" &>/dev/null; then
              echo "Release $TAG already exists, updating assets..."
            else
              echo "Creating release $TAG..."

              # Get changelog from tag annotation
              CHANGELOG=$(git tag -l --format='%(contents)' "$TAG" | \
                awk '/^Changelog:/,/^[A-Z]/' | tail -n +2 | head -n -1)

              # Get attestation lineage from tag
              LINEAGE=$(git tag -l --format='%(contents)' "$TAG" | \
                awk '/^Attestation Lineage:/,/^Changelog:/' | tail -n +2 | head -n -1)

              gh release create "$TAG" \
                --title "$chart: v$VERSION" \
                --notes "$(cat <<EOF
## $chart v$VERSION

### Changelog
$CHANGELOG

### Attestation Lineage
$LINEAGE

### Installation

\`\`\`bash
# From GHCR (OCI)
helm install $chart oci://$REGISTRY/$chart --version $VERSION

# Verify signature
cosign verify $REGISTRY/$chart:$VERSION
\`\`\`

### Verification
\`\`\`bash
# Verify attestations
gh attestation verify $REGISTRY/$chart@${{ steps.ghcr.outputs[format('{0}_digest', chart)] }}
\`\`\`
EOF
)"
            fi

            # Upload assets
            echo "Uploading assets for $TAG..."

            # Chart package
            gh release upload "$TAG" "$TGZ" --clobber

            # Signature
            cosign sign-blob --yes --output-signature "${TGZ}.sig" "$TGZ"
            gh release upload "$TAG" "${TGZ}.sig" --clobber

            # Changelog
            if [ -f "charts/$chart/CHANGELOG.md" ]; then
              gh release upload "$TAG" "charts/$chart/CHANGELOG.md" --clobber
            fi

            # README
            if [ -f "charts/$chart/README.md" ]; then
              gh release upload "$TAG" "charts/$chart/README.md" --clobber
            fi

            # LICENSE
            if [ -f "charts/$chart/LICENSE" ]; then
              gh release upload "$TAG" "charts/$chart/LICENSE" --clobber
            elif [ -f "LICENSE" ]; then
              cp LICENSE "charts/$chart/LICENSE"
              gh release upload "$TAG" "charts/$chart/LICENSE" --clobber
            fi

            # Attestation lineage JSON
            cat > "${chart}-attestation-lineage.json" <<EOF
{
  "chart": "$chart",
  "version": "$VERSION",
  "tag": "$TAG",
  "digest": "${{ steps.ghcr.outputs[format('{0}_digest', chart)] }}",
  "attestations": ${{ steps.attestations.outputs.map }}
}
EOF
            gh release upload "$TAG" "${chart}-attestation-lineage.json" --clobber

            echo "✅ Release $TAG complete"
          done
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 6. Generate Summary
```yaml
      - name: Generate summary
        run: |
          echo "## 🚀 Charts Released" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Chart | Version | GHCR | GitHub Release | Signed |" >> $GITHUB_STEP_SUMMARY
          echo "|-------|---------|------|----------------|--------|" >> $GITHUB_STEP_SUMMARY

          for chart in ${{ steps.charts.outputs.list }}; do
            VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
            TAG="${chart}-v${VERSION}"
            GHCR_LINK="[\`$REGISTRY/${chart}:${VERSION}\`](https://github.com/${{ github.repository_owner }}/packages/container/charts%2F${chart})"
            GH_RELEASE="[$TAG](https://github.com/${{ github.repository }}/releases/tag/$TAG)"

            echo "| $chart | $VERSION | $GHCR_LINK | $GH_RELEASE | ✅ |" >> $GITHUB_STEP_SUMMARY
          done

          echo "" >> $GITHUB_STEP_SUMMARY
          echo "### Verification Commands" >> $GITHUB_STEP_SUMMARY
          echo '```bash' >> $GITHUB_STEP_SUMMARY
          echo "# Verify GHCR signature" >> $GITHUB_STEP_SUMMARY
          echo "cosign verify $REGISTRY/<chart>:<version>" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "# Verify attestations" >> $GITHUB_STEP_SUMMARY
          echo "gh attestation verify $REGISTRY/<chart>@<digest>" >> $GITHUB_STEP_SUMMARY
          echo '```' >> $GITHUB_STEP_SUMMARY
```

## Shared Components Used
- `actions/checkout@v4`
- `azure/setup-helm@v4`
- `sigstore/cosign-installer@v3`
- `docker/login-action@v3`
- `gh release create/upload`
- `helm push` (OCI)
- `cosign sign/sign-blob`
- Attestation map parsing

## Error Handling
- GHCR push fails: Retry (network issues)
- Release already exists: Update assets only
- Signing fails: Fail the workflow (security critical)
- Missing assets: Log warning, continue

## Assets Published

| Asset | Format | Purpose |
|-------|--------|---------|
| `<chart>-<version>.tgz` | Helm package | Chart installation |
| `<chart>-<version>.tgz.sig` | Cosign signature | Package verification |
| `CHANGELOG.md` | Markdown | Version history |
| `README.md` | Markdown | Documentation |
| `LICENSE` | Text | Legal |
| `<chart>-attestation-lineage.json` | JSON | Full attestation chain |

## Sequence Diagram
```
┌──────────┐     ┌──────────┐     ┌──────┐     ┌─────────┐     ┌─────────┐
│ Merge to │     │ Workflow │     │ GHCR │     │ Cosign  │     │ Release │
│ release  │     │    8     │     │      │     │         │     │         │
└────┬─────┘     └────┬─────┘     └──┬───┘     └────┬────┘     └────┬────┘
     │                │               │              │               │
     │ Merge          │               │              │               │
     │───────────────►│               │              │               │
     │                │               │              │               │
     │                │ Build pkg     │              │               │
     │                │───────────────│              │               │
     │                │               │              │               │
     │                │ helm push     │              │               │
     │                │──────────────►│              │               │
     │                │               │              │               │
     │                │ cosign sign   │              │               │
     │                │──────────────────────────────►              │
     │                │               │              │               │
     │                │ Create release│              │               │
     │                │──────────────────────────────────────────────►
     │                │               │              │               │
     │                │ Upload assets │              │               │
     │                │──────────────────────────────────────────────►
     │                │               │              │               │
     │ Complete       │               │              │               │
     │◄───────────────│               │              │               │
```
