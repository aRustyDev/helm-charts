# Claude Code Project Context

## Key Decisions

### Versioning: Release-Please
This repo uses release-please for automated version management. **Do not manually bump chart versions** - release-please handles this based on conventional commits.

- `check-version-increment: false` in ct.yaml/ct-install.yaml
- See [ADR-006](../docs/src/adr/006-release-please-versioning.md) for details

### CI Testing: Separate Configs
Charts requiring external services are excluded from install tests but still linted.

- `ct.yaml` - lint config (all charts)
- `ct-install.yaml` - install config (excludes charts needing external services)
- See [ADR-007](../docs/src/adr/007-separate-ct-configs.md) for details

### Workflow Authentication: GitHub App Token Pattern
When a workflow needs elevated permissions (bypass branch protection, trigger other workflows, push to protected branches), **use a GitHub App token instead of `GITHUB_TOKEN`**.

**Pattern (with 1Password - Preferred):**
```yaml
jobs:
  generate-token:
    runs-on: ubuntu-latest
    outputs:
      token: ${{ steps.app-token.outputs.token }}
    steps:
      - name: Load secrets from 1Password
        id: op-secrets
        uses: 1password/load-secrets-action@v2
        with:
          export-env: false
        env:
          OP_SERVICE_ACCOUNT_TOKEN: ${{ secrets.OP_SERVICE_ACCOUNT_TOKEN }}
          X_REPO_AUTH_APP_ID: op://gh-shared/xauth/app/id
          X_REPO_AUTH_PRIVATE_KEY: op://gh-shared/xauth/app/private-key.pem

      - uses: actions/create-github-app-token@v1
        id: app-token
        with:
          app-id: ${{ steps.op-secrets.outputs.X_REPO_AUTH_APP_ID }}
          private-key: ${{ steps.op-secrets.outputs.X_REPO_AUTH_PRIVATE_KEY }}

  my-job:
    needs: [generate-token]
    steps:
      - uses: actions/checkout@v4
        with:
          token: ${{ needs.generate-token.outputs.token }}
```

**When to use:**
- Pushing to protected branches
- Bypassing ruleset rules
- Creating PRs/commits that should trigger other workflows
- Any operation where `GITHUB_TOKEN` is insufficient

**Do NOT use `GITHUB_TOKEN` for:** force pushes, ruleset bypass, triggering workflows

- See [GitHub App Authentication Guide](../docs/src/ci/github-app-auth.md) for full details
- See [ADR-012](../docs/src/adr/012-github-app-token-pattern.md) for decision rationale

## CI Configuration Quick Reference

| Setting | Value | Reason |
|---------|-------|--------|
| `validate-maintainers` | `true` | Ensures maintainer GitHub usernames are valid |
| `check-version-increment` | `false` | Release-please handles versioning |

### Labels Strategy
Repository uses a structured labeling system for issues and PRs.

- See [Labels Strategy](memory/repo-labels.md) for the full label list and usage guidelines
- Key categories: Status (`pending`, `tagged`), Scope (`chart`, `cicd`), Kind (`bug`, `enhancement`), Flags (`automation`, `release`)

## Architecture Decision Records

Full ADRs are located in `docs/src/adr/`:
- [ADR-006: Release-Please for Helm Chart Versioning](../docs/src/adr/006-release-please-versioning.md)
- [ADR-007: Separate Chart-Testing Configs for Lint vs Install](../docs/src/adr/007-separate-ct-configs.md)
- [ADR-010: Linear History and Rebase Workflow](../docs/src/adr/010-linear-history-rebase.md)
- [ADR-011: Full Atomization Model](../docs/src/adr/011-full-atomization-model.md)
- [ADR-012: GitHub App Token Pattern for Workflows](../docs/src/adr/012-github-app-token-pattern.md)
