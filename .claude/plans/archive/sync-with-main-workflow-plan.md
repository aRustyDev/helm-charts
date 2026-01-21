# Sync-With-Main Workflow Plan

> **Status**: ✅ COMPLETE - Superseded by Full Atomization Model
>
> This plan has been implemented and is now superseded by the Full Atomization Model (ADR-011).
> With full atomization, integration is always reset to main after extraction, eliminating divergence.
> The sync workflow now uses `ff-only` for all branches including integration.
>
> See: `.claude/plans/archive/full-atomization-model.md`

## Overview

Expand the existing `sync-main-to-integration.yaml` workflow to support syncing main to multiple branch patterns:

| Branch Pattern | Purpose | Sync Strategy |
|----------------|---------|---------------|
| `integration` | Staging branch for contributions | Fast-forward only (was Rebase, changed with atomization) |
| `hotfix/*` | Emergency fix branches | Fast-forward only |
| `charts/*` | Per-chart atomic branches (W2) | Fast-forward only |
| `docs/*` | Documentation branches | Fast-forward only |

## Current State

The existing workflow only syncs `integration`:

```yaml
# Current: sync-main-to-integration.yaml
on:
  push:
    branches: [main]
# Only handles integration branch
```

## Proposed Changes

### Option A: Single Workflow with Matrix

Use a matrix strategy to sync all configured branches in a single workflow.

```yaml
name: Sync Main to Branches

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      branch_pattern:
        description: 'Branch pattern to sync (e.g., "integration", "hotfix/*", "all")'
        required: false
        default: 'all'
        type: string

env:
  # Branches to sync with their strategies
  # NOTE: With full atomization, integration uses ff-only (reset after extraction)
  SYNC_BRANCHES: |
    integration:ff-only
    hotfix/*:ff-only
    charts/*:ff-only
    docs/*:ff-only

jobs:
  discover:
    runs-on: ubuntu-latest
    outputs:
      branches: ${{ steps.list.outputs.branches }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Discover matching branches
        id: list
        run: |
          BRANCHES=()

          # For each pattern in SYNC_BRANCHES
          while IFS=: read -r pattern strategy; do
            [[ -z "$pattern" ]] && continue

            # Find matching remote branches
            for branch in $(git branch -r | grep -E "origin/$pattern" | sed 's|origin/||'); do
              BRANCHES+=("{\"name\":\"$branch\",\"strategy\":\"$strategy\"}")
            done
          done <<< "$SYNC_BRANCHES"

          # Output as JSON array
          echo "branches=[$(IFS=,; echo "${BRANCHES[*]}")]" >> "$GITHUB_OUTPUT"

  sync:
    needs: discover
    if: needs.discover.outputs.branches != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        branch: ${{ fromJson(needs.discover.outputs.branches) }}
      fail-fast: false
      max-parallel: 5
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Sync branch
        env:
          BRANCH: ${{ matrix.branch.name }}
          STRATEGY: ${{ matrix.branch.strategy }}
        run: |
          git fetch origin main "$BRANCH"

          MAIN_SHA=$(git rev-parse origin/main)
          BRANCH_SHA=$(git rev-parse "origin/$BRANCH")
          MERGE_BASE=$(git merge-base origin/main "origin/$BRANCH")

          # Determine action
          if [[ "$MAIN_SHA" == "$BRANCH_SHA" ]]; then
            echo "::notice::$BRANCH is equal to main - no sync needed"
            exit 0
          elif [[ "$MERGE_BASE" == "$MAIN_SHA" ]]; then
            echo "::notice::$BRANCH is ahead of main - no sync needed"
            exit 0
          elif [[ "$MERGE_BASE" == "$BRANCH_SHA" ]]; then
            # Main is ahead - can fast-forward
            git checkout "$BRANCH"
            git merge --ff-only origin/main
            git push origin "$BRANCH"
            echo "::notice::Fast-forwarded $BRANCH to main"
          else
            # Diverged
            if [[ "$STRATEGY" == "rebase" ]]; then
              git checkout "$BRANCH"
              if git rebase origin/main; then
                git push origin "$BRANCH" --force-with-lease
                echo "::notice::Rebased $BRANCH onto main"
              else
                git rebase --abort
                echo "::error::Rebase failed for $BRANCH - conflicts detected"
                exit 1
              fi
            else
              echo "::warning::$BRANCH has diverged but strategy is ff-only, skipping"
              exit 0
            fi
          fi
```

