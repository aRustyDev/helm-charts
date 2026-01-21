# Answers and Decisions - Chart Release Workflow Overhaul

## Critical Challenges - Resolutions

### C1: Merge Source Restriction
**Decision**: Workflow-based enforcement accepted
- Workflow validates source branch on PR open
- Auto-closes or fails if source branch is not allowed

### C2: Tag Branch Restriction
**Decision**: Workflow-only tagging accepted
- Block ALL manual tag creation via rulesets (no bypass)
- Only workflows create tags
- Workflow validates commit is on Main before tagging

### C3: Auto-Merge Security
**Decision**: Acceptable with layered controls
- Primary human review: Workflow 1 (`Feature -> Integration`)
- Secondary human review: Workflow 5 (`Integration/<chart> -> Main`)
- Counter-workflow: Auto-close PRs with invalid source branches
- Attestation lineage verification: Detect missing required checks automatically
- Defense-in-depth: Admins who could bypass controls could also modify them anyway

---

## Design Decisions

### Q1: Attestation ID Storage Format
**Decision**: JSON Map inside HTML comment block

```markdown
<!-- ATTESTATION_MAP
{
  "lint-test-v1.32.11": "123456",
  "lint-test-v1.33.7": "234567",
  "lint-test-v1.34.3": "345678",
  "artifacthub-lint": "456789",
  "commit-validation": "567890",
  "changelog-generation": "678901"
}
-->
```

**Rationale**: Easy to parse with regex + JSON.parse()

---

### Q2: Cherry-Pick for Multi-Chart Commits
**Decision**: Use file-based checkout instead of cherry-pick

```bash
git checkout <sha> -- charts/<chart>/
```

**Rationale**: Works even when a single commit touches multiple charts

---

### Q3: Overall Attestation Subject
**Decision**: Dual-subject approach

| Context | Subject(s) |
|---------|------------|
| PRs | Commit SHA + PR Description SHA (hash of description content) |
| Tags/Releases | Tag annotation (includes attestation IDs) |

**Follow-up Answer**: Yes, tag annotations are immutable when:
1. Tag is protected from deletion via rulesets (no bypass)
2. Tag is protected from updates via rulesets (no bypass)
3. Workflow-only creation ensures consistent format

Git tag annotations are stored as part of the tag object. If the tag cannot be deleted or recreated, the annotation is effectively immutable.

---

### Q4: Integration Branch
**Decision**: New long-lived branch

- Name: `integration`
- Initial content: Copy of `main`
- Sits between feature branches and main
- Protected from deletion and direct push

---

### Q5: Security Scanning
**Decision**: Placeholder for now

**Key insight**: Focus on the PATTERN, not specific tools
- Workflow 5 should verify attestation lineage generically
- Required checks are controlled via rulesets
- Workflow doesn't need to know WHAT checks, just that they passed
- This allows adding/removing security checks without modifying workflows

---

### Q6: SemVer Bumping
**Decision**: Use release-please with workflow integration

1. **Tool**: release-please (research alternatives below)
2. **Trigger**: Workflow 5 invokes release-please
3. **Action**: Commits version bump directly to PR
4. **Merge**: Auto-merge if checks pass, or wait for human

---

## SemVer Tool Research

### Tool Comparison for Helm Charts

| Tool | Helm Support | Approach | Pros | Cons |
|------|--------------|----------|------|------|
| **release-please** | Native (`release-type: helm`) | PR-based | Google-backed, mature, monorepo support | Complex config, "Resource not accessible" issues |
| **semantic-release** | Via plugins | Direct to main | Very popular, plugin ecosystem | Commits directly (no PR review), Node.js required |
| **chart-releaser** | Native | GitHub Pages focused | Official Helm project, simple | No version bumping - only packaging/publishing |
| **vnext** | Generic | CLI tool | Fast (Rust), simple | New project, less adoption |
| **standard-version** | Generic | CLI tool | Customizable | Deprecated in favor of release-please |

### Recommendation: release-please

**Reasons**:
1. **Native Helm support**: `release-type: helm` understands Chart.yaml
2. **PR-based workflow**: Aligns with your requirement for review before merge
3. **Monorepo support**: Handles multiple charts in `charts/*`
4. **Conventional commits**: Already using this pattern
5. **Changelog generation**: Automatic based on commits

**Caveat**: We've encountered "Resource not accessible by integration" issues. The workaround (skip-github-release + gh CLI) is already implemented.

### Alternative Consideration: semantic-release with @semantic-release/helm

If release-please continues to have issues, semantic-release could work with:
- `@semantic-release/commit-analyzer` - parse conventional commits
- `@semantic-release/release-notes-generator` - changelog
- Custom plugin or script to update Chart.yaml

However, semantic-release commits directly to branches without PRs, which conflicts with your review-based workflow.

---

## Updated Branch Flow

```
Feature Branch (developer creates)
     │
     ▼ PR opened (Workflow 1: Validate)
     │  - lint-test (v1.32, v1.33, v1.34)
     │  - artifacthub-lint
     │  - security checks (TBD)
     │  - commit message validation
     │  - changelog generation
     │  - Store attestation IDs in PR description
     │
     ▼ Human reviews and merges
Integration Branch (protected)
     │
     ▼ Merge triggers (Workflow 2: Filter Charts)
     │  - Detect charts changed
     │  - git checkout <sha> -- charts/<chart>/ for each
     │  - Open PR: Integration -> Integration/<chart>
     │
Integration/<chart> Branch (per-chart, protected)
     │
     ▼ PR opened (Workflow 3: Enforce Atomic)
     │  - Validate source is Integration
     │  - Auto-merge (no human review here)
     │
     ▼ Merge triggers (Workflow 4: Format)
     │  - Open PR: Integration/<chart> -> Main
     │  - Include source PR reference
     │
     ▼ PR opened (Workflow 5: Validate & SemVer)
     │  - Verify attestation lineage
     │  - release-please bumps version
     │  - Commit version change to PR
     │  - Overall Attestation
     │  - Human reviews and merges (secondary review)
     │
Main Branch (protected)
     │
     ▼ Merge triggers (Workflow 6: Tagging)
     │  - Create immutable tag <chart>-vX.Y.Z
     │  - Tag annotation includes attestation lineage
     │  - Open PR: Main -> Release
     │
     ▼ PR opened (Workflow 7: Atomic Releases)
     │  - Verify attestations at TAG
     │  - Build chart package
     │  - Overall Attestation
     │  - Auto-merge or wait
     │
Release Branch (protected)
     │
     ▼ Merge triggers (Workflow 8: Publishing)
     │  - Publish to GHCR
     │  - Publish to GH Releases
     │  - Assets: attestation lineage, changelog, README, LICENSE
```
