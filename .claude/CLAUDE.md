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

## CI Configuration Quick Reference

| Setting | Value | Reason |
|---------|-------|--------|
| `validate-maintainers` | `true` | Ensures maintainer GitHub usernames are valid |
| `check-version-increment` | `false` | Release-please handles versioning |

### Labels Strategy
Repository uses a structured labeling system for issues and PRs.

- See [Labels Strategy](memory/repo-labels.md) for the full label list and usage guidelines
- Key categories: Status (`pending`, `tagged`), Scope (`chart`, `cicd`), Kind (`bug`, `enhancement`), Flags (`automation`, `release`)

### Atomization Workflow
The integration branch uses the **Full Atomization Model** for automatic content extraction:

- PRs to `integration` are validated, then content is extracted to atomic branches (`chart/`, `docs/`, `ci/`)
- Integration resets to main after extraction (no divergence)
- See [ADR-011](../docs/src/adr/011-full-atomization-model.md) for details

**Key files**:
- `.github/workflows/atomic-branching-preview.yaml` - Phase 1: PR validation
- `.github/workflows/atomize-integration-pr.yaml` - Phase 2: Extract and reset
- `.github/actions/configs/atomic-branches.json` - Branch patterns and relationships
- `.github/actions/atomize/lib/atomize.sh` - Core functions
- `.github/actions/atomize/lib/relationships.sh` - 5-tier relationship determination

**Commit conventions for atomization**:
- `related:` footer to link files across categories
- `requires: <uuid>` footer to bundle commits
- See [Commit Conventions](../docs/src/contributing/commit-conventions.md)

## Architecture Decision Records

Full ADRs are located in `docs/src/adr/`:
- [ADR-006: Release-Please for Helm Chart Versioning](../docs/src/adr/006-release-please-versioning.md)
- [ADR-007: Separate Chart-Testing Configs for Lint vs Install](../docs/src/adr/007-separate-ct-configs.md)
- [ADR-009: Trust-Based Auto-Merge for Integration](../docs/src/adr/009-integration-auto-merge.md)
- [ADR-010: Linear History and Rebase Workflow](../docs/src/adr/010-linear-history-rebase.md)
- [ADR-011: Full Atomization Model](../docs/src/adr/011-full-atomization-model.md)
