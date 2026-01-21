# Workflow 1: Validate Initial Contribution

## Goal
Validate all contributions to the Integration branch through comprehensive checks, generate attestations for each check, and store attestation IDs in the PR description.

## Trigger
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - integration
```

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| PR Number | `github.event.pull_request.number` | PR to validate |
| PR Head SHA | `github.event.pull_request.head.sha` | Commit to validate |
| PR Body | `github.event.pull_request.body` | Existing attestation map (if any) |
| Chart Paths | `charts/**` | Changed chart directories |

## Outputs

| Output | Destination | Description |
|--------|-------------|-------------|
| Attestation IDs | PR Description | JSON map of check → attestation ID |
| Check Statuses | GitHub Checks API | Pass/fail for each check |
| Changelog Diff | PR Description or Comment | Generated changelog entries |

## Controls (Rulesets)

| Control | Setting |
|---------|---------|
| Required checks | All checks must pass |
| Admin bypass | Allowed (emergency merges) |
| PR required | Yes |
| Review required | Yes (at least 1) |

## Processes

### 1. Matrix Lint-Test (Kubernetes Versions)
```yaml
strategy:
  matrix:
    k8s-version: ['v1.32.11', 'v1.33.7', 'v1.34.3']

steps:
  - name: Set up chart-testing
    uses: helm/chart-testing-action@v2

  - name: Lint and test
    run: ct lint-and-install --config ct.yaml

  - name: Attest results
    uses: actions/attest-build-provenance@v3
    with:
      subject-name: "lint-test-${{ matrix.k8s-version }}"
      subject-path: test-results.json

  - name: Store attestation ID
    run: |
      # Update PR description with attestation ID
      update_attestation_map "lint-test-${{ matrix.k8s-version }}" "${{ steps.attest.outputs.attestation-id }}"
```

### 2. ArtifactHub Lint
```yaml
steps:
  - name: Run ArtifactHub linter
    run: ah lint

  - name: Attest results
    uses: actions/attest-build-provenance@v3

  - name: Store attestation ID
    run: update_attestation_map "artifacthub-lint" "$ATTESTATION_ID"
```

### 3. Security Scanning (Placeholder)
```yaml
steps:
  - name: Security scan
    run: |
      # TBD: trivy, kubesec, etc.
      echo "Security scanning placeholder"

  - name: Attest results
    uses: actions/attest-build-provenance@v3

  - name: Store attestation ID
    run: update_attestation_map "security" "$ATTESTATION_ID"
```

### 4. Commit Message Validation
```yaml
steps:
  - name: Validate conventional commits
    uses: wagoid/commitlint-github-action@v5

  - name: Attest results
    uses: actions/attest-build-provenance@v3

  - name: Store attestation ID
    run: update_attestation_map "commit-validation" "$ATTESTATION_ID"
```

### 5. Changelog Generation
```yaml
steps:
  - name: Generate changelog diff
    run: |
      # Use git-cliff or conventional-changelog
      git-cliff --unreleased > changelog-diff.md

  - name: Attest results
    uses: actions/attest-build-provenance@v3
    with:
      subject-path: changelog-diff.md

  - name: Store attestation ID
    run: update_attestation_map "changelog-generation" "$ATTESTATION_ID"
```

## Shared Components Used
- `update_attestation_map` (shell function/action)
- `actions/attest-build-provenance@v3`
- `helm/chart-testing-action@v2`
- Attestation map JSON format

## Error Handling
- If any check fails, PR cannot be merged (ruleset enforced)
- Attestation failures should fail the workflow
- Retry logic for PR description updates (race conditions)

## Sequence Diagram
```
┌────────┐     ┌──────────┐     ┌───────────┐     ┌─────────────┐
│  Dev   │     │  GitHub  │     │ Workflow  │     │ Attestation │
└───┬────┘     └────┬─────┘     └─────┬─────┘     └──────┬──────┘
    │               │                 │                   │
    │ Open PR       │                 │                   │
    │──────────────►│                 │                   │
    │               │ Trigger         │                   │
    │               │────────────────►│                   │
    │               │                 │                   │
    │               │                 │ Run checks        │
    │               │                 │──────────────────►│
    │               │                 │                   │
    │               │                 │ Attestation IDs   │
    │               │                 │◄──────────────────│
    │               │                 │                   │
    │               │ Update PR desc  │                   │
    │               │◄────────────────│                   │
    │               │                 │                   │
    │ Review        │                 │                   │
    │◄──────────────│                 │                   │
    │               │                 │                   │
    │ Merge         │                 │                   │
    │──────────────►│                 │                   │
```
