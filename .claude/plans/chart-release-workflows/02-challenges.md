# Challenges - Chart Release Workflow Overhaul

## Critical Challenges (Potentially Infeasible)

### C1: Merge Source Restriction - NOT SUPPORTED BY GITHUB RULESETS

**Proposed Requirement**:
> "Only `Integration` may merge to `Integration/<chart>`; No admin bypass"

**Reality**: GitHub rulesets do NOT have a rule to restrict which branch can be merged INTO a target branch.

Available ruleset rules:
- Restrict creations (who can create branches)
- Restrict updates (who can push)
- Restrict deletions
- Require pull requests before merging
- Require status checks
- Block force pushes

**None of these can enforce "only branch X can merge to branch Y".**

**Workaround Options**:
1. **Workflow-based enforcement**: A workflow runs on PR open, checks the base branch, and fails if the source isn't allowed
2. **CODEOWNERS**: Require review from a team, but doesn't restrict source branch
3. **Auto-close bot**: A bot that auto-closes PRs from wrong source branches

**Recommendation**: Use workflow-based enforcement with a clear error message.

---

### C2: Tag Creation Branch Restriction - NOT DIRECTLY SUPPORTED

**Proposed Requirement**:
> "`<chart>-vX.Y.Z` tags may only be created against `Main`; No admin bypass"

**Reality**: Tag rulesets can restrict WHO creates tags (via bypass), but not WHICH commit/branch the tag points to.

**Workaround Options**:
1. **Workflow-only tagging**: Only create tags via GitHub Actions (not manual), workflow validates it's on Main
2. **Post-creation validation**: A workflow triggers on tag creation, deletes invalid tags
3. **Pre-receive hook**: Requires GitHub Enterprise Server (not available on github.com)

**Recommendation**: Only create tags via workflows; block manual tag creation entirely via rulesets (restrict creations, no bypass).

---

### C3: Auto-Merge Without Review - Security Risk

**Proposed Requirement** (Workflow 3):
> "Automatically Merge the PR" for `Integration -> Integration/<chart>`

**Concern**: Auto-merging without human review creates a security risk. A compromised Integration branch could auto-propagate malicious changes.

**Challenge**: GitHub's auto-merge feature still requires:
- Status checks to pass (if configured)
- OR no required checks

**Questions**:
- Is there ANY human review in this flow before Main?
- If not, what prevents a malicious commit from reaching Main automatically?

**Recommendation**: At minimum, require attestation verification checks before auto-merge.

---

## Significant Challenges (Require Design Decisions)

### C4: Cherry-Pick Isolation for Multi-Chart Commits

**Proposed Requirement** (Workflow 2):
> "Detect all individual `<chart>` in the last Merge... Open Cherry Picked PR for each"

**Challenge**: If a single commit touches multiple charts, how do you cherry-pick ONLY the changes for one chart?

**Scenarios**:
1. **Clean separation**: Commit A touches `charts/cloudflared/`, Commit B touches `charts/olm/` → Easy
2. **Single commit, multiple charts**: Commit A touches both `charts/cloudflared/` and `charts/olm/` → Can't cherry-pick part of a commit
3. **Shared template change**: A change to a shared helper affects all charts → Which chart gets it?

**Workaround Options**:
1. **File-based checkout**: Use `git checkout <sha> -- charts/<chart>/` instead of cherry-pick
2. **Enforce single-chart commits**: Reject PRs that touch multiple charts in a single commit
3. **Split detection**: If multi-chart commit detected, require manual intervention

**Recommendation**: Enforce atomic chart commits in Workflow 1 (fail if a single commit touches multiple charts).

---

### C5: Attestation ID Storage in PR Description

**Proposed Requirement**:
> "Store Attestation ID in PR Description as Markdown Code Comment"

**Challenges**:
1. **Race conditions**: Multiple checks running in parallel could overwrite each other's updates
2. **PR description size limits**: GitHub has limits on description size (~65,536 chars)
3. **Parsing reliability**: Extracting IDs requires consistent format

**Format Clarification Needed**: Is this HTML comments?
```markdown
<!-- ATTESTATION_MAP
lint-test-v1.32.11: 123456
lint-test-v1.33.7: 234567
-->
```

**Workaround Options**:
1. **Use PR comments instead**: Each check adds a comment with its attestation ID
2. **Use workflow artifacts**: Store attestation map as a JSON artifact
3. **Use GitHub API labels**: Store attestation IDs as label metadata (limited)

**Recommendation**: Use a structured comment block with mutex/retry logic for updates.

---

### C6: "Overall Attestation" Semantics

**Proposed Requirement**:
> "Overall Attestation is to capture a Snapshot of a PR Description (which holds the Attestation ID Map)"

**Challenges**:
1. **What is the subject?**: Attestations require a subject (artifact + digest). What artifact represents "the PR"?
2. **Timing**: When is the snapshot taken? After all checks pass? Before merge?
3. **Verification**: How does someone verify the overall attestation?

**Options for Subject**:
1. **Commit SHA**: Attest the commit that the PR represents
2. **PR metadata file**: Generate a JSON file with all attestation IDs, attest that file
3. **Tag annotation**: For Workflow 6, attest the tag annotation content

**Recommendation**: Generate a `attestation-manifest.json` file containing all attestation IDs, attest that file, include it in the release.

---

### C7: Attestation Lineage Verification

**Proposed Requirement**:
> "Attestation Lineage is the ability to follow one attestation back to its roots"

**Challenge**: GitHub Attestations don't have built-in lineage tracking. Each attestation is independent.

**Implementation Options**:
1. **Chain in predicate**: Include parent attestation IDs in the predicate of child attestations
2. **Manifest approach**: Each stage produces a manifest referencing previous stages
3. **Custom predicate type**: Define a custom In-Toto predicate type for lineage

**Recommendation**: Use the manifest approach - each workflow stage reads the previous manifest and extends it.

---

## Minor Challenges (Implementation Details)

### C8: Branch Proliferation

Creating `integration/<chart>` branches for each chart release could lead to many branches.

**Questions**:
- Are these deleted after merge to Main?
- Is there a cleanup workflow?
- Naming collision if same chart has concurrent releases?

### C9: Cloudflare Pages Migration

Renaming `charts` → `release` requires:
1. Create `release` branch from current `charts`
2. Update Cloudflare Pages configuration
3. Update any documentation referencing the old branch
4. Consider redirects for existing URLs

### C10: Release-Please Deprecation

If this new workflow handles SemVer bumping, what happens to release-please?
- Remove it entirely?
- Keep for changelog generation only?
- Transition period?

---

## Summary

| ID | Challenge | Severity | Resolution |
|----|-----------|----------|------------|
| C1 | Merge source restriction | Critical | Workflow enforcement |
| C2 | Tag branch restriction | Critical | Workflow-only tagging |
| C3 | Auto-merge security | Critical | Needs design decision |
| C4 | Multi-chart cherry-pick | Significant | Enforce atomic commits |
| C5 | Attestation ID storage | Significant | Structured comment block |
| C6 | Overall attestation subject | Significant | attestation-manifest.json |
| C7 | Attestation lineage | Significant | Manifest chaining |
| C8 | Branch cleanup | Minor | Cleanup workflow |
| C9 | CF Pages migration | Minor | Migration plan |
| C10 | Release-please transition | Minor | Deprecation plan |
