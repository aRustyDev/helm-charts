# ADR-002: Branch Architecture for Atomic Releases

## Status
Proposed

## Context
The current branch structure (`main`, `charts`) doesn't support:
- Staging area for contributions before they reach main
- Per-chart isolation for atomic releases
- Clear separation between source and published artifacts

We need a branch architecture that:
- Provides a staging area with review gates
- Supports atomic per-chart processing
- Clearly separates code source from release artifacts

## Decision
Implement a four-tier branch architecture:

### Long-Lived Branches
| Branch | Purpose |
|--------|---------|
| `main` | Stable, reviewed, releasable code |
| `integration` | Staging area between features and main |
| `release` | Published chart artifacts (renamed from `charts`) |

### Dynamic Branches
| Pattern | Purpose | Lifecycle |
|---------|---------|-----------|
| `integration/<chart>` | Per-chart atomic changes | Created by workflow, deleted after merge to main |

### Flow
```
feature/* → integration → integration/<chart> → main → release
```

### Branch Initial States
- `integration`: Created from `main`
- `release`: Renamed from existing `charts` branch

## Consequences

### Positive
- Clear staging area for review
- Per-chart isolation enables atomic releases
- `release` branch name is more semantic than `charts`
- Supports parallel development of multiple charts

### Negative
- More branches to manage
- Potential confusion during transition
- `integration/<chart>` branches require cleanup

### Migration Required
1. Create `integration` branch from `main`
2. Rename `charts` to `release`
3. Update Cloudflare Pages configuration
4. Update any CI/CD references

## Alternatives Considered

### 1. Keep existing structure
Use `main` and `charts` only.
- **Rejected**: No staging area, no per-chart isolation

### 2. Use tags only for releases
No release branch, only tags.
- **Rejected**: Need a branch for Helm repo index hosting

### 3. Per-chart branches permanently
Keep `integration/<chart>` as long-lived branches.
- **Rejected**: Too many branches, harder to manage, not needed for our scale