### Option B: Separate Workflows per Branch Type

Keep dedicated workflows for different branch types:

| Workflow | Branches | Trigger |
|----------|----------|---------|
| `sync-main-to-integration.yaml` | `integration` | Push to main |
| `sync-main-to-hotfix.yaml` | `hotfix/*` | Push to main, manual |
| `sync-main-to-atomic.yaml` | `charts/*` | Push to main (if exists) |

**Pros**: Simpler logic per workflow, easier debugging
**Cons**: Code duplication, more files to maintain

## Recommended: Option A with Configuration

Use Option A with a repository variable for configuration:

### Implementation Steps

#### 1. Create Repository Variable

| Variable | Value |
|----------|-------|
| `SYNC_BRANCH_CONFIG` | `integration:rebase,hotfix/*:ff-only,charts/*:ff-only` |

#### 2. Update Workflow

Rename `sync-main-to-integration.yaml` to `sync-main-to-branches.yaml`:

```yaml
name: Sync Main to Branches

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      target_branch:
        description: 'Specific branch to sync (leave empty for all)'
        required: false
        type: string
      force:
        description: 'Force sync even if branch appears up to date'
        required: false
        default: false
        type: boolean

permissions:
  contents: write
  issues: write  # For creating issues on persistent failures

# Prevent concurrent syncs to the same branches
concurrency:
  group: sync-main-to-branches
  cancel-in-progress: false

env:
  # Default configuration if variable not set
  # Format: branch_pattern:strategy (ff-only for all with atomization)
  DEFAULT_CONFIG: 'integration:ff-only'
  # Maximum branches to process in one run (prevent runaway matrix)
  MAX_BRANCHES: 20

jobs:
  discover-branches:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.discover.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Discover branches to sync
        id: discover
        env:
          CONFIG: ${{ vars.SYNC_BRANCH_CONFIG || env.DEFAULT_CONFIG }}
          TARGET: ${{ github.event.inputs.target_branch }}
          FORCE: ${{ github.event.inputs.force }}
          MAX_BRANCHES: ${{ env.MAX_BRANCHES }}
        run: |
          ENTRIES=()
          COUNT=0

          # Parse config
          IFS=',' read -ra CONFIGS <<< "$CONFIG"
          for config in "${CONFIGS[@]}"; do
            IFS=':' read -r pattern strategy <<< "$config"
            [[ -z "$pattern" ]] && continue

            # If target specified, only process matching patterns
            if [[ -n "$TARGET" && "$TARGET" != "$pattern" ]]; then
              continue
            fi

            # Find matching remote branches
            for branch in $(git for-each-ref --format='%(refname:short)' "refs/remotes/origin/$pattern" | sed 's|origin/||'); do
              # Skip main itself
              [[ "$branch" == "main" ]] && continue

              # Enforce max branches limit
              if [[ $COUNT -ge $MAX_BRANCHES ]]; then
                echo "::warning::Reached max branches limit ($MAX_BRANCHES), skipping remaining"
                break 2
              fi

              ENTRIES+=("{\"branch\":\"$branch\",\"strategy\":\"${strategy:-ff-only}\",\"force\":\"${FORCE:-false}\"}")
              echo "::notice::Will sync: $branch (strategy: ${strategy:-ff-only})"
              ((COUNT++))
            done
          done

          if [[ ${#ENTRIES[@]} -eq 0 ]]; then
            echo "::notice::No branches to sync"
            echo "matrix={\"include\":[]}" >> "$GITHUB_OUTPUT"
          else
            MATRIX=$(printf '%s,' "${ENTRIES[@]}" | sed 's/,$//')
            echo "matrix={\"include\":[$MATRIX]}" >> "$GITHUB_OUTPUT"
            echo "::notice::Total branches to sync: ${#ENTRIES[@]}"
          fi

  sync-branch:
    needs: discover-branches
    if: fromJson(needs.discover-branches.outputs.matrix).include[0] != null
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.discover-branches.outputs.matrix) }}
      fail-fast: false
      max-parallel: 3
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Configure git
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

      - name: Analyze branch relationship
        id: analyze
        env:
          BRANCH: ${{ matrix.branch }}
        run: |
          git fetch origin main "$BRANCH"

          MAIN_SHA=$(git rev-parse origin/main)
          BRANCH_SHA=$(git rev-parse "origin/$BRANCH")
          MERGE_BASE=$(git merge-base origin/main "origin/$BRANCH" 2>/dev/null || echo "none")

          echo "main_sha=$MAIN_SHA" >> "$GITHUB_OUTPUT"
          echo "branch_sha=$BRANCH_SHA" >> "$GITHUB_OUTPUT"
          echo "merge_base=$MERGE_BASE" >> "$GITHUB_OUTPUT"

          if [[ "$MERGE_BASE" == "none" ]]; then
            echo "status=unrelated" >> "$GITHUB_OUTPUT"
          elif [[ "$MAIN_SHA" == "$BRANCH_SHA" ]]; then
            echo "status=equal" >> "$GITHUB_OUTPUT"
          elif [[ "$MERGE_BASE" == "$MAIN_SHA" ]]; then
            echo "status=ahead" >> "$GITHUB_OUTPUT"
          elif [[ "$MERGE_BASE" == "$BRANCH_SHA" ]]; then
            echo "status=behind" >> "$GITHUB_OUTPUT"
          else
            echo "status=diverged" >> "$GITHUB_OUTPUT"
          fi

      - name: Skip - already synced
        if: (steps.analyze.outputs.status == 'equal' || steps.analyze.outputs.status == 'ahead') && matrix.force != 'true'
        run: |
          echo "::notice::${{ matrix.branch }} is already up to date with main"

      - name: Force sync - already synced but force requested
        if: (steps.analyze.outputs.status == 'equal' || steps.analyze.outputs.status == 'ahead') && matrix.force == 'true'
        env:
          BRANCH: ${{ matrix.branch }}
        run: |
          echo "::notice::Force sync requested for $BRANCH (currently up to date)"
          git checkout "$BRANCH"
          git reset --hard origin/main
          git push origin "$BRANCH" --force-with-lease
          echo "::notice::Force synced $BRANCH to main"

      - name: Skip - unrelated branches
        if: steps.analyze.outputs.status == 'unrelated'
        run: |
          echo "::warning::${{ matrix.branch }} has no common ancestor with main, skipping"

      - name: Fast-forward sync
        if: steps.analyze.outputs.status == 'behind'
        env:
          BRANCH: ${{ matrix.branch }}
        run: |
          git checkout "$BRANCH"
          git merge --ff-only origin/main
          git push origin "$BRANCH"
          echo "::notice::Fast-forwarded $BRANCH to main"

      - name: Rebase sync (integration only)
        if: steps.analyze.outputs.status == 'diverged' && matrix.strategy == 'rebase'
        env:
          BRANCH: ${{ matrix.branch }}
        run: |
          git checkout "$BRANCH"

          if git rebase origin/main; then
            git push origin "$BRANCH" --force-with-lease
            echo "::notice::Rebased $BRANCH onto main"
          else
            git rebase --abort
            echo "::error::Rebase failed for $BRANCH - manual intervention required"
            exit 1
          fi

      - name: Skip - diverged (ff-only strategy)
        if: steps.analyze.outputs.status == 'diverged' && matrix.strategy != 'rebase'
        run: |
          echo "::warning::${{ matrix.branch }} has diverged from main"
          echo "::warning::Strategy is ff-only, skipping. Manual intervention may be required."

      - name: Verify sync
        if: steps.analyze.outputs.status == 'behind' || (steps.analyze.outputs.status == 'diverged' && matrix.strategy == 'rebase')
        env:
          BRANCH: ${{ matrix.branch }}
        run: |
          git fetch origin "$BRANCH"
          if git merge-base --is-ancestor origin/main "origin/$BRANCH"; then
            echo "::notice::Verification passed: main is ancestor of $BRANCH"
          else
            echo "::error::Verification failed: main is not ancestor of $BRANCH"
            exit 1
          fi

  # Summary job for reporting and failure notifications
  summary:
    needs: [discover-branches, sync-branch]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Check for failures
        id: check
        run: |
          if [[ "${{ needs.sync-branch.result }}" == "failure" ]]; then
            echo "has_failures=true" >> "$GITHUB_OUTPUT"
          else
            echo "has_failures=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Create issue for persistent sync failures
        if: steps.check.outputs.has_failures == 'true'
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          # Check if an issue already exists
          EXISTING=$(gh issue list --repo "${{ github.repository }}" \
            --label "sync-failure" --state open --json number --jq '.[0].number')

          if [[ -n "$EXISTING" ]]; then
            # Add comment to existing issue
            gh issue comment "$EXISTING" --repo "${{ github.repository }}" \
              --body "Sync workflow failed again on $(date -u +%Y-%m-%dT%H:%M:%SZ). [View run](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})"
          else
            # Create new issue
            gh issue create --repo "${{ github.repository }}" \
              --title "🔄 Branch sync failed - manual intervention required" \
              --label "sync-failure,automation" \
              --body "## Sync Workflow Failure

The branch sync workflow encountered failures that require manual intervention.

**Workflow Run:** [View details](${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }})
**Triggered by:** Push to main
**Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

### Possible Causes
- Rebase conflicts on integration branch
- Protected branch rules blocking push
- Network/GitHub API issues

### Resolution Steps
1. Check the workflow logs for specific errors
2. If rebase conflict: manually rebase integration onto main
3. If ruleset issue: verify GitHub Actions has bypass permissions
4. Once resolved, close this issue

/cc @aRustyDev"
          fi

      - name: Generate summary
        run: |
          echo "## Sync Workflow Summary" >> "$GITHUB_STEP_SUMMARY"
          echo "" >> "$GITHUB_STEP_SUMMARY"
          echo "| Job | Status |" >> "$GITHUB_STEP_SUMMARY"
          echo "|-----|--------|" >> "$GITHUB_STEP_SUMMARY"
          echo "| Discover | ${{ needs.discover-branches.result }} |" >> "$GITHUB_STEP_SUMMARY"
          echo "| Sync | ${{ needs.sync-branch.result }} |" >> "$GITHUB_STEP_SUMMARY"
          echo "" >> "$GITHUB_STEP_SUMMARY"
          if [[ "${{ needs.sync-branch.result }}" == "success" ]]; then
            echo "✅ All branches synced successfully" >> "$GITHUB_STEP_SUMMARY"
          elif [[ "${{ needs.sync-branch.result }}" == "failure" ]]; then
            echo "❌ Some branches failed to sync - see job logs for details" >> "$GITHUB_STEP_SUMMARY"
          else
            echo "⏭️ No branches required syncing" >> "$GITHUB_STEP_SUMMARY"
          fi
```

