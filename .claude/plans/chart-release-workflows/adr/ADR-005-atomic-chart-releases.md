# ADR-005: Atomic Chart Releases via File-Based Checkout

## Status
Proposed

## Context
When multiple charts change in a single contribution, we need to:
- Process each chart independently
- Create separate releases for each chart
- Maintain separate attestation lineages

The challenge: a single commit may touch multiple charts, and `git cherry-pick` operates on whole commits, not file subsets.

## Decision
Use file-based checkout (`git checkout <sha> -- charts/<chart>/`) instead of cherry-pick.

### Process
1. Detect changed charts in merge commit
2. For each chart, create/update `integration/<chart>` branch:
   ```bash
   # Checkout or create the per-chart branch
   git checkout integration/<chart> 2>/dev/null || git checkout -b integration/<chart> integration

   # Checkout only this chart's files from the merge commit
   git checkout <merge-sha> -- charts/<chart>/

   # Commit the changes
   git commit -m "chore(<chart>): sync from integration"

   # Push
   git push origin integration/<chart>
   ```

### Detection Logic
```bash
# Get list of changed charts
changed_charts=$(git diff --name-only HEAD~1 HEAD | grep '^charts/' | cut -d'/' -f2 | sort -u)

for chart in $changed_charts; do
  # Process each chart independently
  ...
done
```

## Consequences

### Positive
- Works even when single commit touches multiple charts
- Clean, isolated changes per chart
- Clear commit history per chart branch

### Negative
- Doesn't preserve original commit metadata
- New commit SHA different from original
- Could miss cross-chart dependencies

### Handling Cross-Chart Dependencies
If charts have dependencies on each other:
1. Order processing based on dependency graph
2. Fail fast if circular dependencies detected
3. Document that cross-chart changes should be separate commits

## Alternatives Considered

### 1. Require single-chart commits
Reject PRs where a single commit touches multiple charts.
- **Rejected**: Too restrictive for legitimate refactoring

### 2. Cherry-pick with patch
Use `git format-patch` and `git apply` with path filters.
- **Rejected**: More complex, similar outcome

### 3. Process all charts together
Don't split, release all changed charts at once.
- **Rejected**: Defeats atomic release purpose, complicates rollback
