# ADR-001: Attestation-Backed Release Pipeline Architecture

## Status
Proposed

## Context
The current release workflow using release-please has several limitations:
1. No cryptographic proof of the release process
2. Manual intervention required for automation failures
3. No verifiable chain from contribution to release
4. Single-point-of-failure in workflow design

Supply chain security is increasingly important (SLSA, SBOM requirements). We need a release process that:
- Provides cryptographic attestation at every step
- Enables programmatic verification of the entire chain
- Supports atomic releases per chart
- Publishes to multiple destinations reliably

## Decision
Implement an 8-workflow pipeline with GitHub Attestations at every step:

1. **Workflow 1**: Validate Initial Contribution (Feature → Integration)
2. **Workflow 2**: Filter Charts (split multi-chart changes)
3. **Workflow 3**: Enforce Atomic Chart PRs (auto-merge)
4. **Workflow 4**: Format Atomic Chart PRs (create Main PR)
5. **Workflow 5**: Validate & SemVer Bump (version + attestation verify)
6. **Workflow 6**: Atomic Chart Tagging (immutable tags)
7. **Workflow 7**: Atomic Chart Releases (build + verify)
8. **Workflow 8**: Atomic Release Publishing (GHCR + GH Release)

Each workflow:
- Attests its outputs using `actions/attest-build-provenance`
- Stores attestation IDs in PR descriptions (JSON in HTML comments)
- Verifies upstream attestations before proceeding

## Consequences

### Positive
- Full cryptographic proof of release process (SLSA compliance path)
- Attestation lineage enables audit and verification
- Atomic releases reduce blast radius of issues
- Multiple publishing destinations increase availability
- Automated flow reduces human error

### Negative
- Increased complexity (8 workflows vs 1)
- More GitHub Actions minutes consumed
- Learning curve for contributors
- Attestation storage in PR descriptions is unconventional

### Risks
- GitHub Attestations API could change
- PR description size limits could be hit with many attestations
- Workflow failures require understanding the full chain

## Alternatives Considered

### 1. Enhanced release-please only
Keep release-please but add attestations to the existing workflow.
- **Rejected**: Doesn't solve atomic releases or multi-destination publishing

### 2. semantic-release
Use semantic-release with plugins.
- **Rejected**: Commits directly to branches without PR review, conflicts with our review-based workflow

### 3. Single workflow with stages
One large workflow with conditional stages.
- **Rejected**: Harder to maintain, debug, and doesn't support the branch-based isolation we need

## References
- [SLSA Provenance](https://slsa.dev/spec/v1.0/provenance)
- [In-Toto Attestation Format](https://github.com/in-toto/attestation)
- [GitHub Attestations](https://docs.github.com/en/actions/security-guides/using-artifact-attestations-to-establish-provenance-for-builds)
