# Helm Chart Release Workflow Architecture

This document describes the complete workflow for releasing Helm charts with attestation-backed validation.

## Overview

The workflow consists of 5 main stages:

| Stage | Workflow File | Trigger | Purpose |
|-------|---------------|---------|---------|
| W1 | `validate-contribution-pr.yaml` | PR to `integration` | Initial validation of contributions |
| W2 | `create-atomic-chart-pr.yaml` | Push to `integration` | Split into per-chart PRs to main |
| W5 | `validate-atomic-chart-pr.yaml` | PR to `main` | Deep validation + version bump + cleanup on merge |
| Release | `release-atomic-chart.yaml` | Push to `main` | Tag, package, publish |

## High-Level Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         HELM CHART RELEASE PIPELINE                          │
└─────────────────────────────────────────────────────────────────────────────┘

  Developer
      │
      │ Creates PR with chart changes
      ▼
┌─────────────┐     Merge      ┌─────────────┐     Creates     ┌─────────────┐
│   W1        │ ──────────────►│   W2        │ ───────────────►│   W5        │
│ Validate    │   to           │ Filter      │   PRs to        │ Validate    │
│ Contribution│   integration  │ Charts      │   main          │ & Bump      │
└─────────────┘                └─────────────┘                 └─────────────┘
      │                              │                               │
      │ Attestations:                │ Creates:                      │ Actions:
      │ • lint                       │ • charts/<chart> branch       │ • Lint + Test
      │ • artifacthub-lint          │ • PR to main                  │ • K8s matrix
      │ • commit-validation          │ • Attestation lineage         │ • Version bump
      │ • changelog                  │                               │ • Changelog
      └──────────────────────────────┴───────────────────────────────┘
                                                                      │
                                                                      │ Merge to main
                                                                      ▼
                                                               ┌─────────────┐
                                                               │ Chart       │
                                                               │ Release     │
                                                               │ Pipeline    │
                                                               └─────────────┘
                                                                      │
                                         ┌────────────────────────────┼────────────────────────────┐
                                         │                            │                            │
                                         ▼                            ▼                            ▼
                                  ┌─────────────┐              ┌─────────────┐              ┌─────────────┐
                                  │ Create Tags │              │ GHCR        │              │ GitHub      │
                                  │ <chart>-v   │              │ + Cosign    │              │ Releases    │
                                  │ <version>   │              │ Signing     │              │ + release   │
                                  └─────────────┘              └─────────────┘              │ branch      │
                                                                                            └─────────────┘
```

## Sequence Diagram

```
┌──────────┐  ┌───────────┐  ┌────────────┐  ┌──────┐  ┌──────┐  ┌───────────────┐
│Developer │  │integration│  │charts/<c>  │  │ main │  │ W1   │  │chart-release  │
└────┬─────┘  └─────┬─────┘  └─────┬──────┘  └──┬───┘  └──┬───┘  └───────┬───────┘
     │              │              │            │         │              │
     │  PR (chart changes)         │            │         │              │
     │─────────────►│              │            │         │              │
     │              │              │            │         │              │
     │              │──────────────────────────────────────►              │
     │              │   W1: Validate Contribution          │              │
     │              │   • lint, artifacthub-lint          │              │
     │              │   • commit-validation, changelog     │              │
     │              │◄─────────────────────────────────────┤              │
     │              │   Attestations stored in PR          │              │
     │              │              │            │         │              │
     │  Merge PR    │              │            │         │              │
     │─────────────►│              │            │         │              │
     │              │              │            │         │              │
     │              │──────────────────────────────────────►              │
     │              │   W2: Filter Charts                  │              │
     │              │   (on push to integration)           │              │
     │              │              │            │         │              │
     │              │  Create branch│            │         │              │
     │              │─────────────►│            │         │              │
     │              │              │            │         │              │
     │              │  Create PR   │            │         │              │
     │              │──────────────┼───────────►│         │              │
     │              │              │            │         │              │
     │              │              │            │─────────►              │
     │              │              │            │ W5: PR Validation      │
     │              │              │            │ • Lint + K8s tests     │
     │              │              │            │ • Version bump         │
     │              │              │            │ • CHANGELOG update     │
     │              │              │            │◄────────┤              │
     │              │              │            │ Commits pushed back    │
     │              │              │            │         │              │
     │  Approve & Merge PR to main │            │         │              │
     │─────────────────────────────┼───────────►│         │              │
     │              │              │            │         │              │
     │              │              │            │─────────────────────────►
     │              │              │            │ chart-release.yaml     │
     │              │              │            │ (on push to main)      │
     │              │              │            │         │              │
     │              │              │            │         │  • Create tag│
     │              │              │            │         │  • Package   │
     │              │              │            │         │  • Sign GHCR │
     │              │              │            │         │  • GH Release│
     │              │              │            │         │  • release   │
     │              │              │            │         │    branch    │
     │              │              │            │◄────────────────────────┤
     │              │              │            │   Delete charts/<c>    │
     │              │              │            │         │              │
     │◄─────────────────────────────────────────────────────────────────┤
     │              Chart Released!             │         │              │
