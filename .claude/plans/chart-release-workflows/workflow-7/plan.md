# Workflow 7: Atomic Chart Releases - Phase Plan

## Overview
**Trigger**: `pull_request` → `release` branch
**Purpose**: Verify attestations at tag, build chart packages, generate release attestations

---

## Relevant Skills

Load these skills before planning, research, or implementation:

| Skill | Path | Relevance |
|-------|------|-----------|
| **CI/CD GitHub Actions** | `~/.claude/skills/cicd-github-actions-dev/SKILL.md` | Attestation verification, artifact handling, gh CLI patterns |
| **Helm Chart Development** | `~/.claude/skills/k8s-helm-charts-dev/SKILL.md` | Chart packaging (`helm package`), dependencies, Chart.yaml |

**How to load**: Read the SKILL.md files at the start of implementation to access patterns and best practices.

---

## Prerequisites

### Shared Components Required (Build First)
- [x] `extract_attestation_map` shell function (implemented in attestation-lib.sh)
- [x] `verify_attestation_chain` shell function (implemented in attestation-lib.sh)
- [x] `validate_source_branch` shell function (implemented in attestation-lib.sh)
- [x] `detect_changed_charts` shell function (implemented in attestation-lib.sh)
- [x] `extract_changelog_for_version` shell function (implemented in attestation-lib.sh)

### Infrastructure Required
- [x] `release-branch-protection` ruleset configured (ID: 11884271)
- [x] `release` branch created (from `charts` branch)
- [x] Tag protection ruleset configured (ID: 11880166)
- [x] Workflow can access tags

### Upstream Dependencies
- [x] Workflow 6 creates the tags and PRs this workflow validates

### Key Assumptions
- **Single chart per PR**: Each release PR contains exactly ONE chart at ONE version
- **Tag exists before PR merge**: W6 creates the tag first, then opens the release PR

---

## Implementation Phases

### Phase 7.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: None

**Tasks**:
1. Create `.github/workflows/atomic-chart-releases.yaml`
2. Configure trigger for `pull_request` → `release`
3. Set up permissions (contents: read, packages: write, id-token: write, attestations: write)

**Deliverable**: Workflow triggers on PR to release branch

---

### Phase 7.2: Source Branch Validation
**Effort**: Low
**Dependencies**: Phase 7.1, `validate_source_branch`

**Tasks**:
1. Validate source branch is `main`
2. If invalid, fail with error message

**Code**:
```bash
if [[ "${{ github.head_ref }}" != "main" ]]; then
  echo "::error::Only 'main' branch can merge to 'release'"
  exit 1
fi
```

---

### Phase 7.3: Chart Detection and Validation
**Effort**: Low
**Dependencies**: Phase 7.1, `detect_changed_charts`

**Note**: Each release PR contains exactly ONE chart. This phase:
1. Extracts the chart from PR title
2. Validates the files changed actually match the titled chart (prevents mislabeled PRs)
3. Validates the tag exists

**Tasks**:
1. Extract chart name and version from PR title
2. **Validate PR title matches files changed** (security check)
3. Validate the tag exists
4. Store chart info for subsequent phases

