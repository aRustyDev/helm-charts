# ADR-005: CI/CD Workflow Architecture

## Status

Accepted (Updated 2025-01-17)

## Context

A Helm chart repository requires multiple CI/CD workflows for:
- Validation (linting, testing)
- Release management (versioning, publishing)
- Documentation (building, deploying)
- Maintenance (branch cleanup, automation)

These workflows must work together without conflicts, minimize redundant runs, provide clear feedback to contributors, and maintain an attestation chain for security.

## Decision

We implement a **multi-stage attestation-backed workflow architecture** with clear separation of concerns:

```
Developer PR → integration (W1) → W2 creates atomic PRs → main (W5) → Release
```

### Core Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| **W1** | `validate-contribution-pr.yaml` | PR to `integration` | Initial validation, changelog preview |
| **W2** | `create-atomic-chart-pr.yaml` | Push to `integration` | Create per-chart PRs to main |
| **W5** | `validate-atomic-chart-pr.yaml` | PR to `main` | Deep validation, version bump, K8s matrix |
| **Release** | `release-atomic-chart.yaml` | Push to `main` | Tag, package, sign, publish |

### Supporting Workflows

| Workflow | File | Trigger | Purpose |
|----------|------|---------|---------|
| Docs | `docs.yaml` | PR/push (docs/) | Documentation validation and deployment |
| Cleanup | `cleanup-branches.yaml` | Weekly, manual | Remove orphan branches |

### Workflow Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Developer Workflow                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  W1: Validate Contribution PR                                            │
│  ─────────────────────────────                                           │
│  Trigger: PR to integration                                              │
│  Jobs:                                                                   │
│    • lint (chart-testing)                                                │
│    • artifacthub-lint (metadata validation)                              │
│    • commit-validation (conventional commits)                            │
│    • changelog (preview with git-cliff)                                  │
│    • enable-automerge (trust-based, if CODEOWNER + verified)            │
│  Output: Attestation map in PR description                               │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (merge to integration)
┌─────────────────────────────────────────────────────────────────────────┐
│  W2: Create Atomic Chart PR                                              │
│  ──────────────────────────                                              │
│  Trigger: Push to integration                                            │
│  Jobs:                                                                   │
│    • detect-changes (find changed charts)                                │
│    • process-charts (create charts/<chart> branch + PR to main)          │
│    • finalize (generate W2 attestation)                                  │
│  Output: Per-chart PRs to main with attestation lineage                  │
│  Dispatch: Triggers W5 via repository_dispatch                           │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (repository_dispatch)
┌─────────────────────────────────────────────────────────────────────────┐
│  W5: Validate Atomic Chart PR                                            │
│  ────────────────────────────                                            │
│  Trigger: PR to main (or repository_dispatch from W2)                    │
│  Jobs:                                                                   │
│    • validate-dispatch (actor validation for dispatch events)            │
│    • validate-and-detect (source branch + chart detection)               │
│    • artifacthub-lint                                                    │
│    • helm-lint                                                           │
│    • k8s-matrix-test (v1.32, v1.33, v1.34)                              │
│    • version-bump (semver + changelog with git-cliff)                    │
│    • update-attestation (embed map in PR)                                │
│    • cleanup-branch (on merge)                                           │
│  Output: Validated chart with bumped version                             │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ (merge to main)
┌─────────────────────────────────────────────────────────────────────────┐
│  Release: Release Atomic Chart                                           │
│  ─────────────────────────────                                           │
│  Trigger: Push to main (charts/**)                                       │
│  Jobs:                                                                   │
│    • detect-and-tag (create git tags)                                    │
│    • package-charts (helm package + attestation)                         │
│    • publish-releases (GHCR + Cosign + GitHub Release)                   │
│    • update-release-branch (index.yaml)                                  │
│  Output: Published chart on all distribution channels                    │
└─────────────────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Attestation Chain**: Each workflow generates attestations that flow through the pipeline
2. **Atomic Releases**: Each chart is released independently via dedicated PRs
3. **Single Responsibility**: Each workflow does one thing well
4. **Event-Driven**: Workflows respond to specific events (PR, push, dispatch)
5. **Trust-Based Automation**: Auto-merge for trusted contributors with verified commits
6. **Path Filtering**: Only run when relevant files change
7. **Matrix Testing**: Test across multiple Kubernetes versions
8. **Concurrency Control**: Prevent duplicate runs with concurrency groups

## Implementation

### Attestation Flow

```yaml
# W1 generates attestations for each validation step
- name: Generate attestation
  uses: actions/attest-build-provenance@v2
  with:
    subject-name: "w1-lint"

# W2 extracts and forwards attestation map
- name: Extract attestation map from source PR
  run: |
    ATTESTATION_MAP=$(extract_attestation_map "$SOURCE_PR")

# W5 validates and adds its own attestations
# Release workflow includes full lineage in tags and releases
```

### Repository Dispatch (W2→W5)

```yaml
# W2 triggers W5 after creating PR
- name: Trigger W5 validation
  run: |
    gh api "repos/${{ github.repository }}/dispatches" \
      --method POST \
      -f event_type=chart-pr-created \
      -f client_payload='{"pr": $PR_NUMBER, "chart": "$CHART"}'

# W5 validates the dispatch actor
validate-dispatch:
  if: github.event_name == 'repository_dispatch'
  steps:
    - name: Validate Actor
      run: |
        if [[ ! ",$ALLOWED_DISPATCH_ACTORS," =~ ",${{ github.actor }}," ]]; then
          exit 1
        fi
```

### Concurrency

```yaml
# Per-PR concurrency for W5
concurrency:
  group: w5-validate-${{ github.event.pull_request.number || github.event.client_payload.pr }}
  cancel-in-progress: false

# Single-run concurrency for W2
concurrency:
  group: w2-filter-charts
  cancel-in-progress: false
```

## Consequences

### Positive

- **Clear workflow ownership**: Each workflow has a specific purpose
- **Efficient CI**: Only runs what's needed via path filtering
- **Security**: Attestation chain provides full provenance
- **Atomic releases**: Charts released independently
- **Kubernetes compatibility**: Matrix testing across versions
- **Automation**: Trust-based auto-merge reduces manual work

### Negative

- **Complexity**: Multiple workflows to understand
- **Debugging**: Issues may span multiple workflows
- **Documentation**: Requires understanding of full pipeline

### Neutral

- Requires understanding of GitHub Actions event model
- Branch protection rules must match workflow names
- Attestation verification requires `gh attestation verify`

## Related

- [ADR-003: Semantic Versioning with git-cliff](003-semantic-versioning.md)
- [ADR-004: Helm Chart Signing and Provenance](004-chart-signing.md)
- [ADR-008: Repository Dispatch for Workflow Automation](008-repository-dispatch-automation.md)
- [ADR-009: Trust-Based Auto-Merge](009-integration-auto-merge.md)
