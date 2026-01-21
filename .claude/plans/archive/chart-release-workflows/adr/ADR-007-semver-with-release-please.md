# ADR-007: SemVer Bumping with release-please

## Status
Proposed

## Context
Automatic semantic versioning requires:
- Parsing conventional commit messages
- Determining major/minor/patch bump
- Updating Chart.yaml version field
- Generating changelog entries

Several tools exist for this purpose. We need one that:
- Supports Helm charts natively
- Works with our PR-based workflow
- Integrates with GitHub Actions
- Has active maintenance

## Decision
Continue using **release-please** with modified integration:
- Invoke release-please in Workflow 5 (not as standalone workflow)
- Commit version changes directly to PR branch
- Skip release-please's GitHub Release creation (we handle this in Workflow 8)

### Integration Point
```yaml
# In Workflow 5: Validate & SemVer Bump
- name: Run release-please
  uses: googleapis/release-please-action@v4
  with:
    token: ${{ secrets.GITHUB_TOKEN }}
    config-file: release-please-config.json
    manifest-file: .release-please-manifest.json
    skip-github-release: true
```

### Configuration
```json
// release-please-config.json
{
  "packages": {
    "charts/cloudflared": {
      "release-type": "helm",
      "package-name": "cloudflared",
      "changelog-path": "CHANGELOG.md"
    }
  },
  "separate-pull-requests": true
}
```

## Tool Comparison

| Tool | Helm Support | PR-Based | Maturity | Recommendation |
|------|--------------|----------|----------|----------------|
| **release-please** | Native | Yes | High | **Selected** |
| semantic-release | Via plugin | No | High | Not suitable |
| chart-releaser | Native | No | High | Publishing only |
| vnext | Generic | No | Low | Too new |
| standard-version | Generic | No | Deprecated | Not maintained |

### Why release-please
1. **Native Helm support**: `release-type: helm` understands Chart.yaml
2. **PR-based**: Creates PRs for review (aligns with our workflow)
3. **Monorepo support**: Handles multiple charts with `separate-pull-requests`
4. **Conventional commits**: Uses the pattern we already follow
5. **Google-backed**: Active maintenance, large user base

### Known Issues and Mitigations
1. **"Resource not accessible by integration"**: Use `skip-github-release: true`, create releases via `gh` CLI
2. **Pending release blocking**: Process pending releases before running release-please

## Consequences

### Positive
- Proven tool with Helm-specific logic
- Automatic changelog generation
- Respects conventional commit patterns
- Already in use in this repo

### Negative
- API issues require workarounds
- Complex configuration for monorepos
- External dependency on Google's maintenance

## Alternatives Considered

### 1. Custom script
Write our own version bumping logic.
- **Rejected**: Reinventing the wheel, maintenance burden

### 2. semantic-release
Popular alternative with plugin ecosystem.
- **Rejected**: Commits directly to branches, no PR review step

### 3. chart-releaser only
Use chart-releaser for everything.
- **Rejected**: Doesn't handle version bumping, only packaging/publishing