**Code**:
```bash
# Extract from PR title "release: <chart>-v<version>"
PR_TITLE="${{ github.event.pull_request.title }}"
if [[ ! "$PR_TITLE" =~ ^release:\ ([a-z0-9-]+)-v([0-9]+\.[0-9]+\.[0-9]+.*)$ ]]; then
  echo "::error::Invalid PR title format. Expected: 'release: <chart>-v<version>'"
  exit 1
fi

CHART="${BASH_REMATCH[1]}"
VERSION="${BASH_REMATCH[2]}"
TAG="${CHART}-v${VERSION}"

echo "::notice::PR title indicates chart: $CHART v$VERSION"

# SECURITY CHECK: Validate PR title matches actual files changed
# Prevents scenario where PR for chart-foo is titled as chart-bar
CHANGED_CHARTS=$(git diff --name-only origin/release...HEAD | grep '^charts/' | cut -d'/' -f2 | sort -u)
CHART_COUNT=$(echo "$CHANGED_CHARTS" | grep -c . || true)

if [[ "$CHART_COUNT" -eq 0 ]]; then
  echo "::error::No chart changes detected in PR"
  exit 1
fi

if [[ "$CHART_COUNT" -gt 1 ]]; then
  echo "::error::Multiple charts changed in PR: $CHANGED_CHARTS"
  echo "::error::Each release PR must contain exactly ONE chart"
  exit 1
fi

ACTUAL_CHART=$(echo "$CHANGED_CHARTS" | head -1)
if [[ "$ACTUAL_CHART" != "$CHART" ]]; then
  echo "::error::PR title mismatch!"
  echo "::error::  Title claims: $CHART"
  echo "::error::  Files changed: $ACTUAL_CHART"
  echo "::error::This could indicate a mislabeled PR or attempted manipulation"
  exit 1
fi

echo "::notice::Validated: PR title matches files changed ($CHART)"

# Verify tag exists
if ! git rev-parse "$TAG" >/dev/null 2>&1; then
  echo "::error::Tag $TAG does not exist"
  exit 1
fi

# Verify Chart.yaml version matches PR title version
CHART_YAML_VERSION=$(grep '^version:' "charts/$CHART/Chart.yaml" | awk '{print $2}' | tr -d '"' | tr -d "'")
if [[ "$CHART_YAML_VERSION" != "$VERSION" ]]; then
  echo "::error::Version mismatch!"
  echo "::error::  PR title: $VERSION"
  echo "::error::  Chart.yaml: $CHART_YAML_VERSION"
  exit 1
fi

echo "::notice::Validated: Chart.yaml version matches PR title ($VERSION)"

echo "chart=$CHART" >> "$GITHUB_OUTPUT"
echo "version=$VERSION" >> "$GITHUB_OUTPUT"
echo "tag=$TAG" >> "$GITHUB_OUTPUT"
```

---

### Phase 7.4: Tag Attestation Verification
**Effort**: High
**Dependencies**: Phase 7.3, `verify_attestation_chain`

**Note**: `gh attestation verify` verifies artifacts against attestations, NOT attestations by ID. We use `gh api` to verify attestation existence.

**Tasks**:
1. Get tag annotation content
2. Parse attestation lineage section
3. Verify each attestation ID exists via GitHub API
4. Log verification results

**Tag Annotation Format** (from W6):
```
Release: <chart> v<version>

Attestation Lineage:
- lint-test-v1.32.11: 12345678
- lint-test-v1.33.1: 12345679

Changelog:
...
```

**Code**:
```bash
TAG="${{ steps.chart.outputs.tag }}"
REPO="${{ github.repository }}"

# Get tag annotation
ANNOTATION=$(git tag -l --format='%(contents)' "$TAG")

if [[ -z "$ANNOTATION" ]]; then
  echo "::error::Tag $TAG has no annotation"
  exit 1
fi

# Extract attestation lineage section
# Format: "- check_name: attestation_id"
ATTESTATION_SECTION=$(echo "$ANNOTATION" | sed -n '/^Attestation Lineage:/,/^$/p' | grep '^- ')

if [[ -z "$ATTESTATION_SECTION" || "$ATTESTATION_SECTION" == *"No attestation data"* ]]; then
  echo "::warning::No attestation data found in tag annotation"
  # Decide: fail or warn-only for missing attestations
  # For now, continue with warning
else
  VERIFIED=0
  FAILED=0

  while IFS= read -r line; do
    # Parse "- check_name: attestation_id"
    CHECK_NAME=$(echo "$line" | sed 's/^- //' | cut -d: -f1)
    ATTESTATION_ID=$(echo "$line" | cut -d: -f2 | tr -d ' ')

    echo "::group::Verifying: $CHECK_NAME"
    echo "Attestation ID: $ATTESTATION_ID"

    # Verify attestation exists via GitHub API
    if gh api "/repos/$REPO/attestations/$ATTESTATION_ID" >/dev/null 2>&1; then
      echo "::notice::Verified: $CHECK_NAME ($ATTESTATION_ID)"
      ((VERIFIED++))
    else
      echo "::error::Failed to verify: $CHECK_NAME ($ATTESTATION_ID)"
      ((FAILED++))
    fi
    echo "::endgroup::"
  done <<< "$ATTESTATION_SECTION"

  echo "::notice::Verification complete: $VERIFIED verified, $FAILED failed"

  if [[ $FAILED -gt 0 ]]; then
    echo "::error::Attestation verification failed"
    exit 1
  fi
fi
```

