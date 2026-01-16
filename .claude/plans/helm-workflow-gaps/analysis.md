# Helm Chart Workflow Gap Analysis

## Executive Summary

After analyzing the slash-command (`create-helm-chart.md`) and skill (`k8s-helm-charts-dev`), significant gaps exist in three areas:

1. **Progressive Disclosure Violation**: "Extend and Contribute Pattern" only in slash-command
2. **Missing Decision Framework**: Fork vs copy-local decision not addressed
3. **No Structured Workflow**: Research → Planning → Implementation phases not implemented

---

## 1. Extend and Contribute Pattern - Progressive Disclosure Analysis

### Current State

| Document | Location | Content |
|----------|----------|---------|
| **Slash-command** | Lines 95-110 | Full pattern with 5 steps + common improvements list |
| **Skill SKILL.md** | Lines 42-55 | Brief research strategy paragraph, no pattern |
| **Skill research-strategy.md** | Lines 60-70 | Basic decision table (4 scenarios) |

### Violation

The slash-command contains **more detail** than the skill, which inverts the progressive disclosure pattern:

- **Expected**: Slash-command triggers → Skill provides depth
- **Actual**: Slash-command has the details → Skill has less

### Gaps in Current "Extend and Contribute" Content

| Missing Element | Impact |
|-----------------|--------|
| When to extend vs create independent | No clear decision criteria |
| How to maintain compatibility | No concrete guidance |
| Contribution workflow steps | No PR process to upstream |
| Values schema compatibility checklist | Could break existing users |
| Communication with upstream maintainers | No collaboration guidance |

---

## 2. Fork vs Copy-Local Decision Framework

### Current State

**Not addressed in either document.**

The slash-command says "Create compatible chart with improvements to contribute back" but doesn't explain HOW.

### Decision Factors Not Documented

| Factor | Fork Upstream | Copy Locally |
|--------|---------------|--------------|
| **Intent** | Contribute back immediately | Diverge or learn |
| **Complexity** | Two repos, upstream tracking | Single repo, simpler |
| **History** | Preserved from upstream | Starts fresh |
| **Contribution** | Direct PRs | Manual diff/patch |
| **Maintenance** | Must track upstream changes | Independent |

### Recommended Decision Tree (Expanded)

```
Has official chart?
├─ No → Create from scratch locally
└─ Yes → Is the chart actively maintained?
    ├─ No (abandoned/stale) → Copy locally, become new maintainer
    └─ Yes → Do you want to contribute back?
        ├─ No → Copy locally, diverge freely
        └─ Yes → Is chart in its own repo?
            ├─ Yes → Fork the repo
            └─ No (monorepo) → Is monorepo small/focused?
                ├─ Yes → Fork monorepo, work in charts/ directory
                └─ No (large monorepo) → Copy locally, create PR later
```

**Additional Scenarios:**
- **Chart exists but is abandoned**: Copy locally, consider adopting/maintaining
- **Multiple community charts exist**: Compare quality, pick best to extend or create fresh
- **Official chart is behind a paywall/enterprise**: Create independent open-source alternative

### Pros/Cons Analysis

**Fork Upstream Repo:**
- Pro: Clear contribution path via PRs
- Pro: Git history preserved
- Pro: Easy to sync upstream changes
- Pro: CI/CD may already be configured
- Con: Two remotes to manage
- Con: May have CI/CD conflicts with your setup
- Con: Must follow upstream conventions

**Copy Chart Locally:**
- Pro: Simpler, contained workflow
- Pro: Can diverge without coordination
- Pro: Faster iteration, your conventions
- Pro: No upstream dependencies
- Con: Manual contribution process (diff + patch)
- Con: No git history from upstream
- Con: May drift significantly from upstream

**Hybrid Approach (Copy + Upstream PR):**
- Copy locally for development speed
- When stable, prepare upstream contribution via:
  1. Clone upstream temporarily
  2. Apply changes as commits
  3. Create PR
  4. Continue local development

---

## 3. Structured Workflow Analysis

### User's Expected Workflow

```
Research Phase:
  Initial Research → Create Plan → Review+Refine → Approve → Implement → Document

Planning Phase:
  Findings → High-Level Plan → Atomic Components → Phase Plans → Approvals → Issue Mapping

Implementation Phase:
  Start → Assign Issue + Draft PR → Sanity Checks → Submit PR
```

### Current Slash-Command Workflow

```
Phase 1: Gather Information (research, but no plan/approval)
Phase 1.5: Research Existing Solutions (partial)
Phase 2: Setup Git Worktree
Phase 2.5: Analyze Existing Patterns
Phase 3: MVP Chart Creation
Phase 3.5: Validate MVP
Phase 3.6: Commit and Create PR
Phase 4: Progressive Enhancement PRs
Phase 5: Cleanup Worktrees
```

### Gap Mapping

