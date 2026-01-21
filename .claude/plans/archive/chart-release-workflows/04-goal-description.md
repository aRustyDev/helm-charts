# GOAL: Helm Chart Release Workflow with Attestation Lineage

## Executive Summary

Build a **fully automated, attestation-backed Helm chart release pipeline** that provides cryptographic proof of every step from initial contribution to final release. The system enforces atomic releases (one chart per release), maintains an unbroken chain of attestations for audit and verification, and publishes charts to multiple destinations (GHCR, GitHub Releases, release branch).

---

## Core Principles

### 1. Attestation Lineage
Every action in the release pipeline is attested using GitHub Attestations (SLSA/In-Toto format). Each attestation references its predecessors, creating a verifiable chain from the initial contribution to the final published artifact.

```
┌─────────────────┐
│ lint-test       │──┐
│ (v1.32.11)      │  │
└─────────────────┘  │
                     │    ┌─────────────────┐
┌─────────────────┐  ├───►│ Overall         │
│ lint-test       │──┤    │ Attestation     │───► ...chain continues...
│ (v1.33.7)       │  │    │ (PR merge)      │
└─────────────────┘  │    └─────────────────┘
                     │
┌─────────────────┐  │
│ artifacthub     │──┘
│ lint            │
└─────────────────┘
```

### 2. Atomic Releases
Each chart is released independently, even when multiple charts change in the same contribution. This ensures:
- Clear versioning per chart
- Independent rollback capability
- Isolated failure domains

### 3. Immutable Tags
Release tags (`<chart>-vX.Y.Z`) are immutable once created. They:
- Can only be created by workflows (not manually)
- Can only point to commits on Main
- Cannot be deleted or modified
- Contain attestation lineage in annotations

### 4. Defense in Depth
Multiple layers of protection:
- Branch protection rulesets
- Workflow-based source branch validation
- Attestation verification at each stage
- Human review gates at Workflows 1 and 5

---

## Branch Architecture

### Long-Lived Branches

| Branch | Purpose | Protection |
|--------|---------|------------|
| `main` | Stable, reviewed code | No deletion, no push (admin bypass for emergencies) |
| `integration` | Staging area for contributions | No deletion, no push (admin bypass) |
| `release` | Published chart packages | No deletion, no push (no bypass) |

### Dynamic Branches

| Pattern | Purpose | Lifecycle |
|---------|---------|-----------|
| `integration/<chart>` | Per-chart atomic changes | Created by Workflow 2, deleted after merge to Main |
| `feat/*`, `fix/*`, etc. | Developer feature branches | Created by developers, deleted after merge to Integration |

### Branch Flow Diagram

```
Developer creates feature branch
         │
         ▼
    ┌─────────┐     Workflow 1: Validate
    │ Feature │─────────────────────────────►┌─────────────┐
    │ Branch  │  PR + Checks + Attestations  │ Integration │
    └─────────┘                              └──────┬──────┘
                                                    │
         Workflow 2: Filter Charts (on merge)       │
         ◄──────────────────────────────────────────┘
         │
         ▼ (for each chart changed)
    ┌────────────────────┐   Workflow 3: Enforce Atomic
    │ Integration/<chart>│◄──────────────────────────────
    └─────────┬──────────┘   Auto-merge from Integration
              │
              │  Workflow 4: Format (on merge)
              ▼
    ┌─────────────────────┐   Workflow 5: Validate & SemVer
    │ PR to Main          │─────────────────────────────────►┌──────┐
    │ (attestation verify)│   Bump version, human review     │ Main │
    └─────────────────────┘                                  └──┬───┘
                                                                │
         Workflow 6: Tagging (on merge)                         │
         ◄──────────────────────────────────────────────────────┘
         │
         ▼ Create immutable tag + Open PR
    ┌─────────────────────┐   Workflow 7: Atomic Releases
    │ PR to Release       │─────────────────────────────────►┌─────────┐
    │ (build chart)       │   Verify at TAG, build package   │ Release │
    └─────────────────────┘                                  └────┬────┘
                                                                  │
         Workflow 8: Publishing (on merge)                        │
         ◄────────────────────────────────────────────────────────┘
         │
         ▼
    ┌─────────────────────────────────────┐
    │ GHCR │ GitHub Release │ Release Branch │
    └─────────────────────────────────────┘
```

---

## Workflow Details

### Workflow 1: Validate Initial Contribution

**Trigger**: PR opened `Feature -> Integration`

**Purpose**: Validate code quality, security, and generate attestations for all checks.

**Checks**:
| Check | Purpose | Attestation |
|-------|---------|-------------|
| `lint-test (v1.32.11)` | K8s 1.32 compatibility | ✓ |
| `lint-test (v1.33.7)` | K8s 1.33 compatibility | ✓ |
| `lint-test (v1.34.3)` | K8s 1.34 compatibility | ✓ |
| `artifacthub-lint` | Artifact Hub metadata | ✓ |
| `security` (TBD) | Security scanning | ✓ |
| `commit-validation` | Conventional commits | ✓ |
| `changelog-generation` | Keep-a-Changelog diff | ✓ |