**Resolved Questions**:
- ✅ Tag existence: Verified in Phase 7.3
- ✅ Attestation verification: Use `gh api` to check attestation exists (attestations are immutable once created)

---

### Phase 7.5: Chart Package Building
**Effort**: Medium
**Dependencies**: Phase 7.3

**Note**: Single chart per PR - builds one package.

**Tasks**:
1. Set up Helm CLI
2. Run `helm package` for the chart
3. Store package in `.cr-release-packages/`
4. Calculate package digest

**Code**:
```bash
CHART="${{ steps.chart.outputs.chart }}"
VERSION="${{ steps.chart.outputs.version }}"

mkdir -p .cr-release-packages

helm package "charts/$CHART" -d .cr-release-packages/

# Calculate digest
PACKAGE_FILE=".cr-release-packages/${CHART}-${VERSION}.tgz"
DIGEST=$(sha256sum "$PACKAGE_FILE" | cut -d' ' -f1)

echo "package=$PACKAGE_FILE" >> "$GITHUB_OUTPUT"
echo "digest=sha256:$DIGEST" >> "$GITHUB_OUTPUT"
```

---

### Phase 7.6: Build Attestation Generation
**Effort**: High
**Dependencies**: Phase 7.5

**Tasks**:
1. For each chart package, generate build attestation
2. Subject: the .tgz file with its digest
3. Store attestation IDs

**Code**:
```yaml
- uses: actions/attest-build-provenance@v3
  with:
    subject-path: '.cr-release-packages/${{ steps.chart.outputs.name }}-${{ steps.chart.outputs.version }}.tgz'
```

---

### Phase 7.7: Overall Attestation
**Effort**: Medium
**Dependencies**: Phase 7.4, Phase 7.6

**Note**: Single chart per PR - generates one overall attestation per release.

**Tasks**:
1. Generate attestation manifest JSON for the chart
2. Include all attestation IDs (upstream from tag + build attestation)
3. Generate overall attestation
4. Update PR description with attestation summary

**Manifest Format**:
```json
{
  "version": "1.0",
  "stage": "release-build",
  "chart": {
    "name": "<chart>",
    "version": "<version>",
    "digest": "<sha256>",
    "tag": "<chart>-v<version>"
  },
  "pr": <pr-number>,
  "attestations": {
    "upstream": {
      "lint-test-v1.32.11": "<id>",
      "lint-test-v1.33.1": "<id>"
    },
    "build": "<id>"
  }
}
```

---

### Phase 7.8: Artifact Upload (Optional)
**Effort**: Low
**Dependencies**: Phase 7.5

**Note**: This uploads the chart package as a **workflow artifact** for inspection/debugging. This is NOT the distribution mechanism - W8 commits packages to the release branch for distribution via charts.arusty.dev and ArtifactHub.

**Tasks**:
1. Upload chart package as workflow artifact
2. Enable download for manual inspection (expires in 90 days by default)

**Code**:
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: chart-package-${{ steps.chart.outputs.chart }}-${{ steps.chart.outputs.version }}
    path: .cr-release-packages/${{ steps.chart.outputs.chart }}-${{ steps.chart.outputs.version }}.tgz
    retention-days: 30  # Optional: reduce from default 90