| Expected Element | Current State | Gap |
|------------------|---------------|-----|
| Create Robust Research Plan | Not implemented | Missing |
| Review + Refine Plan | Not implemented | Missing |
| Get Plan Approval | Not implemented | Missing |
| Document Findings | Implicit, not structured | Needs template |
| High-Level Plan | Not implemented | Missing |
| Identify Atomic Components | Implicit in Phase 4 table | Needs formalization |
| Phase Plans per Component | Not implemented | Missing |
| Sequential Approvals | Not implemented | Missing |
| Map Plans to Issues | Not implemented | Missing |
| Assign Issue + Draft PR | Partial (worktree, but no issue) | Needs issue workflow |
| Sanity Checks | Implicit (lint/template) | Needs formalization |
| External Review Stops | Not implemented | Missing |

### Skill Coverage

The skill (`SKILL.md` and references) is even more sparse - it provides:
- Generic Helm workflow (steps 1-10)
- Pattern templates
- Validation guidance

But does **not** provide:
- Research → Planning → Implementation structure
- Approval gates
- Issue tracking integration
- Contribution workflows

---

## 4. Workflow Selection Criteria (NEW)

The full structured workflow is **not always necessary**. Select based on chart complexity:

### When to Use Full Workflow (Research → Planning → Implementation)

| Criteria | Full Workflow | Fast Path |
|----------|---------------|-----------|
| Chart complexity | Complex/Operator | Simple/Standard |
| Official chart exists | Yes (extending) | No |
| External dependencies | Multiple required | None/Optional |
| User uncertainty | High (multiple approaches) | Low (clear path) |
| Contribution intent | Yes (upstream PR) | No |
| Multi-phase development | Yes (staged PRs) | Single PR |

### Fast Path (Simple Charts)

For Simple/Standard charts with clear requirements:
1. Quick research (5 min)
2. Create chart directly
3. Validate and PR

Skip: formal research plan, high-level plan, approval gates, issue mapping

### Full Workflow Triggers

Use full workflow when ANY of these apply:
- Extending an existing official chart
- Chart requires 3+ external services
- User explicitly requests planning
- Multiple valid architectural approaches
- Expected to be a multi-week effort

---

## 5. Recommended Implementation

### Phase A: Fix Progressive Disclosure (Skill Enhancement)

1. **Move detailed "Extend and Contribute Pattern" to skill**
   - Create `references/extend-contribute-strategy.md`
   - Include decision tree, compatibility checklist, contribution workflow

2. **Update slash-command to reference skill**
   - Brief mention with `> See skill's references/extend-contribute-strategy.md`

3. **Add fork vs copy-local decision framework**
   - Add to same reference file
   - Include pros/cons table and decision tree

### Phase B: Add Structured Workflow (Both Documents)

1. **Create Research Phase structure in skill**
   - Add `references/research-phase-workflow.md`
   - Include plan template, approval gates, documentation format

2. **Create Planning Phase structure in skill**
   - Add `references/planning-phase-workflow.md`
   - Include high-level plan template, atomic component breakdown
   - Include issue mapping guidance

3. **Update slash-command phases**
   - Add explicit approval gates
   - Add issue creation/assignment steps
   - Add "Draft PR at start" pattern

4. **Add Implementation Phase checkpoints**
   - Sanity check definitions
   - External review criteria
   - PR submission conditions

### Phase C: Issue Integration

1. **Define issue templates for Helm chart development**
   - Parent issue: Chart as a whole
   - Child issues: Per-phase (MVP, probes, security, etc.)

2. **Add issue mapping guidance**
   - How to structure parent-child relationships
   - SemVer bump correlation (Minor for features, Patch for fixes)

---

## 6. Files to Create/Modify

### New Files (in Skill)

| File | Purpose |
|------|---------|
| `references/extend-contribute-strategy.md` | Full extend/contribute workflow |
| `references/research-phase-workflow.md` | Research phase structure |
| `references/planning-phase-workflow.md` | Planning phase structure |
| `references/implementation-workflow.md` | Implementation phase with checkpoints |
| `assets/templates/research-summary.md` | Template for documenting findings |
| `assets/templates/high-level-plan.md` | Template for planning |
| `assets/templates/issue-structure.md` | Template for issue hierarchy |

### Modified Files

| File | Changes |
|------|---------|
| `SKILL.md` | Add workflow sections, reference new files |
| `references/research-strategy.md` | Expand decision table, add extend/contribute |
| Slash-command `create-helm-chart.md` | Add approval gates, issue workflow, reference skill |

---

## 7. Priority Order

1. **High**: Fix progressive disclosure (extend/contribute pattern)
2. **High**: Add fork vs copy-local decision framework
3. **Medium**: Add Research Phase workflow
4. **Medium**: Add Planning Phase workflow
5. **Medium**: Add Implementation Phase checkpoints
6. **Low**: Issue integration templates

---

## Next Steps

1. User approval of this analysis
2. Create detailed implementation plan per priority
3. Implement changes to skill files first
4. Update slash-command to reference skill
5. Validate with next chart creation
