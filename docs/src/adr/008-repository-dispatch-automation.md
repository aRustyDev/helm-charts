# ADR-008: Repository Dispatch for Workflow Automation

**Status:** Accepted
**Date:** 2025-01-17

## Context

GitHub Actions workflows triggered by `GITHUB_TOKEN` do not trigger other workflows. This is an intentional anti-loop protection mechanism. However, our CI pipeline requires W2 (Create Atomic Chart PR) to trigger W5 (Validate Atomic Chart PR) after creating PRs to main.

Without automation, PRs created by W2 would require manual intervention to trigger validation, breaking the automated release pipeline.

## Decision

Use `repository_dispatch` events with actor validation to enable W2 to trigger W5 automatically while maintaining security controls.

### Implementation

1. **W2 dispatches event after PR creation:**
```yaml
- name: Trigger W5 validation
  run: |
    gh api "repos/${{ github.repository }}/dispatches" \
      --method POST \
      -f event_type=chart-pr-created \
      -f client_payload="{\"pr\": $PR_NUMBER, \"chart\": \"$CHART\"}"
```

2. **W5 listens for repository_dispatch:**
```yaml
on:
  repository_dispatch:
    types: [chart-pr-created]
```

3. **W5 validates the actor before proceeding:**
```yaml
env:
  ALLOWED_DISPATCH_ACTORS: "github-actions[bot]"

jobs:
  validate-dispatch:
    if: github.event_name == 'repository_dispatch'
    steps:
      - name: Validate Actor
        run: |
          if [[ ! ",$ALLOWED_DISPATCH_ACTORS," =~ ",${{ github.actor }}," ]]; then
            echo "::error::Unauthorized actor"
            exit 1
          fi
```

4. **W5 fetches PR context via API for dispatch events:**
```yaml
- name: Determine PR Context
  run: |
    PR_DATA=$(gh api "repos/.../pulls/$PR_NUMBER" --jq '{head_ref, head_sha, base_ref, base_sha}')
```

## Rationale

### Why repository_dispatch over alternatives?

| Option | Pros | Cons |
|--------|------|------|
| **PAT (Personal Access Token)** | Simple | Not automatable (rotation), single point of failure |
| **workflow_dispatch** | Built-in | Open to any authorized API user, less scoped |
| **repository_dispatch** | Scoped event types, actor validation | Requires API call |
| **GitHub App Token** | Most secure | More complex setup |

`repository_dispatch` provides the best balance of security and simplicity:
- Event types (`chart-pr-created`) scope what can trigger the workflow
- Actor validation restricts WHO can trigger it
- Audit logging tracks all dispatch events
- No external tokens to manage

### Security Controls

1. **Actor Allowlist:** Only `github-actions[bot]` can trigger W5 via dispatch
2. **Event Type Scoping:** Only `chart-pr-created` events are accepted
3. **Payload Validation:** PR number is required in the payload
4. **Audit Trail:** All dispatch events are logged with actor, event, PR, chart, and run_id

## Consequences

### Positive
- Automated W2→W5 pipeline without manual intervention
- Security controls prevent unauthorized triggering
- Audit trail for compliance and debugging
- Extensible pattern for future workflow chaining

### Negative
- Additional complexity in workflow code
- W5 must handle both PR events and dispatch events
- Actor validation list must be maintained

## Alternatives Considered

### Use GitHub App Token in W2 for PR Creation
Workflows triggered by GitHub App tokens DO trigger other workflows. However, this requires managing app credentials and adds complexity for a simple use case.

### Require Manual PR Approval to Trigger W5
Rejected because it defeats the purpose of automation and creates bottlenecks.

### Use `pull_request_target` in W5
Rejected because `pull_request_target` has security implications and doesn't solve the token-triggered workflow problem.

## Related

- [ADR-005: CI Workflows](005-ci-workflows.md)
- [Workflow 2 Plan](.claude/plans/chart-release-workflows/workflow-2/plan.md)
- [Workflow 5 Plan](.claude/plans/chart-release-workflows/workflow-5/plan.md)