#### 3. Configure Repository Variable

```bash
# With full atomization, all branches use ff-only
gh variable set SYNC_BRANCH_CONFIG --body "integration:ff-only,hotfix/*:ff-only,charts/*:ff-only"
```

## Branch-Specific Behavior

### Integration Branch

> **With Full Atomization**: Integration is always reset to main after extraction,
> so divergence should never occur. Using ff-only strategy.

| Scenario | Action |
|----------|--------|
| Main ahead | Fast-forward |
| Integration ahead | No action (should not happen with atomization) |
| Diverged | Skip - should not occur with atomization (manual intervention if it does) |

### Hotfix Branches

| Scenario | Action |
|----------|--------|
| Main ahead | Fast-forward |
| Hotfix ahead | No action (hotfix has the fix) |
| Diverged | Skip (hotfix should be short-lived) |

### Charts Branches

| Scenario | Action |
|----------|--------|
| Main ahead | Fast-forward (pick up dependencies) |
| Charts ahead | No action |
| Diverged | Skip (will be cleaned up after merge) |

### Docs Branches

| Scenario | Action |
|----------|--------|
| Main ahead | Fast-forward |
| Docs ahead | No action |
| Diverged | Skip (docs PRs are typically short-lived) |

## Permissions Requirements

The workflow needs `contents: write` permission with the ability to force push for rebase operations. This is granted by `GITHUB_TOKEN` but requires:

