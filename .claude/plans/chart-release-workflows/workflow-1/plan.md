# Workflow 1: Validate Initial Contribution - Phase Plan

## Overview
**Trigger**: `pull_request` → `integration` branch
**Purpose**: Validate contributions with comprehensive checks and generate attestations

### Related Documents
- **Workflow Spec**: [workflow-1-validate-initial-contribution.md](../workflows/workflow-1-validate-initial-contribution.md)
- **ADR-001**: [Attestation-Backed Release Pipeline](../adr/ADR-001-attestation-backed-release-pipeline.md)
- **ADR-003**: [Attestation Storage Format](../adr/ADR-003-attestation-storage-format.md)
- **Components**: [components-index.md](../components-index.md) - See `update_attestation_map`
- **Research**: [05-research-plan.md](../05-research-plan.md) - Changelog generation decision
- **Migration**: [migration-plan.md](../migration-plan.md) - Integration branch setup
- **Downstream**: After PR merges → triggers [Workflow 2](../workflow-2/plan.md)

---

## Prerequisites

### Shared Components Required (Build First)
- [ ] `update_attestation_map` shell function/action
- [ ] Attestation map format finalized

### Infrastructure Required
- [ ] `integration` branch created
- [ ] `integration-protection` ruleset configured
- [ ] `commitlint.config.js` created

### CLI Tools to Install
- [ ] `git-cliff` for changelog generation
- [ ] `ah` (ArtifactHub CLI) for metadata linting

---

## Implementation Phases

### Phase 1.1: Base Workflow Structure
**Effort**: Low
**Dependencies**: Integration branch exists

**Tasks**:
1. Create `.github/workflows/validate-contribution.yaml`
2. Configure trigger for `pull_request` → `integration`
3. Set up permissions block
4. Create job structure with matrix for K8s versions

**Deliverable**: Workflow file skeleton that triggers on correct events

---

### Phase 1.2: Lint-Test Matrix Job
**Effort**: Medium
**Dependencies**: Phase 1.1, existing ct.yaml config

**Tasks**:
1. Configure matrix strategy for K8s versions: `['v1.32.11', 'v1.33.7', 'v1.34.3']`
2. Set up `helm/chart-testing-action@v2`
3. Run `ct lint-and-install`
4. Capture test results as artifact

**Questions**:
- [ ] Do we need a KinD cluster for each K8s version?
- [ ] Should tests run in parallel or sequential?
- [ ] What's the timeout per K8s version test?

**Gaps**:
- Current `ct.yaml` may need updates for new branch structure
- Need to verify K8s version availability in KinD

---

### Phase 1.3: ArtifactHub Lint Job
**Effort**: Low
**Dependencies**: Phase 1.1

**Tasks**:
1. Install `ah` CLI in workflow
2. Run `ah lint` on changed charts
3. Capture lint results

**Questions**:
- [ ] Where to download `ah` binary? GitHub releases?
- [ ] Cache the binary between runs?

---

### Phase 1.4: Commit Message Validation Job
**Effort**: Low
**Dependencies**: Phase 1.1, commitlint config

**Tasks**:
1. Add `wagoid/commitlint-github-action@v5`
2. Create `commitlint.config.js` with project rules
3. Validate all commits in PR

**Questions**:
- [ ] What custom rules beyond conventional commits?
- [ ] Allow any scope or restrict to chart names?

**Gaps**:
- Need to define `commitlint.config.js` contents

---

### Phase 1.5: Changelog Generation Job
**Effort**: Medium
**Dependencies**: Phase 1.1, git-cliff config