**Attestation Storage**:
```markdown
<!-- ATTESTATION_MAP
{
  "lint-test-v1.32.11": "123456",
  "lint-test-v1.33.7": "234567",
  "lint-test-v1.34.3": "345678",
  "artifacthub-lint": "456789",
  "security": "567890",
  "commit-validation": "678901",
  "changelog-generation": "789012"
}
-->
```

**Rulesets**:
- All required checks must pass
- Admin bypass allowed (for emergencies)

**Human Review**: PRIMARY REVIEW GATE

---

### Workflow 2: Filter Charts

**Trigger**: Merge to `Integration` with changes in `/charts/**`

**Purpose**: Detect changed charts and create per-chart branches for atomic processing.

**Actions**:
1. Detect all charts modified in the merge
2. For each chart:
   ```bash
   git checkout integration/<chart> 2>/dev/null || git checkout -b integration/<chart> integration
   git checkout <merge-sha> -- charts/<chart>/
   git commit -m "chore(<chart>): sync from integration"
   git push origin integration/<chart>
   ```
3. Open PR: `Integration -> Integration/<chart>` (or update existing PR)

**Rulesets**:
- `Integration` protected from deletion (no bypass)
- `Integration` protected from push (admin bypass)

---

### Workflow 3: Enforce Atomic Chart PRs

**Trigger**: PR opened `Integration -> Integration/<chart>`

**Purpose**: Validate source branch and auto-merge.

**Actions**:
1. Validate source branch is `integration` (workflow-based enforcement)
2. If invalid source: auto-close PR with explanation
3. If valid: auto-merge immediately

**Rulesets**:
- `Integration/<chart>` protected from push (no bypass)
- Only `Integration` can be source (workflow-enforced)

**Human Review**: None (validated by attestation chain)

---

### Workflow 4: Format Atomic Chart PRs

**Trigger**: Merge to `Integration/<chart>`

**Purpose**: Create PR to Main with proper formatting.

**Actions**:
1. Open PR: `Integration/<chart> -> Main`
2. PR body includes:
   - Reference to source PR (that merged to Integration)
   - Attestation map copied from source PR
   - Link to attestation lineage

---

### Workflow 5: Validate & SemVer Bump Atomic Chart PRs

**Trigger**: PR opened `Integration/<chart> -> Main`

**Purpose**: Verify attestation chain, bump version, prepare for release.

**Checks**:
| Check | Purpose |
|-------|---------|
| `verify-attestations` | Validate all required attestations exist and are valid |
| `semver-bump` | Determine and apply version bump via release-please |

**Actions**:
1. Parse attestation map from PR description
2. Verify each attestation ID via `gh attestation verify`
3. Run release-please to determine version bump
4. Commit Chart.yaml version change to PR branch
5. Generate Overall Attestation:
   - Subject: Commit SHA + PR Description SHA
   - Predicate: All attestation IDs in lineage
6. Store Overall Attestation ID in PR description

**Rulesets**:
- All required checks must pass (no bypass)

**Human Review**: SECONDARY REVIEW GATE

---

### Workflow 6: Atomic Chart Tagging

**Trigger**: Merge to `Main` with changes in `/charts/**`

**Purpose**: Create immutable tag and prepare release PR.

**Actions**:
1. For each chart changed:
   - Read version from Chart.yaml
   - Create annotated tag `<chart>-vX.Y.Z`:
     ```bash
     git tag -a <chart>-v<version> -m "$(cat <<EOF
     Release: <chart> v<version>

     Attestation Lineage:
     - Workflow 1: <attestation-id>
     - Workflow 5: <attestation-id>

     Changelog:
     <diff-changelog>
     EOF
     )"
     ```
   - Push tag to origin
2. Open PR: `Main -> Release`

**Rulesets**:
- `Main` protected from deletion (no bypass)
- `Main` protected from push (admin bypass)
- `<chart>-vX.Y.Z` tags protected from deletion (no bypass)
- `<chart>-vX.Y.Z` tags immutable (no bypass)
- Tags can only be created via workflow (restrict creations, no bypass)

---

### Workflow 7: Atomic Chart Releases

**Trigger**: PR opened `Main -> Release`

**Purpose**: Build chart package and verify attestations at tag.

**Checks**:
| Check | Purpose |
|-------|---------|
| `verify-attestations-at-tag` | Verify attestation lineage in tag annotation |
| `build-chart` | Package chart as .tgz |

**Actions**:
1. Checkout at tag
2. Verify all attestation IDs in tag annotation
3. Build chart package:
   ```bash
   helm package charts/<chart> -d .cr-release-packages/
   ```
4. Attest the built package:
   ```yaml
   - uses: actions/attest-build-provenance@v3
     with:
       subject-path: '.cr-release-packages/<chart>-<version>.tgz'
   ```