1. **Ruleset configuration**: The `protected-branches-linear` ruleset blocks force pushes. For the sync workflow to work, we need to either:
   - Add `github-actions[bot]` to the bypass list
   - Or temporarily disable the ruleset during sync (not recommended)

### Recommended: Add Workflow Bypass to Ruleset

Update the `protected-branches-linear` ruleset:

```bash
gh api repos/aRustyDev/helm-charts/rulesets/11925113 --method PUT --input - << 'EOF'
{
  "name": "protected-branches-linear",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 2,
      "actor_type": "Integration",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": [
        "refs/heads/main",
        "refs/heads/integration",
        "refs/heads/release"
      ],
      "exclude": []
    }
  },
  "rules": [
    {"type": "required_linear_history"},
    {"type": "non_fast_forward"},
    {"type": "deletion"}
  ]
}
EOF
```

**Note**: The Actor ID for GitHub Actions bypass needs verification. Use this command to find the correct actor:

```bash
# List available bypass actors for the repository
gh api repos/aRustyDev/helm-charts/rulesets/rule-suites \
  --jq '.[] | select(.result == "bypass") | {actor_name, actor_type, actor_id}' 2>/dev/null || \
  echo "No bypass events found yet - the ID will be visible after first workflow run"

# Common actor configurations:
# - actor_id: 1, actor_type: "RepositoryRole" (Repository Admin)
# - actor_id: 2, actor_type: "RepositoryRole" (Repository Maintain)
# - actor_id: 5, actor_type: "RepositoryRole" (Repository Write)
# - For GitHub Actions app: actor_type: "Integration", actor_id varies by installation
```