```

---

### Phase 7.9: Status Check Registration
**Effort**: Low
**Dependencies**: All previous phases

**Tasks**:
1. Register workflow as required check
2. Configure in ruleset

---

## File Structure

```
.github/
├── workflows/
│   └── atomic-chart-releases.yaml    # Main workflow
└── scripts/
    └── attestation-lib.sh            # Shared functions
```

---

## Dependencies Graph

```
┌──────────────────────┐
│ Workflow 6 creates   │
│ PR to release        │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 7.1: Base      │
│ Workflow             │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 7.2: Source    │
│ Branch Validation    │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ Phase 7.3: Chart     │
│ Detection            │
└──────────┬───────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐ ┌─────────────┐
│Phase 7.4│ │Phase 7.5    │
│Tag      │ │Build        │
│Verify   │ │Packages     │
└────┬────┘ └──────┬──────┘
     │             │
     │       ┌─────┴─────┐
     │       ▼           ▼
     │  ┌─────────┐ ┌─────────────┐
     │  │Phase 7.6│ │Phase 7.8    │
     │  │Build    │ │Artifact     │
     │  │Attest   │ │Upload       │
     │  └────┬────┘ └─────────────┘
     │       │
     └───────┼───────┘
             ▼
┌──────────────────────┐
│ Phase 7.7: Overall   │
│ Attestation          │
└──────────────────────┘
```

---

## Open Questions

1. ✅ **Tag Availability**: What if PR is opened before tags are pushed?
   - **Resolved**: W6 creates tag BEFORE opening the release PR, so tag always exists
   - Phase 7.3 validates tag existence and fails fast if missing

2. ✅ **Attestation Subject**: For build attestation, use file path or digest?
   - **Resolved**: Use `subject-path` with the `.tgz` file - the action calculates the digest automatically

3. ✅ **Multiple Charts**: Process in parallel or sequential?
   - **Resolved**: N/A - each release PR contains exactly ONE chart

4. ✅ **Failed Verification**: Block entire PR or just flag the chart?
   - **Resolved**: Block the PR - attestation verification failure means the release cannot proceed

5. ✅ **Artifact Retention / Chart Packages**:
   - **Clarification**: There are TWO types of "artifacts":
     - **Workflow artifacts** (`actions/upload-artifact`): Temporary files stored by GitHub Actions (default 90 days). Used for debugging/inspection. NOT for distribution.
     - **Chart packages** (`.tgz` files): The actual Helm chart archives for distribution.
   - **Distribution flow**: Chart packages are committed to the `release` branch (W8) to be served via:
     - `charts.arusty.dev` (GitHub Pages)
     - ArtifactHub.io (reads from the repo)
   - **W7 role**: W7 builds and attests the `.tgz` package. W8 commits it to the release branch and publishes.
   - **Workflow artifact**: Optional - can upload for inspection/download, but the authoritative distribution is via the release branch.

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Tag not found | High | Phase 7.3 validates tag exists early; W6 creates tag before PR |
| Attestation verification fails | High | Clear error, block merge (intended behavior) |
| Helm package fails | High | Validate chart before building; ct lint runs in earlier workflows |
| GitHub API rate limits | Medium | Use exponential backoff for attestation verification |
| Package already exists in release | Low | Check before commit (W8 responsibility) |

---

## Success Criteria

- [ ] Workflow triggers on PR to release branch
- [ ] Validates source branch is `main`
- [ ] Extracts chart name/version from PR title (format: `release: <chart>-v<version>`)
- [ ] **Validates PR title matches actual files changed** (security check)
- [ ] **Validates Chart.yaml version matches PR title version**
- [ ] Validates tag exists and has annotation
- [ ] Verifies attestation IDs from tag annotation via GitHub API
- [ ] Builds single chart package successfully
- [ ] Generates build attestation for the package
- [ ] Generates overall attestation with upstream + build attestations
- [ ] Updates PR description with attestation summary
- [ ] (Optional) Uploads package as workflow artifact for inspection
- [ ] Workflow completes in < 5 minutes (single chart should be fast)
