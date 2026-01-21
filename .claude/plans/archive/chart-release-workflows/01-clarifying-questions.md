# Clarifying Questions - Chart Release Workflow Overhaul

## Round 1: Branch Structure & Flow

### Q1.1: Integration Branch - Does it exist today?
The current repo has `main` and `charts` branches. The proposal introduces:
- `integration` branch
- `integration/<chart>` branches (dynamic)
- Rename `charts` → `release`

**Question**: Is `integration` a new long-lived branch that sits between feature branches and main?

### Q1.2: Feature Branch Naming
The proposal says `PR: Feature -> Integration`.

**Question**: Are "Feature" branches developer-created branches (e.g., `feat/add-cloudflared-metrics`)? Or is there a specific naming convention required?

### Q1.3: Integration/<chart> Branch Lifecycle
Workflow 2 creates `Integration/<chart>` branches via cherry-pick.

**Questions**:
- Are these ephemeral branches that get deleted after merge to Main?
- Or do they persist as long-lived per-chart integration branches?
- If multiple charts change in one PR, do we get multiple `Integration/<chart>` branches?

### Q1.4: Workflow 3 - "Automatically Merge the PR"
The workflow says it auto-merges `Integration -> Integration/<chart>` PRs.

**Question**: What triggers this auto-merge? Is it:
- Immediate upon PR creation (no human review)?
- After certain checks pass?
- Using GitHub's auto-merge feature?

---

## Round 2: Attestation Mechanics

### Q2.1: "Markdown Code Comment" Format
You mention storing Attestation IDs in PR descriptions as "Markdown Code Comments".

**Question**: Is this HTML-style comments in markdown? Example:
```markdown
<!-- ATTESTATION:lint-test-v1.32.11:123456 -->
```
Or a different format?

### Q2.2: Attestation ID Extraction
Each check stores its attestation ID in the PR description.

**Questions**:
- How do subsequent workflows read these IDs? Parse the PR body?
- What happens if a workflow re-runs and needs to update the ID?
- Is there a schema for the attestation map?

### Q2.3: "Overall Attestation" Definition
You describe "Overall Attestation" as capturing a snapshot of the PR description attestation map.

**Questions**:
- Is this a meta-attestation that attests to the collection of other attestation IDs?
- What is the "subject" of this overall attestation? The PR itself? A commit SHA?
- How does this enable "Attestation Lineage" programmatically?

### Q2.4: Attestation Lineage Verification
You want "the ability to follow one attestation back to its roots in a programmatic/algorithmic manner."

**Questions**:
- Is this for human audit or automated verification gates?
- What tool/process follows the lineage? `gh attestation verify`?
- Should the final release attestation include the entire chain?

---

## Round 3: Technical Implementation

### Q3.1: Security Check Placeholder
Workflow 1 lists `<security>` as a check.

**Question**: What security scanning do you envision?
- Trivy for container/config scanning?
- Kubesec for Kubernetes manifests?
- SAST for template logic?
- Dependency scanning?

### Q3.2: Cherry-Pick Mechanics (Workflow 2)
When multiple charts change in one merge to Integration:
- "Open Cherry Picked PR `Integration -> Integration/<chart>` for each `<chart>`"

**Questions**:
- How do you cherry-pick only the changes for one chart from a multi-chart commit?
- What if chart A depends on a shared template change that also affects chart B?
- Is this `git cherry-pick` or `git checkout -- charts/<chart>`?

### Q3.3: Commit Message Validation
Workflow 1 validates "Conventional-Commit (+ local overrides)".

**Question**: What are the local overrides? Is there a `commitlint.config.js` or similar to reference?

### Q3.4: SemVer Bumping Automation
Workflow 5 performs "SemVer Bumping + Attestation@SHA".

**Questions**:
- Is this replacing release-please entirely?
- Who determines major/minor/patch? Parsed from commit messages?
- Does this auto-commit the version bump to the PR?

---

## Round 4: Publishing & Assets

### Q4.1: Release Branch Content
The `Release` branch receives content from Main.

**Question**: Does the Release branch contain:
- Just packaged chart tarballs?
- The full chart source?
- An index.yaml for Helm repo hosting?

### Q4.2: Cloudflare Pages Update
You mention updating Cloudflare Pages for the `charts` → `release` rename.

**Question**: Is Cloudflare Pages serving:
- The Helm chart index (like GitHub Pages)?
- Documentation?
- Both?

### Q4.3: GH Release Assets - "Development Diff Lineage"
Workflow 8 includes "Development Diff Lineage (in tree; not squashed)" as a release asset.

**Question**: What format is this? A git bundle? A diff file? JSON with commit history?

---

## Round 5: Ruleset Feasibility

### Q5.1: "Only Integration may merge to Integration/<chart>"
This ruleset requires branch-specific merge restrictions.

**Question**: Can GitHub rulesets express "only branch X can be the base for merging to branch Y"? I believe this requires:
- Branch protection with "Require pull request reviews"
- But there's no "restrict merge source" rule natively

**Challenge**: This may require workflow-based enforcement rather than rulesets.

### Q5.2: Tag Creation Restriction
"<chart>-vX.Y.Z tags may only be created against Main"

**Question**: GitHub tag protection rules can prevent deletion but can they restrict which branch a tag points to? This might need workflow enforcement.

---

## Summary: Key Unknowns

| # | Topic | Status |
|---|-------|--------|
| 1 | Integration branch lifecycle | Need clarification |
| 2 | Attestation ID storage format | Need clarification |
| 3 | Overall Attestation mechanics | Need clarification |
| 4 | Cherry-pick isolation for multi-chart PRs | Need clarification |
| 5 | Security scanning tooling | Need clarification |
| 6 | SemVer automation source | Need clarification |
| 7 | Ruleset feasibility for merge restrictions | Potentially infeasible via rulesets |
| 8 | Tag branch restriction | Potentially infeasible via rulesets |
