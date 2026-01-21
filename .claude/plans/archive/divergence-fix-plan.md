# Branch Divergence Fix Plan

## Current State Analysis (2026-01-18)

### Branch Relationship

```
Status: DIVERGED

Main SHA:        891552afb827060d488f56babc7514697f0a9055
Integration SHA: c0b1e5ae46d2f39014c829dd3c0b04ed64cda5ca
Merge Base:      c8e90ba30223d3576ec164a05d21f06c9f659807
```

### Commits in Main (Not in Integration)

| SHA | Message | Content |
|-----|---------|---------|
| 891552a | docs: add attestation documentation and E2E tests (#100) | Attestation docs |
| 5089041 | docs(tests): add comprehensive workflow test plan | Test plan |
| 4b70ec9 | refactor(ci): use GitHub variable for auto-merge | Workflow config |
| 7eb2927 | feat(ci): add configurable branch filtering | Workflow |
| f9a589b | fix(ci): remove branches filter from auto-merge | Workflow |
| 9e0ebc6 | feat(ci): implement auto-merge as separate workflow | Auto-merge workflow |
| 991d75a | fix(ci): relax commitlint rules for GitHub squash | Commitlint config |
| ad26225 | docs(adr): update ADRs to reflect actual impl | ADR updates |
| b535b09 | feat(ci): add trust-based auto-merge for integration | CODEOWNERS, workflows |

### Commits in Integration (Not in Main)

| SHA | Message | Unique Content? |
|-----|---------|-----------------|
| c0b1e5a | docs: add attestation documentation (#99) | No - same as main #100 |
| **15467cb** | feat(cloudflared): add priorityClassName support | **YES** |
| e627549 | fix(ci): sync critical workflow fixes | No - sync commit |
| **faafeee** | feat(cloudflared): add ingress/private-network keywords | **YES** |
| 8ef22b3 | chore: sync main to integration | No - sync commit |
| 08d3435 | feat(ci): consolidate release workflows | No - sync commit |
| 2ea2850 | chore: sync W2 branch base fix | No - sync commit |
| ... | (various sync commits) | No |

### Unreleased Features in Integration

These commits contain NEW features that must be preserved:

1. **15467cb** - `feat(cloudflared): add priorityClassName support`
   - Files: `deployment.yaml`, `values.yaml`, `values.schema.json`
   - Content: Adds priorityClassName option to pod spec

2. **faafeee** - `feat(cloudflared): add ingress and private-network keywords`
   - Files: `Chart.yaml`
   - Content: Adds `ingress`, `private-network` keywords (main has other keywords but not these)

### Version Differences

| Chart | Main | Integration | Notes |
|-------|------|-------------|-------|
| cloudflared | 0.4.2 | 0.4.1 | Main is released, integration is stale |

## Fix Strategy

### Recommended: Hard Reset + Cherry-Pick

Reset integration to match main, then cherry-pick the unreleased features.

```bash
# 1. Backup integration
git branch integration-backup-20260118 origin/integration
git push origin integration-backup-20260118

# 2. Reset integration to main
git checkout -B integration origin/main

# 3. Cherry-pick unreleased features (in chronological order)
git cherry-pick faafeee  # keywords first (older)
git cherry-pick 15467cb  # priorityClassName second (newer)

# 4. Resolve any conflicts (likely Chart.yaml version)
# The version should stay at 0.4.2 from main, features added on top

# 5. Force push integration (requires ruleset bypass or sync workflow)
git push origin integration --force-with-lease
```

### Conflict Resolution Notes

**Expected Conflict: `charts/cloudflared/Chart.yaml`**

When cherry-picking faafeee (keywords), Chart.yaml will conflict on:
- Version: Keep 0.4.2 from main
- Keywords: Accept both (main's ztna + ingress/private-network)
- Changelog: Keep main's changelog, add new entry for keywords

```yaml
# Resolved Chart.yaml should have:
version: 0.4.2  # Keep main's version
keywords:
  - cloudflared
  - cloudflare
  - cloudflare-tunnel
  - kubernetes
  - reverse-proxy
  - argo-tunnel
  - argo
  - tunnel
  - zero-trust-network-access
  - ztna
  - warp
  - connect-apps
  - access
  - network
  - connectivity
  - ingress          # From faafeee
  - private-network  # From faafeee
```

## Execution Plan

### Phase 1: Preparation

1. **Verify no open PRs to integration**
   ```bash
   gh pr list --base integration --state open
   # Close or merge any open PRs first
   ```

2. **Create backup branch**
   ```bash
   git fetch origin
   git branch integration-backup-$(date +%Y%m%d) origin/integration
   git push origin integration-backup-$(date +%Y%m%d)
   ```

3. **Temporarily disable rulesets** (if needed)
   - The sync workflow can bypass by using `--force-with-lease`
   - Or admin can use ruleset bypass

### Phase 2: Execute Sync

```bash
# Fetch latest
git fetch origin main integration

# Create new integration from main
git checkout -B integration origin/main

# Cherry-pick unreleased work
git cherry-pick --no-commit faafeee
# Resolve conflicts if any
git add .
git commit -m "feat(cloudflared): add ingress and private-network keywords

Cherry-picked from integration branch.
Original commit: faafeee

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

git cherry-pick --no-commit 15467cb
# Resolve conflicts if any
git add .
git commit -m "feat(cloudflared): add priorityClassName support

Cherry-picked from integration branch.
Original commit: 15467cb

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"

# Force push
git push origin integration --force-with-lease
```

### Phase 3: Verification

```bash
# 1. Verify main is ancestor of integration
git merge-base --is-ancestor origin/main origin/integration && \
  echo "SUCCESS: main is ancestor of integration" || \
  echo "FAILURE: main is NOT ancestor of integration"

# 2. Check commits in integration not in main
git log --oneline origin/main..origin/integration
# Should show only: keywords commit, priorityClassName commit

# 3. Check commits in main not in integration
git log --oneline origin/integration..origin/main
# Should show: nothing

# 4. Verify priorityClassName exists
git show origin/integration:charts/cloudflared/templates/deployment.yaml | grep priorityClassName

# 5. Verify keywords exist
git show origin/integration:charts/cloudflared/Chart.yaml | grep -E "ingress|private-network"

# 6. Verify version matches main
git show origin/integration:charts/cloudflared/Chart.yaml | grep "^version:"
# Should show: version: 0.4.2
```

### Phase 4: Post-Fix Validation

1. **Create test PR to integration**
   ```bash
   git checkout -b test/verify-sync origin/integration
   echo "# Test" >> README.md
   git commit -m "test: verify sync workflow"
   git push origin test/verify-sync
   gh pr create --base integration --title "test: verify sync"
   ```

2. **Verify W1 passes** - lint, artifacthub-lint, commit-validation

3. **Delete test branch/PR**
   ```bash
   gh pr close <number> --delete-branch
   ```

## Post-Fix: Sync Workflow

After the fix, the `sync-main-to-integration.yaml` workflow will keep integration in sync:

- **Trigger**: Every push to main
- **Fast-forward**: If integration is behind main
- **Rebase**: If integration has diverged (unreleased features)
- **Skip**: If integration is ahead or equal

This prevents future divergence by automatically rebasing integration onto main.

## Rollback Procedure

If the fix causes issues:

```bash
# Restore from backup
git checkout -B integration origin/integration-backup-20260118
git push origin integration --force-with-lease

# Delete backup (after rollback verification)
git push origin --delete integration-backup-20260118
```

## Checklist

- [ ] Verify no open PRs to integration
- [ ] Create backup branch
- [ ] Document unreleased commits to preserve
- [ ] Execute reset to main
- [ ] Cherry-pick faafeee (keywords)
- [ ] Cherry-pick 15467cb (priorityClassName)
- [ ] Resolve conflicts (keep main version, add features)
- [ ] Force push integration
- [ ] Verify main is ancestor of integration
- [ ] Verify unreleased features present
- [ ] Verify version matches main (0.4.2)
- [ ] Test PR to integration passes W1
- [ ] Delete backup branch (optional, keep for safety)
- [ ] Enable sync workflow to prevent future divergence