If the bypass doesn't work, you may need to use `actor_type: "RepositoryRole"` with `actor_id: 5` (write role) instead of "Integration".

## Testing Plan

> **Note**: With full atomization, SY-T3 and SY-T7 are no longer applicable since
> integration uses ff-only and should never diverge from main.

| Test | Scenario | Expected |
|------|----------|----------|
| SY-T1 | Push to main with integration behind | Integration fast-forwarded |
| SY-T2 | Push to main with integration ahead | No action |
| ~~SY-T3~~ | ~~Push to main with integration diverged~~ | ~~N/A with atomization~~ |
| SY-T4 | Hotfix branch exists and behind | Fast-forward |
| SY-T5 | Charts branch exists and behind | Fast-forward |
| SY-T6 | Manual dispatch with specific branch | Only that branch synced |
| ~~SY-T7~~ | ~~Rebase conflict on integration~~ | ~~N/A with atomization~~ |
| SY-T8 | Force sync with branch already synced | Branch reset to main |
| SY-T9 | Many branches match pattern (>20) | Max 20 processed, warning logged |
| SY-T10 | Concurrent sync triggers | Jobs serialized, no conflicts |

## Verification Commands

```bash
# Check sync workflow runs
gh run list --workflow sync-main-to-branches.yaml

# Verify branch relationships after sync (all configured branches)
git fetch origin
for branch in integration $(git for-each-ref --format='%(refname:short)' 'refs/remotes/origin/hotfix/*' 'refs/remotes/origin/charts/*' | sed 's|origin/||'); do
  [[ "$branch" == "main" ]] && continue
  if git merge-base --is-ancestor origin/main "origin/$branch" 2>/dev/null; then
    echo "✅ $branch: synced (main is ancestor)"
  else
    echo "❌ $branch: NOT synced or diverged"
  fi
done

# Manual sync trigger (all branches)
gh workflow run sync-main-to-branches.yaml

# Manual sync trigger (specific branch)
gh workflow run sync-main-to-branches.yaml -f target_branch=integration

# Force sync (reset branch to main)
gh workflow run sync-main-to-branches.yaml -f target_branch=integration -f force=true

# Check for sync failure issues
gh issue list --label sync-failure --state open
```

