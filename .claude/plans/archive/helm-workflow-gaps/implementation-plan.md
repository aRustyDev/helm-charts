# Helm Chart Workflow - Implementation Plan

Based on gap analysis, this plan implements the missing structured workflow.

---

## Workflow Selection (NEW)

Before implementing the structured workflow, add **workflow selection criteria** to both skill and slash-command:

| Chart Complexity | Official Chart Exists | Workflow |
|------------------|----------------------|----------|
| Simple/Standard | No | **Fast Path** - Quick research, create, validate |
| Simple/Standard | Yes (use as-is) | **Skip** - Use existing chart |
| Complex/Operator | No | **Full Workflow** - Research → Plan → Implement |
| Any | Yes (extend) | **Full Workflow** with Extend/Contribute strategy |

---

## Phase A: Fix Progressive Disclosure (Priority: High)

### A1: Create Extend/Contribute Strategy Reference

**File**: `k8s-helm-charts-dev/references/extend-contribute-strategy.md`

**Content Structure**:
```markdown
# Extend and Contribute Strategy

## When to Extend vs Create Independent

Decision matrix for choosing approach when official chart exists.

## Fork vs Copy-Local Decision

Decision tree with pros/cons for each approach.

## Compatibility Checklist

- [ ] Values schema compatibility
- [ ] Release naming conventions
- [ ] Dependency versions
- [ ] Breaking changes assessment

## Contribution Workflow

1. Review upstream chart structure
2. Identify improvement opportunities
3. Implement with compatibility
4. Document differences
5. Prepare contribution (PR or issue)
6. Communicate with maintainers

## Common Improvements to Contribute

- HPA/PDB support
- Startup probes
- kubeVersion constraints
- Enhanced security contexts
- Additional persistence options
```

### A2: Update Skill Research Strategy

**File**: `k8s-helm-charts-dev/references/research-strategy.md`

**Changes**:
- Expand "Decision: Existing Chart Found" section
- Add reference to new extend-contribute-strategy.md
- Add fork vs copy-local decision tree

### A3: Update Slash-Command

**File**: `helm-charts/.claude/commands/create-helm-chart.md`

**Changes**:
- Condense "Extend and Contribute Pattern" to brief summary
- Add: `> **Details**: See skill's references/extend-contribute-strategy.md`
- Keep the 3 user options (Skip, Extend, Create Independent)

---

## Phase B: Add Research Phase Workflow (Priority: Medium)

### B1: Create Research Phase Reference

**File**: `k8s-helm-charts-dev/references/research-phase-workflow.md`

**Content Structure**:
```markdown
# Research Phase Workflow

## Overview
Initial Research → Create Plan → Review+Refine → Approve → Implement → Document

## Step 1: Initial Research
Quick exploration to understand scope.

## Step 2: Create Research Plan
Structured plan for systematic investigation.

### Research Plan Template
- Objectives
- Information needed (checklist)
- Sources to investigate
- Fallback strategies
- Expected outputs

## Step 3: Review and Refine
Self-review checklist before seeking approval.

## Step 4: Get Approval (Optional Gate)
When to seek user approval:
- Complex applications
- Unclear requirements
- Multiple valid approaches

## Step 5: Implement Research Plan
Execute the plan systematically.

## Step 6: Document Findings
Use structured template (see assets/templates/research-summary.md)
```

### B2: Create Research Summary Template

**File**: `k8s-helm-charts-dev/assets/templates/research-summary.md`

**Content**: Formalized version of the template already in research-strategy.md, with added sections for approval tracking.

### B3: Update Slash-Command Phase 1/1.5

**File**: `helm-charts/.claude/commands/create-helm-chart.md`

**Changes**:
- Add research plan creation step
- Add approval gate (optional, based on complexity)
- Reference skill's research-phase-workflow.md

---

## Phase C: Add Planning Phase Workflow (Priority: Medium)

### C1: Create Planning Phase Reference

**File**: `k8s-helm-charts-dev/references/planning-phase-workflow.md`

**Content Structure**:
```markdown
# Planning Phase Workflow

## Overview
Findings → High-Level Plan → Atomic Components → Phase Plans → Approvals → Issue Mapping

## Step 1: Use Research Findings
How to translate research into planning inputs.

## Step 2: Create High-Level Plan
Overall chart structure and features.

### High-Level Plan Template
- Chart name and type
- Complexity classification
- Target features (MVP + enhancements)
- Dependencies
- CI handling

## Step 3: Identify Atomic Components
Break down into independently deployable features.

### Atomicity Criteria
- Single concern
- Independently testable
- Clear boundaries
- SemVer appropriate (Minor or Patch)

## Step 4: Draft Phase Plans
Per-component detailed plans.

### Phase Plan Template
- Component name
- Files to create/modify
- Values to add
- Templates to add
- Validation criteria
- Dependencies on other phases

## Step 5: Sequential Approvals
Review each phase plan before proceeding.

## Step 6: Map to Issues
Structure as GitHub issues.

### Issue Hierarchy
- Parent: Chart overall
- Children: Per-phase (MVP, probes, security, etc.)
- Grandchildren: Sub-tasks if needed

### SemVer Mapping
- New feature (HPA, PDB) → Minor bump
- Fix/improvement → Patch bump
```

