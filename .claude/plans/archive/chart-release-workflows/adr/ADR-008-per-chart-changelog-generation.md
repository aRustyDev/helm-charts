# ADR-008: Per-Chart Changelog Generation with git-cliff

## Status
Accepted

## Context
The attestation-backed release pipeline needs to generate changelogs for each chart release. Key requirements:
- Generate changelog content for PR review and release notes
- Support multiple charts in a monorepo structure
- Use conventional commits as the source of truth
- Follow Keep-a-Changelog format for consistency
- Integrate with GitHub Actions workflows

We evaluated several approaches:
1. Combined changelog for all charts
2. Per-chart changelog generation
3. Manual changelog maintenance

## Decision
Generate changelogs **per-chart** using `git-cliff` with path-based filtering (`--include-path`).

### Tool Selection: git-cliff

**Selected**: `git-cliff` v2.11.0+

**Rationale**:
1. **Monorepo Support**: Built-in `--include-path` flag filters commits by directory
2. **Conventional Commits**: Native support for parsing conventional commit messages
3. **Keep-a-Changelog**: Configurable templates support the desired output format
4. **Performance**: Single Rust binary, fast execution
5. **Active Development**: Regular releases, well-maintained (v2.11.0 released Jan 2025)
6. **GitHub Action**: Official action available (`orhun/git-cliff-action@v4`)

### Per-Chart Invocation
```bash
# Generate changelog for specific chart
git cliff --include-path "charts/$CHART/**/*" --unreleased

# Or from chart directory (auto-scoped)
cd charts/$CHART && git cliff
```

### Configuration
```toml
# .github/cliff.toml
[git]
conventional_commits = true
filter_commits = true
commit_parsers = [
    { message = "^feat", group = "Features" },
    { message = "^fix", group = "Bug Fixes" },
    { message = "^docs", group = "Documentation" },
    { message = "^perf", group = "Performance" },
    { message = "^refactor", group = "Refactoring" },
    { message = "^chore", skip = true },
    { message = "^ci", skip = true },
]

[changelog]
header = "# Changelog\n\n"
body = """
{% for group, commits in commits | group_by(attribute="group") %}
## {{ group }}

{% for commit in commits %}
- {{ commit.message | split(pat="\n") | first }}
{% endfor %}

{% endfor %}
"""
```

### Workflow Integration
```yaml
# In W1: Validate Initial Contribution
- name: Generate changelog for changed charts
  run: |
    CHARTS=$(git diff --name-only origin/integration...HEAD | grep '^charts/' | cut -d'/' -f2 | sort -u)
    for chart in $CHARTS; do
      echo "## Changelog for $chart" >> changelog.md
      git cliff --include-path "charts/$chart/**/*" --unreleased >> changelog.md
    done

- name: Add changelog comment
  uses: peter-evans/create-or-update-comment@v4
  with:
    issue-number: ${{ github.event.pull_request.number }}
    body-file: changelog.md
```

## Consequences

### Positive
- Each chart has its own isolated changelog
- Only relevant commits appear in each chart's changelog
- Consistent formatting via git-cliff templates
- Automated generation reduces manual effort
- Changelog visible in PR for review

### Negative
- Additional CLI tool to install in workflows
- Configuration file maintenance required
- Scoped commits require conventional commit discipline

### Mitigations
- Cache git-cliff binary between workflow runs
- Enforce conventional commits via commitlint (W1)
- Document expected commit format in CONTRIBUTING.md

## Alternatives Considered

### 1. conventional-changelog-conventionalcommits-helm
A Node.js preset specifically for Helm charts.
- **URL**: https://github.com/scc-digitalhub/conventional-changelog-conventionalcommits-helm
- **Rejected**: Low adoption (0 stars), requires Node.js, last updated 2+ years ago

### 2. release-please built-in changelog
Use release-please's automatic changelog generation.
- **Rejected**: Tied to release-please's version bump flow, less control over format

### 3. Combined changelog
Single changelog for all charts in the repository.
- **Rejected**: Mixes unrelated changes, harder to review per-chart impact

### 4. Manual changelog
Require maintainers to update CHANGELOG.md manually.
- **Rejected**: Error-prone, inconsistent, doesn't leverage conventional commits

## References
- [git-cliff Documentation](https://git-cliff.org/)
- [git-cliff Monorepo Support](https://git-cliff.org/docs/usage/monorepos/)
- [git-cliff GitHub Action](https://github.com/marketplace/actions/git-cliff-changelog-generator)
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
