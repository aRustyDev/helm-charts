# ADR-001: Charts Branch for Artifacts

## Status

Accepted

## Context

Helm chart repositories require serving static files (`index.yaml` and `.tgz` packages) over HTTP. We need to decide where to store these built artifacts:

1. **Same branch as source** (e.g., `main` with `/docs` directory)
2. **Dedicated branch** (e.g., `gh-pages` or `charts`)
3. **External hosting** (e.g., S3, GCS, Artifactory)

### Considerations

- **Source vs. artifacts**: Chart templates (source) and packaged charts (artifacts) have different lifecycles
- **Git history**: Large `.tgz` binaries pollute git history if on main branch
- **Tooling**: `chart-releaser-action` defaults to `gh-pages` branch
- **Clarity**: Branch naming should reflect content

## Decision

Use a dedicated `charts` branch for storing packaged Helm chart artifacts.

### Why "charts" instead of "gh-pages"?

- **Semantic naming**: `charts` describes what the branch contains, not where it's deployed
- **Platform agnostic**: Works with GitHub Pages, Cloudflare Pages, or any static host
- **Discoverability**: Clearer intent when browsing repository

### Implementation

```yaml
# chart-releaser-action configuration
- uses: helm/chart-releaser-action@v1.7.0
  with:
    pages_branch: charts  # Override default 'gh-pages'
```

## Consequences

### Positive

- Clean separation of source code and built artifacts
- Main branch history only shows code changes
- Branch name clearly indicates purpose
- Compatible with multiple hosting platforms

### Negative

- Two branches to understand (main for source, charts for artifacts)
- Requires configuring `pages_branch` in chart-releaser-action
- GitHub Pages must be manually configured to use `charts` branch

### Neutral

- chart-releaser-action handles branch creation and updates automatically
- No impact on end users (they only interact with the HTTP endpoint)