**Decision**: Generate changelog **per-chart** using `git-cliff` with `--include-path`.
See [05-research-plan.md](../05-research-plan.md#31-changelog-generation-research) for details.

**Tasks**:
1. Install `git-cliff` in workflow using `orhun/git-cliff-action@v4`
2. Configure `cliff.toml` for Keep-a-Changelog format
3. For each changed chart, generate changelog:
   ```bash
   git cliff --include-path "charts/$CHART/**/*" --unreleased
   ```
4. Add generated changelog to PR comment

**Code**:
```yaml
- name: Generate changelog for changed charts
  id: changelog
  run: |
    CHARTS=$(git diff --name-only origin/integration...HEAD | grep '^charts/' | cut -d'/' -f2 | sort -u)
    for chart in $CHARTS; do
      echo "## Changelog for $chart" >> changelog.md
      git cliff --include-path "charts/$chart/**/*" --unreleased >> changelog.md
      echo "" >> changelog.md
    done

- name: Add changelog comment
  uses: peter-evans/create-or-update-comment@v4
  with:
    issue-number: ${{ github.event.pull_request.number }}
    body-file: changelog.md
```

**Resolved Questions**:
- [x] Generate changelog per-chart or combined? **Per-chart**
- [x] Where to store generated changelog? **PR comment**

**Gaps**:
- Need `cliff.toml` configuration file

---

### Phase 1.6: Security Scanning Job (OUT OF SCOPE)
**Status**: Deferred to future iteration
**Effort**: N/A for initial implementation

**Placeholder Tasks** (for future):
1. ~~Decide on security scanning tool(s)~~
2. ~~Implement scanning job~~
3. ~~Configure severity thresholds~~

**Notes**:
- Security scanning is explicitly out of scope for the initial workflow implementation
- The workflow structure will support adding security scanning as a future enhancement
- When implemented, should integrate with attestation pattern (generate attestation for scan results)

---

### Phase 1.7: Attestation Generation
**Effort**: High
**Dependencies**: Phase 1.2-1.5, `update_attestation_map` function

**Decision**: Attestation subject = **check/action name**. See [05-research-plan.md](../05-research-plan.md#4-attestation-subjects-decided).

**Tasks**:
1. Add `actions/attest-build-provenance@v3` to each job
2. Use check name as subject (e.g., `w1-lint-test-v1.32.11`)
3. Implement `update_attestation_map` to store IDs in PR description
4. Handle race conditions for parallel job updates

**Resolved: Attestation Subjects**
| Check | Subject Name |
|-------|--------------|
| Lint-test (K8s 1.32) | `w1-lint-test-v1.32.11` |
| Lint-test (K8s 1.33) | `w1-lint-test-v1.33.7` |
| Lint-test (K8s 1.34) | `w1-lint-test-v1.34.3` |
| ArtifactHub lint | `w1-artifacthub-lint` |
| Commit validation | `w1-commit-validation` |
| Changelog generation | `w1-changelog` |

**Code**:
```yaml
- name: Generate attestation
  uses: actions/attest-build-provenance@v3
  id: attestation
  with:
    subject-name: "w1-lint-test-${{ matrix.k8s_version }}"
    subject-digest: "sha256:${{ steps.test.outputs.digest }}"
    push-to-registry: false

- name: Update attestation map
  run: |
    source .github/scripts/attestation-lib.sh
    update_attestation_map \
      "lint-test-${{ matrix.k8s_version }}" \
      "${{ steps.attestation.outputs.attestation-id }}" \
      "${{ github.event.pull_request.number }}"
```

**Remaining Questions**:
- [ ] How to handle attestation for failed checks? (Likely: don't attest)
- [ ] Retry strategy for PR description updates?

**Gaps**:
- `update_attestation_map` not yet implemented - see [components-index.md](../components-index.md#update_attestation_map)
- Need mutex/retry for parallel attestation map updates

---

### Phase 1.8: Integration Testing
**Effort**: Medium
**Dependencies**: All previous phases

**Tasks**:
1. Test workflow with sample PR
2. Verify all checks run
3. Verify attestation map is populated
4. Test failure scenarios
5. Document any issues

---

## File Structure

```
.github/
├── workflows/
│   └── validate-contribution.yaml    # Main workflow
├── scripts/
│   └── attestation-lib.sh            # Shared functions
├── cliff.toml                         # git-cliff config
└── commitlint.config.js              # commitlint config
```

---

## Dependencies Graph

```
                    ┌──────────────────┐
                    │ integration      │
                    │ branch created   │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
        ┌──────────┐  ┌───────────┐  ┌────────────┐
        │commitlint│  │ cliff.toml│  │ ct.yaml    │
        │.config.js│  │ config    │  │ update     │
        └────┬─────┘  └─────┬─────┘  └──────┬─────┘
             │              │               │
             └──────────────┼───────────────┘
                            ▼
                    ┌──────────────────┐
                    │ Phase 1.1: Base  │
                    │ Workflow         │
                    └────────┬─────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
  ┌───────────┐       ┌───────────┐       ┌───────────┐
  │Phase 1.2  │       │Phase 1.3  │       │Phase 1.4  │
  │Lint-Test  │       │AH Lint    │       │Commit Val │
  └─────┬─────┘       └─────┬─────┘       └─────┬─────┘
        │                   │                   │
        └───────────────────┼───────────────────┘
                            ▼
                    ┌──────────────────┐
                    │ update_          │
                    │ attestation_map  │
                    └────────┬─────────┘
                             ▼
                    ┌──────────────────┐
                    │ Phase 1.7:       │
                    │ Attestation      │
                    └────────┬─────────┘
                             ▼
                    ┌──────────────────┐
                    │ Phase 1.8:       │
                    │ Testing          │
                    └──────────────────┘
```

---

## Open Questions

### Resolved
- [x] **Attestation Subject**: Use check/action name (e.g., `w1-lint-test-v1.32.11`) - See Phase 1.7
- [x] **Security Tool**: OUT OF SCOPE for initial implementation - See Phase 1.6
- [x] **Changelog Scope**: Per-chart using git-cliff `--include-path` - See Phase 1.5

### Remaining
1. **K8s Version Testing**: How long does each K8s version test take? Should we parallelize?
2. **Race Conditions**: How to safely update PR description from parallel jobs?
3. **ArtifactHub CLI**: Best method to install `ah` CLI in workflow?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Parallel attestation map updates cause conflicts | High | Implement mutex/retry logic |
| K8s version tests are slow | Medium | Consider running only latest by default |
| ArtifactHub CLI download fails | Low | Cache binary, fallback URL |
| git-cliff config complexity | Low | Start with default, iterate |

---

## Success Criteria

- [ ] All checks run on PR to `integration`
- [ ] Each check produces valid GitHub Attestation
- [ ] Attestation IDs stored in PR description in correct format
- [ ] Failed checks block PR merge
- [ ] Workflow completes in < 15 minutes
