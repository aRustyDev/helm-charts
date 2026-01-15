# Workflow 3: Enforce Atomic Chart PRs

## Goal
Validate that PRs to `integration/<chart>` branches only come from `integration`, then auto-merge them. This enforces the atomic release pattern by preventing unauthorized changes to per-chart branches.

## Trigger
```yaml
on:
  pull_request:
    types: [opened, reopened, synchronize]
    branches:
      - 'integration/*'
```

## Inputs

| Input | Source | Description |
|-------|--------|-------------|
| PR Number | `github.event.pull_request.number` | PR to validate |
| Source Branch | `github.head_ref` | Branch being merged from |
| Target Branch | `github.base_ref` | Target `integration/<chart>` branch |
| PR Author | `github.event.pull_request.user.login` | Who opened the PR |

## Outputs

| Output | Destination | Description |
|--------|-------------|-------------|
| Merge Status | PR | Merged or closed |
| Validation Result | Check Status | Pass/fail |

## Controls (Rulesets)

| Control | Setting |
|---------|---------|
| `integration/*` push | Blocked (no bypass) |
| Source restriction | Workflow-enforced (only `integration`) |

## Processes

### 1. Validate Source Branch
```yaml
jobs:
  validate-and-merge:
    runs-on: ubuntu-latest
    steps:
      - name: Validate source branch
        id: validate
        run: |
          SOURCE="${{ github.head_ref }}"
          TARGET="${{ github.base_ref }}"

          echo "Source: $SOURCE"
          echo "Target: $TARGET"

          if [[ "$SOURCE" != "integration" ]]; then
            echo "::error::Invalid source branch"
            echo "Only 'integration' branch can merge to $TARGET"
            echo "Got: $SOURCE"
            echo "valid=false" >> $GITHUB_OUTPUT
            exit 1
          fi

          echo "valid=true" >> $GITHUB_OUTPUT
          echo "Source branch validation passed"
```

### 2. Verify Attestation Map Exists
```yaml
      - name: Verify attestation map
        run: |
          PR_BODY=$(gh pr view ${{ github.event.pull_request.number }} --json body -q '.body')

          if ! echo "$PR_BODY" | grep -q "ATTESTATION_MAP"; then
            echo "::warning::No attestation map found in PR description"
            echo "This PR may have been created manually"
            # Don't fail, but log warning
          fi
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 3. Auto-Close Invalid PRs
```yaml
      - name: Close invalid PR
        if: failure()
        run: |
          gh pr close ${{ github.event.pull_request.number }} \
            --comment "This PR was auto-closed because it violates the atomic release policy.

**Reason:** Only the \`integration\` branch can merge to \`integration/<chart>\` branches.

**Source branch:** \`${{ github.head_ref }}\`
**Expected source:** \`integration\`

If you need to make changes to this chart, please:
1. Create a PR to \`integration\` branch
2. Wait for it to be merged
3. The system will automatically create the appropriate per-chart PR

---
*Auto-closed by Workflow 3: Enforce Atomic Chart PRs*"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 4. Auto-Merge Valid PRs
```yaml
      - name: Auto-merge
        if: steps.validate.outputs.valid == 'true'
        run: |
          echo "Enabling auto-merge for PR #${{ github.event.pull_request.number }}"

          # Enable auto-merge (squash)
          gh pr merge ${{ github.event.pull_request.number }} \
            --auto \
            --squash \
            --subject "chore(${{ github.base_ref }}): sync from integration"
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## Shared Components Used
- `gh` CLI for PR operations
- Source branch validation logic
- Auto-merge functionality

## Error Handling
- Invalid source branch: Close PR with explanation
- Merge conflicts: Fail and notify (shouldn't happen with workflow-only creation)
- API failures: Retry with backoff

## Security Considerations
- This workflow runs on `pull_request`, which has limited permissions
- Auto-merge requires `GITHUB_TOKEN` with write access
- Consider using GitHub App token for higher trust operations

## Sequence Diagram
```
┌──────┐     ┌────────┐     ┌──────────┐     ┌──────────────┐
│ PR   │     │ GitHub │     │ Workflow │     │ integration/ │
│opened│     │        │     │    3     │     │ <chart>      │
└──┬───┘     └───┬────┘     └────┬─────┘     └──────┬───────┘
   │             │               │                   │
   │ PR opened   │               │                   │
   │────────────►│               │                   │
   │             │               │                   │
   │             │ Trigger       │                   │
   │             │──────────────►│                   │
   │             │               │                   │
   │             │               │ Check source      │
   │             │               │─────────┐         │
   │             │               │         │         │
   │             │               │◄────────┘         │
   │             │               │                   │
   │             │ [valid]       │                   │
   │             │               │ Auto-merge        │
   │             │               │──────────────────►│
   │             │               │                   │
   │             │ [invalid]     │                   │
   │             │               │ Close PR          │
   │             │◄──────────────│                   │
```
