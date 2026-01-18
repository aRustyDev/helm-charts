# ADR-003: Semantic Versioning with git-cliff

## Status

Accepted (Updated 2025-01-17)

## Context

Chart versions need to be managed systematically. Options considered:

1. **Manual versioning**: Developers update `Chart.yaml` version manually
2. **release-please**: Creates release PRs for review before publishing
3. **git-cliff + custom script**: Automated versioning during PR validation

### Considerations

- **Helm charts are in a monorepo**: Multiple charts in `charts/` directory
- **Atomic releases**: Each chart should be versioned independently
- **Changelog generation**: Automatic based on commits
- **Conventional commits**: Required for automation
- **PR workflow**: Version bumps should happen during PR validation, not as separate PRs

## Decision

Use **git-cliff** for changelog generation and a custom **version-bump.sh** script for semantic version calculation. Version bumping occurs during W5 (PR validation) workflow.

### Why git-cliff over release-please?

| Feature | git-cliff + W5 | release-please |
|---------|---------------|----------------|
| Version bump timing | During PR validation | Separate release PR |
| Changelog generation | Per-chart, customizable | Per-package |
| Monorepo support | Custom script handles | Native but complex |
| Integration | Built into validation workflow | Separate workflow |
| Merge overhead | Single PR per chart | Feature PR + Release PR |

### Commit Convention

| Commit Type | Version Bump | Example |
|-------------|--------------|---------|
| `fix(chart):` | Patch (0.0.X) | `fix(cloudflared): correct port` |
| `feat(chart):` | Minor (0.X.0) | `feat(cloudflared): add HPA` |
| `feat(chart)!:` or `BREAKING CHANGE:` | Major (X.0.0) | `feat(cloudflared)!: change values schema` |
| `chore:`, `docs:`, `ci:` | No bump | `chore: update readme` |

## Implementation

### W5 Version Bump Job

```yaml
# validate-atomic-chart-pr.yaml
version-bump:
  needs: [validate-and-detect, artifacthub-lint, helm-lint, k8s-matrix-test]
  if: all validations pass
  steps:
    - name: Install git-cliff
      run: |
        curl -sSL https://github.com/orhun/git-cliff/releases/... | tar xz
        sudo mv git-cliff /usr/local/bin/

    - name: Bump Version and Generate Changelog
      run: |
        source .github/scripts/version-bump.sh
        bump_chart_version "$chart" "origin/main"

    - name: Commit Version Bump
      run: |
        git add "charts/$chart/Chart.yaml" "charts/$chart/CHANGELOG.md"
        git commit -m "chore(release): bump versions"
        git push origin HEAD:${{ branch }}
```

### version-bump.sh Logic

```bash
bump_chart_version() {
  local chart=$1
  local base_ref=$2

  # Get commits for this chart since base
  commits=$(git log --format="%s" "$base_ref..HEAD" -- "charts/$chart/")

  # Determine bump type from conventional commits
  if echo "$commits" | grep -qE "^feat.*!:|BREAKING CHANGE:"; then
    bump_type="major"
  elif echo "$commits" | grep -qE "^feat(\(|:)"; then
    bump_type="minor"
  elif echo "$commits" | grep -qE "^fix(\(|:)"; then
    bump_type="patch"
  else
    bump_type="none"
  fi

  # Apply bump to Chart.yaml
  # Generate changelog with git-cliff
}
```

### Changelog Generation

git-cliff generates per-chart changelogs using `.github/cliff.toml`:

```toml
[changelog]
header = "# Changelog\n\n"
body = """
{% for group, commits in commits | group_by(attribute="group") %}
### {{ group | upper_first }}
{% for commit in commits %}
- {{ commit.message | upper_first }}
{% endfor %}
{% endfor %}
"""

[git]
conventional_commits = true
filter_unconventional = true
commit_parsers = [
  { message = "^feat", group = "Features" },
  { message = "^fix", group = "Bug Fixes" },
  { message = "^doc", group = "Documentation" },
  { message = "^perf", group = "Performance" },
  { message = "^refactor", group = "Refactoring" },
]
```

## Consequences

### Positive

- **Single PR workflow**: No separate release PRs cluttering the PR list
- **Immediate feedback**: Version bump happens during validation
- **Per-chart changelogs**: Each chart has its own CHANGELOG.md
- **Customizable**: git-cliff templates are fully configurable
- **Atomic releases**: Each chart versioned independently

### Negative

- **Custom script maintenance**: version-bump.sh requires maintenance
- **Learning curve**: Team must use conventional commits
- **Commit dependency**: Bad commit messages = bad version bumps

### Neutral

- Chart version in `Chart.yaml` is automatically bumped in PR
- Changelog is committed alongside version bump
- Works with existing chart-testing configuration

## Related

- [ADR-007: Separate Chart-Testing Configs](007-separate-ct-configs.md)
- [Workflow 5: Validate Atomic Chart PR](.github/workflows/validate-atomic-chart-pr.yaml)
- [git-cliff Documentation](https://git-cliff.org/)
