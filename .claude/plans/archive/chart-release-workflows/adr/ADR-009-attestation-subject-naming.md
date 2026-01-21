# ADR-009: Attestation Subject Naming Convention

## Status
Accepted

## Context
GitHub Attestations (`actions/attest-build-provenance@v3`) require a `subject-name` parameter that identifies what is being attested. The attestation lineage system needs:
- Consistent naming across all workflows
- Unique identification per check type
- Traceable lineage from contribution to release
- Clear mapping between attestation IDs and their purposes

We need a naming convention that is:
- Human-readable for debugging
- Machine-parseable for automation
- Consistent across 8 workflows
- Supportive of matrix builds (e.g., multiple K8s versions)

## Decision
Use check/action name as the attestation subject, following this pattern:

```
<workflow>-<check-name>[-<variant>]
```

### Format Components
| Component | Description | Example |
|-----------|-------------|---------|
| `workflow` | Workflow identifier (w1-w8) | `w1` |
| `check-name` | The validation or action performed | `lint-test` |
| `variant` | Optional discriminator for matrix builds | `v1.32.11` |

### Complete Subject Catalog

#### Workflow 1: Validate Initial Contribution
| Check | Subject Name | Description |
|-------|--------------|-------------|
| Lint-test (K8s 1.32) | `w1-lint-test-v1.32.11` | Chart testing with K8s 1.32 |
| Lint-test (K8s 1.33) | `w1-lint-test-v1.33.7` | Chart testing with K8s 1.33 |
| Lint-test (K8s 1.34) | `w1-lint-test-v1.34.3` | Chart testing with K8s 1.34 |
| ArtifactHub lint | `w1-artifacthub-lint` | ArtifactHub metadata validation |
| Commit validation | `w1-commit-validation` | Conventional commit check |
| Changelog generation | `w1-changelog` | Per-chart changelog generation |

#### Workflow 5: Validate & SemVer Bump
| Check | Subject Name | Description |
|-------|--------------|-------------|
| Chain verification | `w5-attestation-verify` | Upstream attestation verification |
| SemVer bump | `w5-semver-bump` | Version increment attestation |
| Overall | `w5-overall` | Combined W5 attestation |

#### Workflow 7: Atomic Chart Releases
| Check | Subject Name | Description |
|-------|--------------|-------------|
| Tag verification | `w7-tag-verify` | Tag attestation verification |
| Build (per chart) | `w7-build-<chart>` | Chart package build attestation |
| Overall | `w7-overall` | Combined W7 attestation |

### Implementation Example
```yaml
# Matrix build attestation
- name: Generate attestation
  uses: actions/attest-build-provenance@v3
  id: attestation
  with:
    subject-name: "w1-lint-test-${{ matrix.k8s_version }}"
    subject-digest: "sha256:${{ steps.test.outputs.digest }}"
    push-to-registry: false

# Store in attestation map
- name: Update attestation map
  run: |
    source .github/scripts/attestation-lib.sh
    update_attestation_map \
      "lint-test-${{ matrix.k8s_version }}" \
      "${{ steps.attestation.outputs.attestation-id }}" \
      "${{ github.event.pull_request.number }}"
```

### Attestation Map Key vs Subject Name
| Purpose | Value | Example |
|---------|-------|---------|
| Attestation `subject-name` | Full identifier with workflow prefix | `w1-lint-test-v1.32.11` |
| Attestation map key | Short check name for readability | `lint-test-v1.32.11` |

The map key is derived from the subject name by removing the workflow prefix. This keeps the PR description concise while maintaining full traceability in the attestation itself.

## Consequences

### Positive
- Consistent naming enables automated verification
- Human-readable names aid debugging
- Workflow prefix prevents collisions across stages
- Variant support enables matrix build tracking
- Clear audit trail from check to attestation

### Negative
- Slightly verbose subject names
- Requires discipline to follow convention
- Breaking changes would invalidate existing attestations

### Mitigations
- Document convention in CONTRIBUTING.md
- Validate subject names in CI
- Version the naming scheme if changes needed

## Alternatives Considered

### 1. File-based subjects
Use the file or artifact being validated as the subject.
- **Example**: `charts/cloudflared/Chart.yaml`
- **Rejected**: Same file attested multiple times (different checks), ambiguous

### 2. UUID subjects
Generate random UUIDs for each attestation.
- **Rejected**: Not human-readable, harder to debug, no semantic meaning

### 3. Timestamp-based subjects
Include timestamp in subject name.
- **Example**: `lint-test-2025-01-15T12:00:00Z`
- **Rejected**: Doesn't uniquely identify the check type, verbose

### 4. Hash-based subjects
Use content hash as subject.
- **Example**: `sha256:abc123...`
- **Rejected**: Already captured in `subject-digest`, would be redundant

## References
- [GitHub Attestations Documentation](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds)
- [actions/attest-build-provenance](https://github.com/actions/attest-build-provenance)
- [ADR-003: Attestation Storage Format](./ADR-003-attestation-storage-format.md)
