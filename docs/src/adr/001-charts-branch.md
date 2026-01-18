# ADR-001: Release Branch for Artifacts

## Status

Accepted (Updated 2025-01-17)

## Context

Helm chart repositories require serving static files (`index.yaml` and `.tgz` packages) over HTTP. We need to decide where to store these built artifacts:

1. **Same branch as source** (e.g., `main` with `/docs` directory)
2. **Dedicated branch** (e.g., `gh-pages`, `charts`, or `release`)
3. **External hosting** (e.g., S3, GCS, Artifactory)

### Considerations

- **Source vs. artifacts**: Chart templates (source) and packaged charts (artifacts) have different lifecycles
- **Git history**: Large `.tgz` binaries pollute git history if on main branch
- **Clarity**: Branch naming should reflect content
- **Automation**: Branch should be easily updated by CI workflows

## Decision

Use a dedicated `release` branch for storing packaged Helm chart artifacts.

### Why "release" instead of "gh-pages" or "charts"?

- **Semantic naming**: `release` clearly indicates this branch contains release artifacts
- **Platform agnostic**: Works with GitHub Pages, Cloudflare Pages, or any static host
- **Workflow clarity**: Matches the release workflow that updates it
- **Separation of concerns**: Distinct from feature branches like `charts/<name>`

### Implementation

The `release-atomic-chart.yaml` workflow updates this branch after publishing:

```yaml
# Phase 4: Update release branch
update-release-branch:
  steps:
    - name: Checkout Release Branch
      uses: actions/checkout@v4
      with:
        ref: release

    - name: Update Release Branch
      run: |
        # Copy packages and update index.yaml
        helm repo index . --url "https://github.com/.../releases/download/$TAG" --merge index.yaml
        git add index.yaml *.tgz
        git commit -m "chore(release): publish charts"
        git push origin release
```

### Branch Contents

```
release/
├── index.yaml           # Helm repository index
├── <chart>-<version>.tgz  # Packaged charts
└── ...
```

## Consequences

### Positive

- Clean separation of source code and built artifacts
- Main branch history only shows code changes
- Branch name clearly indicates purpose
- Compatible with multiple hosting platforms
- Easy to configure static hosting from this branch

### Negative

- Two branches to understand (main for source, release for artifacts)
- Branch protection rules needed to prevent accidental pushes
- Packages duplicated in GitHub Releases and release branch

### Neutral

- Release workflow handles branch updates automatically
- No impact on end users (they only interact with the HTTP endpoint or OCI registry)
