# ADR-003: Attestation ID Storage in PR Descriptions

## Status
Proposed

## Context
Each workflow step produces a GitHub Attestation with a unique ID. Downstream workflows need to:
- Read attestation IDs from upstream steps
- Verify attestations before proceeding
- Build an attestation lineage chain

We need a storage mechanism that:
- Persists across workflow runs
- Is accessible to all workflows
- Can be updated by multiple checks (potentially in parallel)
- Doesn't require external storage

## Decision
Store attestation IDs in PR descriptions using a JSON map inside an HTML comment block.

### Format
```markdown
<!-- ATTESTATION_MAP
{
  "lint-test-v1.32.11": "123456",
  "lint-test-v1.33.7": "234567",
  "lint-test-v1.34.3": "345678",
  "artifacthub-lint": "456789",
  "security": "567890",
  "commit-validation": "678901",
  "changelog-generation": "789012"
}
-->
```

### Update Logic
```bash
# Read existing map
existing=$(gh pr view $PR --json body -q '.body' | grep -ozP '<!-- ATTESTATION_MAP\n\K[^-]+' | tr -d '\0')

# Parse, update, serialize
updated=$(echo "$existing" | jq --arg key "$CHECK_NAME" --arg val "$ATTESTATION_ID" '. + {($key): $val}')

# Replace in PR body
new_body=$(echo "$body" | sed "s|<!-- ATTESTATION_MAP.*-->|<!-- ATTESTATION_MAP\n$updated\n-->|")
gh pr edit $PR --body "$new_body"
```

### Race Condition Handling
Use GitHub API's optimistic locking or implement retry logic with exponential backoff.

## Consequences

### Positive
- No external storage required
- Visible in PR for debugging
- Persists across workflow runs
- Easy to parse with standard tools

### Negative
- PR description size limit (~65KB) could be hit with many attestations
- Race conditions possible with parallel updates
- Unconventional storage location
- HTML comments not rendered in UI

### Mitigations
- Implement retry logic for concurrent updates
- Monitor description size
- Document the format clearly

## Alternatives Considered

### 1. GitHub Actions artifacts
Store attestation IDs as workflow artifacts.
- **Rejected**: Artifacts are per-workflow, can't be easily read across workflows

### 2. PR comments
Each check adds a comment with its attestation ID.
- **Rejected**: Harder to parse, comments can be deleted, creates noise

### 3. Repository file
Commit attestation IDs to a file.
- **Rejected**: Creates commit noise, complicates the flow

### 4. External storage (S3, etc.)
Store attestation IDs externally.
- **Rejected**: Adds external dependency, complexity, and cost