## Migration from Existing Workflow

The current `sync-main-to-integration.yaml` must be handled during implementation:

| Option | Action | Recommendation |
|--------|--------|----------------|
| A. Delete | Remove old workflow, create new | **Recommended** - clean break |
| B. Rename | `git mv` to preserve history | Good if history matters |
| C. Keep Both | Disable old, enable new | Temporary for testing |

**Migration Steps:**
1. Create the new `sync-main-to-branches.yaml`
2. Test with manual dispatch
3. Delete `sync-main-to-integration.yaml`
4. Update documentation references

## Rollback Procedure

If a sync causes issues (e.g., bad commits propagated):

```bash
# 1. Identify the good commit before sync
git fetch origin
git log --oneline origin/integration

# 2. Reset the branch to the good state
GOOD_SHA="abc123"  # Replace with actual SHA
git checkout integration
git reset --hard "$GOOD_SHA"

# 3. Temporarily disable rulesets (if needed)
gh api repos/aRustyDev/helm-charts/rulesets/11925122 --method PUT \
  --input - <<< '{"enforcement": "disabled"}'

# 4. Force push the fix
git push origin integration --force-with-lease

# 5. Re-enable rulesets
gh api repos/aRustyDev/helm-charts/rulesets/11925122 --method PUT \
  --input - <<< '{"enforcement": "active"}'

# 6. Verify
git merge-base --is-ancestor origin/main origin/integration && echo "OK" || echo "Still diverged"
```

## Implementation Checklist

### Pre-Implementation
- [ ] Create `sync-failure` label in repository (for issue creation)
- [ ] Verify GitHub Actions actor ID for bypass (see note below)

### Workflow Implementation
- [ ] Create new `sync-main-to-branches.yaml` workflow
- [ ] Create `SYNC_BRANCH_CONFIG` repository variable
- [ ] Update `protected-branches-linear` ruleset with GitHub Actions bypass
- [ ] Delete old `sync-main-to-integration.yaml` after testing

### Testing
- [ ] Test with integration branch sync (auto-trigger on main push)
- [ ] Test with hotfix branch (create test hotfix, verify ff-only)
- [ ] Test manual dispatch (target_branch input)
- [ ] Test force sync (force input)
- [ ] Test failure notification (trigger intentional failure, verify issue created)
- [ ] Test concurrency control (trigger concurrent syncs, verify serialization)

### Documentation
- [ ] Update `.github/RULESETS.md` with GitHub Actions bypass
- [ ] Create ADR-010 for sync workflow design (or update existing)
- [ ] Update `docs/src/contributing.md` if applicable

## Files to Modify

| File | Action |
|------|--------|
| `.github/workflows/sync-main-to-branches.yaml` | Create (new) |
| `.github/workflows/sync-main-to-integration.yaml` | Delete (after testing new workflow) |
| `.github/RULESETS.md` | Document GitHub Actions bypass |
| Repository Labels | Create `sync-failure` label |
| Repository Variables | Create `SYNC_BRANCH_CONFIG` |
| `docs/src/adr/010-linear-history-rebase.md` | Update with sync details |

## Known Limitations

1. **No retry logic for transient failures** - Git operations may fail due to network issues. Consider adding retry wrapper if this becomes an issue.

2. **Rebase conflicts require manual intervention** - The workflow cannot automatically resolve merge conflicts.

3. **Force sync is destructive** - Using `force=true` will discard any commits in the target branch not in main.

4. **Branch discovery is pattern-based** - New branch patterns require config update.

5. **No cleanup of stale branches** - Branches that no longer match patterns won't be removed automatically.
