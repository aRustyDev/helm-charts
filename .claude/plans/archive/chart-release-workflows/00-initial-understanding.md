# Initial Understanding - Chart Release Workflow Overhaul

## Branch Flow (as I understand it)

```
Feature Branch
     │
     ▼ PR (Workflow 1: Validate)
Integration Branch
     │
     ▼ Merge triggers (Workflow 2: Filter Charts)
Integration/<chart> Branch (per-chart)
     │
     ▼ Auto-PR (Workflow 3: Enforce Atomic)
Integration/<chart> Branch
     │
     ▼ Auto-merge (Workflow 4: Format)
     │
     ▼ Auto-PR opened
Main Branch
     │
     ▼ PR with checks (Workflow 5: Validate & SemVer)
Main Branch
     │
     ▼ Merge triggers (Workflow 6: Tagging)
     │   Creates immutable tag <chart>-vX.Y.Z
     │
     ▼ Auto-PR opened
Release Branch
     │
     ▼ PR with checks (Workflow 7: Atomic Releases)
Release Branch
     │
     ▼ Merge triggers (Workflow 8: Publishing)
GHCR + GH Release + Release Branch
```

## Key Concepts

### 1. Atomic Releases
- Each chart release is isolated and independent
- One chart per release PR/tag/publish cycle

### 2. Attestation Lineage
- Chain of attestations from initial contribution to final release
- Each step attests its own outputs
- "Overall Attestation" captures the entire chain

### 3. In-Toto Pattern
- SLSA build provenance format
- Subject (artifact) + Digest bound to provenance predicate
- Signed via Sigstore

### 4. Attestation ID Storage
- Stored in PR descriptions as "Markdown Code Comments"
- Each check gets a unique key
- Re-runs overwrite previous attestation ID for that key

## Technical Components

### GitHub Attestations
- Uses `actions/attest-build-provenance@v3`
- Returns `attestation-id` and `attestation-url`
- Requires permissions: `id-token: write`, `attestations: write`

### Branch Rulesets Required
| Branch/Tag | Protection |
|------------|------------|
| Integration | No deletion, no push (admin bypass) |
| Integration/<chart> | No push (no bypass), only Integration can merge |
| Main | No deletion (no bypass), no push (admin bypass) |
| Release | No deletion (no bypass), no push (no bypass) |
| <chart>-vX.Y.Z tags | Immutable, no deletion, only from Main |

---

## Open Questions (to clarify)

See `01-clarifying-questions.md`
