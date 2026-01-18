# Attestation and Provenance

This section documents how attestations provide cryptographic proof of provenance for Helm charts released from this repository.

## What Are Attestations?

Attestations are cryptographically signed statements that bind metadata about how an artifact was built to the artifact itself. They answer the question: **"How was this artifact created, and by whom?"**

In this repository, attestations serve three purposes:

1. **Build Provenance**: Prove that a chart package was built by our GitHub Actions workflows
2. **Verification Chain**: Link each release back through the validation pipeline
3. **Tamper Detection**: Detect if an artifact has been modified after signing

## Attestation Types Used

| Type | What It Proves | Where Generated |
|------|----------------|-----------------|
| **Build Provenance** | Package was built from this repo's workflows | Release workflow (W8) |
| **K8s Test Attestation** | Chart passed install tests on specific K8s versions | W5 validation |
| **Cosign Signature** | OCI image came from our workflow and hasn't changed | Release workflow |
| **Attestation Map** | Links PR to all upstream validation attestations | W5 → Release |

## How Attestations Flow Through the Pipeline

```
Developer PR → W1 (Validate) → integration merge
                                    ↓
                              W2 (Create atomic PR)
                                    ↓
                              W5 (Validate) ──────────────────┐
                              │ - lint tests                  │
                              │ - ArtifactHub lint            │
                              │ - K8s matrix tests ─────→ Test Attestations
                              │ - version bump               │
                              └────────────────────────────────┤
                                    ↓                         │
                              PR Description updated with     │
                              ATTESTATION_MAP (JSON)         │
                                    ↓                         │
                              Merge to main                   │
                                    ↓                         │
                              Release (W8) ←─────────────────┘
                              │ - Extract attestation map from source PR
                              │ - Create tag with lineage metadata
                              │ - Package chart
                              │ - Generate build attestation
                              │ - Sign with Cosign
                              │ - Create GitHub Release
                              └─→ Published artifact with full provenance
```

## Verification Capabilities

### Quick Verification (One Command)

For most users, a single command verifies the chart came from this repository:

```bash
# Verify GHCR chart
cosign verify ghcr.io/arustydev/helm-charts/cloudflared:1.0.0 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp "github.com/aRustyDev/helm-charts"

# Verify GitHub Release package
gh attestation verify cloudflared-1.0.0.tgz --repo aRustyDev/helm-charts
```

### Deep Verification (Full Lineage)

For security-critical deployments, trace the complete provenance chain:

1. **Verify the package attestation** - proves it was built by our workflow
2. **Extract source PR from release** - identifies which PR created the release
3. **Verify the attestation map** - confirms all tests passed
4. **Trace to integration merge** - links back to contributor PR

See [Lineage Tracing](./lineage.md) for detailed commands.

## Confidence Levels

| Verification Level | What You Know | Confidence |
|--------------------|---------------|------------|
| Cosign signature valid | Artifact came from our GitHub Actions | High |
| Build attestation valid | Package built from tagged commit in our repo | High |
| Attestation map present | Upstream tests passed (recorded in PR) | Medium |
| Full lineage trace | Complete chain from contributor to release | Very High |

## Documentation Structure

- **[Verification](./verification.md)**: Commands and methods for verifying charts
- **[Lineage Tracing](./lineage.md)**: How to trace provenance through the pipeline
- **[Limitations](./limitations.md)**: What attestations don't prove

## Quick Reference

### Distribution Channels

| Channel | Attestation Type | Verification Command |
|---------|------------------|---------------------|
| GHCR (OCI) | Cosign signature + Build attestation | `cosign verify` |
| GitHub Release | Build attestation + .sig file | `gh attestation verify` |
| charts.arusty.dev | None (index.yaml points to GH Release) | Download from Release, then verify |

### Key Files

| File | Purpose |
|------|---------|
| `.github/scripts/attestation-lib.sh` | Shared library for attestation operations |
| `.github/workflows/release-atomic-chart.yaml` | Generates build attestations and Cosign signatures |
| `.github/workflows/validate-atomic-chart-pr.yaml` | Generates test attestations and attestation map |

## Security Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    WHAT ATTESTATIONS PROVE                       │
├─────────────────────────────────────────────────────────────────┤
│ ✓ This artifact was built by GitHub Actions in this repo        │
│ ✓ The build used this specific commit SHA                       │
│ ✓ The workflow that built it was release-atomic-chart.yaml      │
│ ✓ The artifact has not been tampered with since signing         │
│ ✓ (With lineage) All upstream tests passed                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                 WHAT ATTESTATIONS DON'T PROVE                    │
├─────────────────────────────────────────────────────────────────┤
│ ✗ The source code is free of vulnerabilities                    │
│ ✗ The chart follows security best practices                     │
│ ✗ The upstream images referenced are safe                       │
│ ✗ The contributor's identity beyond their GitHub account        │
└─────────────────────────────────────────────────────────────────┘
```

See [Limitations](./limitations.md) for detailed discussion.