### C2: Create Planning Templates

**Files**:
- `k8s-helm-charts-dev/assets/templates/high-level-plan.md`
- `k8s-helm-charts-dev/assets/templates/phase-plan.md`
- `k8s-helm-charts-dev/assets/templates/issue-structure.md`

### C3: Update Slash-Command

**File**: `helm-charts/.claude/commands/create-helm-chart.md`

**Changes**:
- Add "Phase 1.8: Create Implementation Plan" (between research and worktree)
- Add approval gate for high-level plan
- Reference skill's planning-phase-workflow.md

---

## Phase D: Add Implementation Phase Checkpoints (Priority: Medium)

### D1: Create Implementation Workflow Reference

**File**: `k8s-helm-charts-dev/references/implementation-workflow.md`

**Content Structure**:
```markdown
# Implementation Phase Workflow

## Overview
Start → Assign Issue + Draft PR → Sanity Checks → External Review → Submit PR

## Step 1: Begin Implementation
- Create worktree
- Create draft PR immediately
- Link to issue

## Step 2: Sanity Checks
Run before each commit:
- helm lint
- helm template
- Security check (runAsNonRoot, etc.)
- Dependency check

### Sanity Check Script
Reference to validate-chart.sh with additions.

## Step 3: External Review Stops
When to pause and request review:
- Architectural decisions
- Breaking changes
- Unclear requirements
- Complex logic

## Step 4: Submit PR
Conditions for marking PR ready:
- All sanity checks pass
- Documentation updated
- NOTES.txt accurate
- README current

## Step 5: Post-Merge
- Update issue status
- Clean up worktree
- Start next phase (if applicable)
```

### D2: Update Slash-Command Phases 3-4

**File**: `helm-charts/.claude/commands/create-helm-chart.md`

**Changes**:
- Add issue assignment step
- Add "create draft PR immediately" guidance
- Formalize sanity check requirements
- Add external review criteria
- Reference skill's implementation-workflow.md

---

## Phase E: Skill SKILL.md Updates (Priority: High)

### E1: Update Main Skill File

**File**: `k8s-helm-charts-dev/SKILL.md`

**Changes**:
- Add "Structured Workflow" section after current content
- Reference all new workflow files
- Add brief summaries with `> Details: See references/...`

**New Section Outline**:
```markdown
## Structured Development Workflow

For complex charts or when contributing to existing projects, follow this structured approach:

### Research Phase
Brief overview → See `references/research-phase-workflow.md`

### Planning Phase
Brief overview → See `references/planning-phase-workflow.md`

### Implementation Phase
Brief overview → See `references/implementation-workflow.md`

### Extending Existing Charts
Brief overview → See `references/extend-contribute-strategy.md`
```

---

## Implementation Order (Optimized)

**Strategy**: Create all skill files first, then update SKILL.md, then update slash-command once.

| Order | Phase | Files | Effort |
|-------|-------|-------|--------|
| 1 | A1 | `references/extend-contribute-strategy.md` | Medium |
| 2 | A2 | Update `references/research-strategy.md` | Low |
| 3 | B1 | `references/research-phase-workflow.md` | Medium |
| 4 | B2 | `assets/templates/research-summary.md` | Low |
| 5 | C1 | `references/planning-phase-workflow.md` | Medium |
| 6 | C2a | `assets/templates/high-level-plan.md` | Low |
| 7 | C2b | `assets/templates/phase-plan.md` | Low |
| 8 | C2c | `assets/templates/issue-structure.md` | Low |
| 9 | D1 | `references/implementation-workflow.md` | Medium |
| 10 | E1 | Update `SKILL.md` (add workflow section, references) | Medium |
| 11 | FINAL | Update `create-helm-chart.md` (all changes at once) | Medium |

**Rationale**:
- Avoids multiple slash-command edits
- Skill is complete before slash-command references it
- Easier to validate skill in isolation

---

## Validation

After implementation:
1. Dry-run `/create-helm-chart` for a new application
2. Verify progressive disclosure works (slash-command → skill)
3. Verify all approval gates are clear
4. Verify issue mapping guidance is actionable

---

## Issue Tracking (Optional)

If creating GitHub issues:

**Parent Issue**: `feat(skills): add structured workflow to k8s-helm-charts-dev`

**Child Issues**:
1. `feat(skills): add extend-contribute-strategy reference`
2. `feat(skills): add research-phase-workflow reference`
3. `feat(skills): add planning-phase-workflow reference`
4. `feat(skills): add implementation-workflow reference`
5. `feat(commands): update create-helm-chart for structured workflow`