5. Store attestation ID in PR description
6. Generate Overall Attestation for release

**Rulesets**:
- Only `Main` can merge to `Release` (workflow-enforced)
- All required checks must pass (no bypass)

---

### Workflow 8: Atomic Release Publishing

**Trigger**: Merge to `Release`

**Purpose**: Publish chart to all destinations.

**Actions**:
1. **GHCR**:
   ```bash
   helm push <chart>-<version>.tgz oci://ghcr.io/<owner>/charts
   cosign sign --yes ghcr.io/<owner>/charts/<chart>@<digest>
   ```

2. **GitHub Release**:
   ```bash
   gh release create <chart>-v<version> \
     --title "<chart>: v<version>" \
     --notes-file <changelog> \
     <chart>-<version>.tgz \
     attestation-lineage.json \
     CHANGELOG.md \
     README.md \
     LICENSE
   ```

3. **Release Branch**: Already contains the chart source from merge

**Assets in GitHub Release**:
| Asset | Description |
|-------|-------------|
| `<chart>-<version>.tgz` | Packaged Helm chart |
| `<chart>-<version>.tgz.sig` | Cosign signature |
| `attestation-lineage.json` | Full chain of attestation IDs |
| `CHANGELOG.md` | Chart changelog |
| `README.md` | Chart documentation |
| `LICENSE` | Chart license |

**Rulesets**:
- `Release` protected from deletion (no bypass)
- `Release` protected from push (no bypass)

---

## Attestation Lineage Structure

### Per-Check Attestation
Each check produces an attestation:
```json
{
  "subject": {
    "name": "lint-test-v1.32.11",
    "digest": { "sha256": "<result-hash>" }
  },
  "predicate": {
    "_type": "https://slsa.dev/provenance/v1",
    "buildType": "https://github.com/actions/attest-build-provenance",
    "invocation": {
      "configSource": {
        "uri": "git+https://github.com/<owner>/<repo>@refs/heads/<branch>",
        "digest": { "sha1": "<commit>" }
      }
    }
  }
}
```

### Overall Attestation (PR level)
Captures the complete attestation map:
```json
{
  "subject": [
    { "name": "commit", "digest": { "sha1": "<commit-sha>" } },
    { "name": "pr-description", "digest": { "sha256": "<desc-hash>" } }
  ],
  "predicate": {
    "_type": "https://example.com/attestation-lineage/v1",
    "attestations": {
      "lint-test-v1.32.11": "123456",
      "lint-test-v1.33.7": "234567",
      "lint-test-v1.34.3": "345678",
      "artifacthub-lint": "456789",
      "security": "567890",
      "commit-validation": "678901",
      "changelog-generation": "789012"
    },
    "parent": null
  }
}
```

### Release Attestation (Tag level)
Includes full lineage:
```json
{
  "subject": {
    "name": "<chart>-<version>.tgz",
    "digest": { "sha256": "<package-hash>" }
  },
  "predicate": {
    "_type": "https://example.com/attestation-lineage/v1",
    "attestations": {
      "workflow-1-overall": "<id>",
      "workflow-5-semver": "<id>",
      "workflow-7-build": "<id>"
    },
    "lineage": [
      { "stage": "validation", "attestation": "<workflow-1-id>" },
      { "stage": "semver", "attestation": "<workflow-5-id>" },
      { "stage": "build", "attestation": "<workflow-7-id>" }
    ]
  }
}
```

---

## Required Rulesets Summary

### Branch Rulesets

| Branch Pattern | Deletion | Push | Merge Source | Admin Bypass |
|----------------|----------|------|--------------|--------------|
| `main` | Block | Block | Any (PR required) | Push only |
| `integration` | Block | Block | Any (PR required) | Push only |
| `integration/*` | Allow | Block | `integration` only (workflow) | None |
| `release` | Block | Block | `main` only (workflow) | None |

### Tag Rulesets

| Tag Pattern | Deletion | Update | Creation | Admin Bypass |
|-------------|----------|--------|----------|--------------|
| `*-v*` | Block | Block | Workflow only | None |

---

## Migration Steps

1. **Create `integration` branch** from `main`
2. **Rename `charts` to `release`**:
   ```bash
   git branch -m charts release
   git push origin release
   git push origin :charts
   ```
3. **Update Cloudflare Pages** to point to `release`
4. **Create rulesets** for all branches and tags
5. **Implement workflows** 1-8
6. **Update documentation** and CLAUDE.md
7. **Test with a chart change** end-to-end

---

## Success Criteria

1. ✓ Any chart change follows the full 8-workflow pipeline
2. ✓ All checks produce GitHub Attestations
3. ✓ Attestation lineage is verifiable from any point back to origin
4. ✓ Tags are immutable and can only be created on Main
5. ✓ Charts are published to GHCR, GitHub Releases, and release branch
6. ✓ No manual intervention required after Workflow 1 approval (except Workflow 5 secondary review)
7. ✓ Attestation verification fails if any upstream check was skipped or tampered
