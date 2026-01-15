# Workflow 7: Atomic Chart Releases - Phase Plan

## Overview
**Trigger**: `pull_request` → `release` branch
**Purpose**: Verify attestations at tag, build chart packages, generate release attestations

---

## Prerequisites

### Shared Components Required (Build First)
- [ ] `extract_attestation_map` shell function
- [ ] `verify_attestation_chain` shell function
- [ ] `validate_source_branch` shell function
- [ ] `detect_changed_charts` shell function

### Infrastructure Required
- [ ] `release-protection` ruleset configured
- [ ] `release` branch created
- [ ] Workflow can access tags

### Upstream Dependencies
- [ ] Workflow 6 creates the tags and PRs this workflow validates

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

### Phase 7.3: Chart Detection
**Effort**: Low
**Dependencies**: Phase 7.1, `detect_changed_charts`

**Tasks**:
1. Detect charts changed between release and main
2. For each chart, get version from Chart.yaml
3. Construct expected tag names

---

### Phase 7.4: Tag Attestation Verification
**Effort**: High
**Dependencies**: Phase 7.3, `verify_attestation_chain`

**Tasks**:
1. For each chart, find the corresponding tag
2. Get tag annotation content
3. Extract attestation IDs from annotation
4. Verify each attestation ID
5. Generate verification attestation

**Code**:
```bash
for chart in $CHARTS; do
  VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
  TAG="${chart}-v${VERSION}"

  # Get tag annotation
  ANNOTATION=$(git tag -l --format='%(contents)' "$TAG")

  # Extract attestation IDs and verify
  echo "$ANNOTATION" | grep -oP '- \K[^:]+: \d+' | while read line; do
    key=$(echo "$line" | cut -d: -f1)
    id=$(echo "$line" | cut -d: -f2 | tr -d ' ')
    gh attestation verify --repo $REPO --attestation-id "$id"
  done
done
```

**Questions**:
- [ ] What if tag doesn't exist yet?
- [ ] How to verify attestations against correct subjects?

---

### Phase 7.5: Chart Package Building
**Effort**: Medium
**Dependencies**: Phase 7.3

**Tasks**:
1. Set up Helm CLI
2. For each chart, run `helm package`
3. Store packages in `.cr-release-packages/`
4. Calculate package digests

**Code**:
```bash
mkdir -p .cr-release-packages

for chart in $CHARTS; do
  VERSION=$(grep '^version:' "charts/$chart/Chart.yaml" | awk '{print $2}')
  helm package "charts/$chart" -d .cr-release-packages/

  # Calculate digest
  DIGEST=$(sha256sum ".cr-release-packages/${chart}-${VERSION}.tgz" | cut -d' ' -f1)
  echo "${chart}_digest=sha256:$DIGEST" >> $GITHUB_OUTPUT
done
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

**Tasks**:
1. Generate attestation manifest JSON
2. Include all attestation IDs (upstream + this stage)
3. Generate overall attestation
4. Update PR description

**Manifest Format**:
```json
{
  "version": "1.0",
  "stage": "release-build",
  "charts": [
    { "name": "<chart>", "version": "<version>", "digest": "<sha256>" }
  ],
  "pr": <pr-number>,
  "attestations": {
    "tag-verification": "<id>",
    "build-<chart>": "<id>"
  }
}
```

---

### Phase 7.8: Artifact Upload
**Effort**: Low
**Dependencies**: Phase 7.5

**Tasks**:
1. Upload chart packages as workflow artifacts
2. Enable download for manual inspection

**Code**:
```yaml
- uses: actions/upload-artifact@v4
  with:
    name: chart-packages
    path: .cr-release-packages/*.tgz
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

1. **Tag Availability**: What if PR is opened before tags are pushed?
2. **Attestation Subject**: For build attestation, use file path or digest?
3. **Multiple Charts**: Process in parallel or sequential?
4. **Failed Verification**: Block entire PR or just flag the chart?
5. **Artifact Retention**: How long to keep chart packages?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Tag not found | High | Wait for tag or fail with clear error |
| Attestation verification fails | High | Clear error, block merge |
| Helm package fails | High | Validate chart before building |
| Disk space for packages | Low | Clean up after upload |
| Multiple PRs for same release | Low | Idempotent operations |

---

## Success Criteria

- [ ] Workflow triggers on PR to release
- [ ] Validates source branch is main
- [ ] Finds and verifies tag attestations
- [ ] Builds chart packages successfully
- [ ] Generates build attestations for each package
- [ ] Generates overall attestation
- [ ] Updates PR description with attestation IDs
- [ ] Uploads artifacts for download
- [ ] Workflow completes in < 10 minutes
