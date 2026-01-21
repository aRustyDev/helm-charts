# ADR-006: Immutable Release Tags with Attestation Annotations

## Status
Proposed

## Context
Release tags need to:
- Be immutable once created (no deletion, no moving)
- Contain attestation lineage for verification
- Only point to commits on `main`
- Follow the `<chart>-vX.Y.Z` pattern

Git annotated tags can contain messages (annotations), which can store attestation data.

## Decision
Create immutable annotated tags with attestation lineage in the annotation.

### Tag Format
```
<chart>-v<major>.<minor>.<patch>
```

Examples:
- `cloudflared-v0.5.0`
- `mdbook-htmx-v0.3.0`

### Annotation Format
```
Release: <chart> v<version>

Attestation Lineage:
- workflow-1-overall: <attestation-id>
- workflow-5-semver: <attestation-id>
- workflow-5-overall: <attestation-id>

Changelog:
<keep-a-changelog formatted diff>

Commit: <sha>
PR: #<number>
```

### Creation
```bash
git tag -a "<chart>-v<version>" -m "$(cat <<EOF
Release: <chart> v<version>

Attestation Lineage:
- workflow-1-overall: $WORKFLOW_1_ATTESTATION
- workflow-5-semver: $WORKFLOW_5_SEMVER_ATTESTATION
- workflow-5-overall: $WORKFLOW_5_OVERALL_ATTESTATION

Changelog:
$CHANGELOG_DIFF

Commit: $COMMIT_SHA
PR: #$PR_NUMBER
EOF
)"
git push origin "<chart>-v<version>"
```

### Protection (Rulesets)
| Rule | Setting |
|------|---------|
| Target pattern | `*-v*` |
| Restrict deletions | Enabled, no bypass |
| Restrict updates | Enabled, no bypass |
| Restrict creations | Enabled, no bypass (workflows only) |

## Consequences

### Positive
- Tags are truly immutable
- Attestation data is part of the tag object
- Easily retrievable: `git tag -l --format='%(contents)' <tag>`
- No external storage needed

### Negative
- Tag annotations have size limits (~1MB)
- Can't update attestation data after creation
- Requires careful formatting

### Verification
```bash
# Get tag annotation
git tag -l --format='%(contents)' cloudflared-v0.5.0

# Verify attestations
for id in $(git tag -l --format='%(contents)' cloudflared-v0.5.0 | grep -oP 'workflow-\d+-\w+: \K\d+'); do
  gh attestation verify --attestation-id "$id" ...
done
```

## Alternatives Considered

### 1. Lightweight tags + external attestation storage
Use lightweight tags, store attestation data elsewhere.
- **Rejected**: Adds external dependency, attestation data could be lost

### 2. Release notes only
Store attestation data in GitHub Release notes instead of tag.
- **Rejected**: Release notes can be edited, not immutable

### 3. Signed tags
Use GPG-signed tags.
- **Rejected**: Adds key management complexity, GitHub Attestations already provide signing