```

---

## Workflow Details

### Validate Contribution PR (W1)

**File:** `.github/workflows/validate-contribution-pr.yaml`

#### Trigger
```yaml
on:
  pull_request:
    branches:
      - integration
```

#### Inputs
| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `test_all` | boolean | No | `false` | Test all charts, not just changed |

#### Jobs

| Job | Purpose | Attestation |
|-----|---------|-------------|
| `detect-changes` | Identify changed charts | - |
| `lint` | Helm chart linting (ct lint) | `w1-lint` |
| `artifacthub-lint` | ArtifactHub metadata validation | `w1-artifacthub-lint` |
| `commit-validation` | Conventional commit message validation | `w1-commit-validation` |
| `changelog` | Generate changelog preview | `w1-changelog` |

#### Outputs
- Attestations stored in PR description via `<!-- ATTESTATION_MAP {...} -->`
- Changelog preview comment on PR

#### Permissions
```yaml
permissions:
  contents: read
  pull-requests: write
  id-token: write
  attestations: write
```

#### Restrictions/Protections
- Branch protection on `integration` requires passing checks
- Attestations are cryptographically signed via GitHub's OIDC

---

### Create Atomic Chart PR (W2)

**File:** `.github/workflows/create-atomic-chart-pr.yaml`

#### Trigger
```yaml
on:
  push:
    branches:
      - integration
    paths:
      - 'charts/**'
```

#### Inputs
| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `dry_run` | boolean | No | `false` | Skip PR creation |

#### Jobs

| Job | Purpose |
|-----|---------|
| `detect-changes` | Find changed charts, extract attestation map from source PR |
| `process-charts` | Create `charts/<chart>` branch and PR to main (matrix) |
| `finalize` | Generate W2 attestation |

#### Actions
1. Detect which charts changed in the push
2. Find the source PR and extract its attestation map
3. For each changed chart:
   - Create/update `charts/<chart>` branch from `origin/main`
   - Cherry-pick chart changes
   - Create/update PR to `main` with attestation lineage

#### Outputs
- `charts/<chart>` branches created
- PRs to `main` created with attestation map embedded
- W2 attestation generated

#### Permissions
```yaml
permissions:
  contents: write
  pull-requests: write
  id-token: write
  attestations: write
```

#### Concurrency
```yaml
concurrency:
  group: w2-filter-charts
  cancel-in-progress: false
```

---

### Validate Atomic Chart PR (W5)

**File:** `.github/workflows/validate-atomic-chart-pr.yaml`

#### Trigger
```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, closed]
    branches:
      - main
    paths:
      - 'charts/**'
```

#### Inputs
| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `test_all` | boolean | No | `false` | Test all charts |
| `skip_version_bump` | boolean | No | `false` | Skip version bump (manual testing) |

#### Jobs

| Job | Runs When | Purpose |
|-----|-----------|---------|
| `validate-and-detect` | PR opened/sync | Validate source branch, detect changed charts |
| `artifacthub-lint` | PR opened/sync | ArtifactHub metadata validation |
| `helm-lint` | PR opened/sync | Helm chart linting |
| `k8s-matrix-test` | PR opened/sync | K8s install tests (v1.32, v1.33, v1.34) |
| `version-bump` | PR opened/sync | Determine semver bump, update Chart.yaml, generate CHANGELOG |
| `update-attestation` | PR opened/sync | Store attestation map in PR description |
| `summary` | PR opened/sync | Generate workflow summary |
| `cleanup-branch` | PR merged | Delete source branch |

#### Actions
1. **Validate source branch** - Expects `charts/<chart>` or `integration/<chart>` pattern
2. **Detect changed charts** - Uses `detect_changed_charts()` from attestation-lib
3. **Lint** - ArtifactHub + Helm chart-testing lint
4. **K8s Matrix Test** - Install tests on 3 K8s versions
5. **Version Bump** - Determine bump type from conventional commits:
   - `feat` → minor bump
   - `fix` → patch bump
   - `BREAKING CHANGE` or `!:` → major bump
6. **Changelog Generation** - Uses git-cliff with `cliff.toml` config
7. **Commit back** - Push version bump + changelog to PR branch
8. **Cleanup on merge** - Delete source branch when PR is merged

#### Outputs
- Version bump committed to PR branch
- CHANGELOG.md updated
- Attestation map stored in PR description
- Source branch deleted on merge

#### Permissions
```yaml
permissions:
  contents: write
  pull-requests: write
  id-token: write
  attestations: write
```

#### Concurrency
```yaml
concurrency:
  group: w5-validate-${{ github.event.pull_request.number || github.run_id }}
  cancel-in-progress: false
