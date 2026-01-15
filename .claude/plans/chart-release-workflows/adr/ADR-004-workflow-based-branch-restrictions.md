# ADR-004: Workflow-Based Branch Restrictions

## Status
Proposed

## Context
The release pipeline requires restrictions that GitHub rulesets cannot enforce:
1. **Merge source restriction**: Only `integration` can merge to `integration/<chart>`
2. **Tag branch restriction**: Tags can only be created pointing to `main`

GitHub rulesets support:
- WHO can push/create/delete
- WHETHER PRs are required
- WHAT status checks must pass

But NOT:
- WHICH branch can be the source of a merge
- WHICH branch a tag can point to

## Decision
Implement workflow-based enforcement for unsupported restrictions.

### Merge Source Restriction
```yaml
name: Enforce Merge Source
on:
  pull_request:
    types: [opened, reopened, synchronize]
    branches:
      - 'integration/*'

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Check source branch
        run: |
          if [[ "${{ github.head_ref }}" != "integration" ]]; then
            echo "::error::Only 'integration' branch can merge to integration/<chart> branches"
            echo "Source branch '${{ github.head_ref }}' is not allowed"
            exit 1
          fi
```

### Tag Branch Restriction
```yaml
name: Create Release Tag
on:
  push:
    branches: [main]
    paths: ['charts/**']

jobs:
  tag:
    runs-on: ubuntu-latest
    steps:
      - name: Verify on main
        run: |
          if [[ "${{ github.ref }}" != "refs/heads/main" ]]; then
            echo "::error::Tags can only be created from main branch"
            exit 1
          fi

      - name: Create tag
        run: |
          git tag -a "<chart>-v<version>" -m "Release message"
          git push origin "<chart>-v<version>"
```

### Block Manual Tag Creation
Use rulesets to block ALL manual tag creation:
- Target: `*-v*` pattern
- Restrict creations: Enabled, no bypass
- Only workflows (with proper tokens) can create tags

## Consequences

### Positive
- Achieves restrictions not possible with rulesets alone
- Clear error messages for invalid operations
- Auditable through workflow logs

### Negative
- Restrictions not visible in GitHub UI settings
- Requires understanding workflow logic
- Could be bypassed by admin modifying workflows

### Mitigations
- Document restrictions clearly
- Add CODEOWNERS for workflow files
- Consider branch protection for workflow files

## Alternatives Considered

### 1. Pre-receive hooks
Server-side hooks that validate before accepting pushes.
- **Rejected**: Only available on GitHub Enterprise Server, not github.com

### 2. GitHub Apps with webhook listeners
External app that monitors and reverts invalid operations.
- **Rejected**: Complex, external dependency, eventual consistency issues

### 3. Accept the limitation
Don't enforce these restrictions.
- **Rejected**: Core to the security model of the pipeline
