# Claude Code Project Context

## Key Decisions

### Versioning: Git-Cliff + Version Bump Script
This repo uses **git-cliff** for changelog generation and a custom **version-bump.sh** script for semantic versioning. **Do not manually bump chart versions** - the W5 workflow handles this based on conventional commits.

- `check-version-increment: false` in ct.yaml/ct-install.yaml (version bumping happens in W5, not during lint)
- See [ADR-003](../docs/src/adr/003-semantic-versioning.md) for the versioning approach

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

### Chart Release Pipeline
The repository uses an atomic branching model with attestation-backed releases:

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **W1** | PR to `integration` | Lint, validate commits, preview changelog |
| **W2** | Push to `integration` | Create per-chart atomic branches + PRs to main |
| **W5** | PR to `main` | Deep validation, K8s tests, version bump |
| **W6** | Push to `main` | Tag, package, sign, publish to GHCR |
| **Auto-Merge** | W1 completes | Enable auto-merge for trusted contributors |

- See [ADR-011](../docs/src/adr/011-full-atomization-model.md) for the full atomization model
- See [Workflow Architecture](../docs/src/ci/workflow-architecture.md) for detailed flow

## CI Configuration Quick Reference

| Setting | Value | Reason |
|---------|-------|--------|
| `validate-maintainers` | `true` | Ensures maintainer GitHub usernames are valid |
| `check-version-increment` | `false` | W5 handles version bumping |

### Labels Strategy
Repository uses a structured labeling system for issues and PRs.

- See [Labels Strategy](./memory/repo-labels.md) for the full label list and usage guidelines
- Key categories: Status (`pending`, `tagged`), Scope (`chart`, `cicd`), Kind (`bug`, `enhancement`), Flags (`automation`, `release`)

## Architecture Decision Records

Full ADRs are located in `docs/src/adr/`. Key ADRs for development:

- [ADR-003: Semantic Versioning with git-cliff](../docs/src/adr/003-semantic-versioning.md) - How versioning works
- [ADR-007: Separate Chart-Testing Configs](../docs/src/adr/007-separate-ct-configs.md) - Why ct.yaml vs ct-install.yaml
- [ADR-009: Trust-Based Auto-Merge](../docs/src/adr/009-integration-auto-merge.md) - Auto-merge for integration PRs
- [ADR-010: Linear History and Rebase Workflow](../docs/src/adr/010-linear-history-rebase.md) - Branch strategy
- [ADR-011: Full Atomization Model](../docs/src/adr/011-full-atomization-model.md) - Per-chart atomic releases
- [ADR-012: GitHub App Token Pattern](../docs/src/adr/012-github-app-token-pattern.md) - Elevated permissions

See [ADR Index](../docs/src/adr/index.md) for the complete list.