```

---

### Release Atomic Chart

**File:** `.github/workflows/release-atomic-chart.yaml`

#### Trigger
```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'charts/**'
```

#### Jobs

| Job | Purpose |
|-----|---------|
| `detect-and-tag` | Detect charts, find source PR, create git tags |
| `package-charts` | Build `.tgz` packages, generate attestations |
| `publish-releases` | Publish to GHCR, create GitHub Releases |
| `update-release-branch` | Update `release` branch with packages + index.yaml |
| `cleanup` | Delete `integration/<chart>` branches |
| `summary` | Generate workflow summary |

#### Actions

**Phase 1: Detect and Tag**
1. Detect changed charts in merge commit
2. Find source PR and extract attestation map
3. For each chart:
   - Get version from Chart.yaml
   - Create annotated tag `<chart>-v<version>` with:
     - Attestation lineage
     - Changelog excerpt
     - Source PR reference

**Phase 2: Package Charts**
1. Checkout tag
2. Validate Chart.yaml version matches tag
3. Run `helm package`
4. Generate build attestation
5. Upload artifact

**Phase 3: Publish Releases**
1. Download package artifact
2. Push to GHCR: `oci://ghcr.io/<owner>/<repo>/<chart>:<version>`
3. Sign with Cosign (keyless OIDC)
4. Create GitHub Release with:
   - Package `.tgz`
   - Signature `.sig`
   - Attestation lineage JSON

**Phase 4: Update Release Branch**
1. Checkout `release` branch
2. Copy packages
3. Run `helm repo index` to update `index.yaml`
4. Commit and push

**Phase 5: Cleanup**
1. Delete `integration/<chart>` branches

#### Outputs
- Git tags created
- Packages published to GHCR (signed)
- GitHub Releases created
- `release` branch updated with `index.yaml`

#### Permissions
```yaml
permissions:
  contents: write
  packages: write
  pull-requests: write
  id-token: write
  attestations: write
```

#### Concurrency
```yaml
concurrency:
  group: chart-release-${{ github.sha }}
  cancel-in-progress: false
```

---

## Attestation Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           ATTESTATION LINEAGE                                │
└─────────────────────────────────────────────────────────────────────────────┘

W1 (PR to integration)
   │
   ├─► lint attestation
   ├─► artifacthub-lint attestation
   ├─► commit-validation attestation
   └─► changelog attestation
         │
         │ Stored in PR description: <!-- ATTESTATION_MAP {...} -->
         │
         ▼
W2 (Push to integration)
   │
   ├─► Extracts attestation map from source PR
   └─► Carries forward to new PR
         │
         │ Embedded in PR to main: <!-- ATTESTATION_MAP {...} -->
         │
         ▼
W5 (PR to main)
   │
   ├─► k8s-install attestations (per K8s version)
   ├─► w5-verification attestation
   └─► w5-semver attestation
         │
         │ Updated in PR: <!-- W5_ATTESTATION_MAP {...} -->
         │
         ▼
Chart Release (Push to main)
   │
   ├─► Extracts attestation map from source PR
   ├─► Embeds in git tag annotation
   └─► build-provenance attestation (per package)
         │
         ▼
   Published artifacts with full lineage
```

---

## Branch Protection & Rulesets

### Protected Branches

| Branch | Protection |
|--------|------------|
| `main` | Require PR, require status checks, no force push |
| `integration` | Require PR, require status checks |
| `release` | Restrict pushes to workflow only |

### Tag Protection

| Pattern | Protection |
|---------|------------|
| `*-v[0-9]*` | Only workflow can create, no deletion |

### Required Status Checks

**For PRs to `integration`:**
- `lint`
- `artifacthub-lint`
- `commit-validation`

**For PRs to `main`:**
- `artifacthub-lint`
- `helm-lint`
- `k8s-test (v1.32.11)`
- `k8s-test (v1.33.7)`
- `k8s-test (v1.34.3)`

---

## Branch Naming Convention

W2 creates per-chart branches with the pattern `charts/<chart>`. W5 accepts both patterns for flexibility:

| Pattern | Created By | Purpose |
|---------|------------|---------|
| `charts/<chart>` | W2 | Primary pattern from automated workflow |
| `integration/<chart>` | Manual | Alternative for direct integration PRs |

Both patterns are accepted by W5 and cleaned up by the release pipeline.

---

## Distribution Channels

After a successful release, charts are available from:

| Channel | URL | Command |
|---------|-----|---------|
| **GHCR (OCI)** | `ghcr.io/<owner>/<repo>/<chart>:<version>` | `helm install <name> oci://ghcr.io/<owner>/<repo>/<chart> --version <version>` |
| **Helm Repo** | `https://charts.arusty.dev` | `helm repo add arustydev https://charts.arusty.dev` |
| **GitHub Releases** | `https://github.com/<owner>/<repo>/releases` | Download `.tgz` directly |

---

## Verification Commands

```bash
# Verify GHCR signature
cosign verify ghcr.io/<owner>/<repo>/<chart>@<digest>

# Verify attestations
gh attestation verify oci://ghcr.io/<owner>/<repo>/<chart>:<version> --repo <owner>/<repo>

# Verify GitHub Release signature
cosign verify-blob --signature <chart>-<version>.tgz.sig <chart>-<version>.tgz
```
