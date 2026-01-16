# Workflow 1: Validate Initial Contribution - Phase Plan

## Overview
**Trigger**: `pull_request` → `integration` branch
**Purpose**: Validate contributions with **broad, fast checks** and generate attestations

---

## Relevant Skills

Load these skills before planning, research, or implementation:

| Skill | Path | Relevance |
|-------|------|-----------|
| **CI/CD GitHub Actions** | `~/.claude/skills/cicd-github-actions-dev/SKILL.md` | Matrix builds, caching, concurrency control, pre-commit validation |
| **Helm Chart Development** | `~/.claude/skills/k8s-helm-charts-dev/SKILL.md` | Chart structure, ct lint configuration, values patterns |

**How to load**: Read the SKILL.md files at the start of implementation to access patterns and best practices.

### Check Distribution Philosophy

W1 performs **broadly applicable validation** that:
- Applies uniformly to all charts in a PR
- Catches issues early (before per-chart branching)
- Runs quickly to provide fast developer feedback

**Per-chart specific checks** (security scanning, SBOM generation, integration tests) belong in **W5** where:
- Changes are isolated to a single chart
- Expensive scans are more targeted
- Security findings are actionable per-release

See [W2 Plan: Check Distribution Strategy](../workflow-2/plan.md#architectural-note-check-distribution-strategy) for the full breakdown.

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

### Phase 1.2: Lint Job (Static Analysis Only)
**Effort**: Low
**Dependencies**: Phase 1.1, existing ct.yaml config
**Status**: ✅ Implemented

**Architecture Decision**: W1 runs `ct lint` only. `ct install` (K8s deployment tests) moved to W5.

**Rationale for Split**:
- `ct lint` is **fast** (seconds) and catches syntax/schema errors early
- `ct install` is **slow** (minutes per K8s version) and belongs in W5 where:
  - Single chart is being validated (more targeted)
  - Results are tied to the specific release candidate
  - Resource cost is justified by release context

**Tasks**:
1. Set up `helm/chart-testing-action@v2`
2. Run `ct lint` (static analysis only)
3. Generate attestation for lint results

**Resolved Questions**:
- [x] Do we need a KinD cluster? **No** - lint is static analysis, no cluster needed
- [x] Should tests run in parallel? **N/A** - lint is a single job now
- [x] Where does K8s compat testing go? **W5** - see Phase 5.3a in W5 plan

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

### Phase 1.6: Security Scanning Job (MOVED TO W5)
**Status**: Intentionally placed in W5, not W1
**Effort**: N/A for W1

**Architectural Decision**: Security scanning belongs in **W5 (PR → Main)**, not W1, because:

1. **Isolated context**: W5 validates a single chart, making security findings more actionable
2. **Expensive operations**: Security scans are slower; running per-chart avoids redundant work
3. **Release candidate focus**: Security attestations should be tied to the specific version being released
4. **SBOM accuracy**: Software Bill of Materials makes more sense for isolated chart content

**Future Implementation Location**: See [W2 Plan: Future Security Checks](../workflow-2/plan.md#future-security-checks-out-of-scope)

**Checks to add to W5** (when implementing):
- Trivy vulnerability scanning
- Kubesec security analysis
- SBOM generation (Syft/Anchore)
- License compliance checking
- Chart-specific integration tests

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
| Check | Subject Name | Notes |
|-------|--------------|-------|
| Chart lint | `w1-lint` | Static analysis via `ct lint` |
| ArtifactHub lint | `w1-artifacthub-lint` | Metadata validation |
| Commit validation | `w1-commit-validation` | Conventional commits |
| Changelog generation | `w1-changelog` | Per-chart changelog preview |

**Note**: K8s compat matrix testing (`w5-k8s-install-*`) attestations are generated in W5.

**Code**:
```yaml
- name: Generate attestation
  uses: actions/attest-build-provenance@v2
  id: attestation
  with:
    subject-name: "w1-lint"
    subject-digest: "sha256:${{ steps.digest.outputs.digest }}"
    push-to-registry: false

- name: Update attestation map
  run: |
    source .github/scripts/attestation-lib.sh
    update_attestation_map \
      "lint" \
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
- [x] **Attestation Subject**: Use check/action name (e.g., `w1-lint`) - See Phase 1.7
- [x] **Security Tool**: OUT OF SCOPE for initial implementation - See Phase 1.6
- [x] **Changelog Scope**: Per-chart using git-cliff `--include-path` - See Phase 1.5
- [x] **K8s Version Testing**: Moved to W5 (Phase 5.3a) for per-chart targeted testing
- [x] **ct lint vs ct install split**: W1 does `ct lint` (fast), W5 does `ct install` (slow, targeted)

### Remaining
1. **Race Conditions**: How to safely update PR description from parallel jobs?
2. **ArtifactHub CLI**: Best method to install `ah` CLI in workflow?

---

## Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| Parallel attestation map updates cause conflicts | High | Implement mutex/retry logic (done in attestation-lib.sh) |
| ArtifactHub CLI download fails | Low | Cache binary, fallback URL |
| git-cliff config complexity | Low | Start with default, iterate |

**Mitigated Risk**: K8s version tests being slow - moved to W5 where per-chart targeting makes the cost worthwhile.

---

## Success Criteria

- [x] All checks run on PR to `integration`
- [x] Each check produces valid GitHub Attestation
- [x] Attestation IDs stored in PR description in correct format
- [ ] Failed checks block PR merge (requires ruleset configuration)
- [x] Workflow completes quickly (< 5 minutes without K8s install tests)
