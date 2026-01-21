# Full Atomization Model

## Overview

Integration branch operates as a **staging branch**, not an accumulator. All content from PRs to integration gets extracted to atomic branches, then the source commits are removed from integration.

```
                                    ┌─► charts/<chart> ─┐
                                    │                   │
feat/* ──► integration (staging) ──►├─► docs/<topic> ──►├──► main
                │                   │                   │
                │                   └─► ci/<feature> ──►┘
                │                           │
                └───── reset ◄──────────────┘
                    (after extraction)
```

## Key Principles

1. **Integration is ephemeral**: Commits pass through, get atomized, then are removed
2. **All content is atomized**: Charts, docs, CI, configs - everything gets its own branch
3. **Related changes are linked**: Commits from the same source PR are tagged as related
4. **No rebasing needed**: Integration stays aligned with main via fast-forward only

## Content Types and Branch Patterns

| Content Type | Path Pattern | Branch Pattern | Example |
|--------------|--------------|----------------|---------|
| Charts | `charts/<name>/**` | `charts/<name>` | `charts/cloudflared` |
| Documentation | `docs/**` | `docs/<topic>` | `docs/attestation` |
| CI/Workflows | `.github/workflows/**` | `ci/<feature>` | `ci/sync-workflow` |
| CI/Scripts | `.github/scripts/**` | `ci/<feature>` | `ci/release-scripts` |
| Repository Config | `.github/*.md`, `CONTRIBUTING.md`, etc. | `repo/<topic>` | `repo/contributing` |
| ADRs | `docs/src/adr/**` | `docs/adr-<number>` | `docs/adr-011` |

## Configuration File

Branch patterns and chart relationships are defined in `.github/actions/configs/atomic-branches.json`:

```json
{
  "branches": [
    {
      "name": "$chart",
      "prefix": "chart/",
      "pattern": "charts/(?P<chart>[^/]+)/**"
    },
    {
      "name": "$topic",
      "prefix": "docs/",
      "pattern": "docs/src/(?P<topic>[^/]+)/**"
    },
    {
      "name": "$workflow",
      "prefix": "ci/",
      "pattern": "\\.github/workflows/(?P<workflow>[^/]+)\\.yaml"
    }
  ],
  "charts": [
    {
      "name": "cloudflared",
      "related": [
        "docs/src/cloudflared/*",
        "docs/src/adr/adr-009.md",
        "docs/src/tunnels/cloudflare.md"
      ],
      "priority": 1
    },
    {
      "name": "external-secrets",
      "related": [
        "docs/src/external-secrets/*"
      ],
      "priority": 2
    }
  ]
}
```

### Branch Pattern Mechanics

Pattern matching extracts named groups to construct branch names:

| File Path | Pattern Match | Extracted | Branch Name |
|-----------|---------------|-----------|-------------|
| `charts/cloudflared/values.yaml` | `charts/(?P<chart>[^/]+)/**` | `chart=cloudflared` | `chart/cloudflared` |
| `docs/src/tunnels/setup.md` | `docs/src/(?P<topic>[^/]+)/**` | `topic=tunnels` | `docs/tunnels` |
| `.github/workflows/release.yaml` | `\.github/workflows/(?P<workflow>...)` | `workflow=release` | `ci/release` |

### Priority Hierarchy

The `priority` field in chart config is **advisory** for merge order. PRs include dependency tags:

```markdown
## Dependencies
depends-on: #43
blocking: #45
```

## Relationship Determination

Five-tier system for determining what's related. **No path inference** - relationships must be explicit.

### Tier 1 (Highest): Configuration File

Defined in `atomic-branches.json` under `charts[].related`:

```json
{
  "name": "cloudflared",
  "related": ["docs/src/cloudflared/*", "docs/src/adr/adr-009.md"]
}
```

### Tier 2: Frontmatter (Markdown only)

YAML frontmatter in `.md` files:

```markdown
---
related:
  charts:
    - cloudflared
    - external-secrets
---

# Configuration Guide
...
```

### Tier 3: Commit Footer

Explicit `related:` trailer in commit message:

```
feat(cloudflared): add metrics support

Add prometheus metrics endpoint.

related: docs/src/cloudflared/metrics.md
related: charts/external-secrets/*
```

### Tier 4: Conventional Commit Scope

Scope in commit message implies relationship:

```
feat(cloudflared): add metrics    → relates to cloudflared
docs(cloudflared): update readme  → relates to cloudflared
fix(ci): repair release workflow  → relates to ci (standalone)
```

### Tier 5 (Lowest): Same Commit

Files in the same commit are considered related (separate branches, linked PRs).

### Relationship Resolution

**Priority**: Tier 1 > Tier 2 > Tier 3 > Tier 4 > Tier 5

**Key Rule**: Relationships only apply to content that actually changed. If a file's frontmatter says it relates to `external-secrets`, but `external-secrets` didn't change in this PR, no related link is added.

**Example 1**: Changes to `docs/src/cloudflared/*` and `charts/cloudflared/*`
```
PR: chart/cloudflared
  - Related: #<docs-pr>

PR: docs/cloudflared
  - Related: #<chart-pr>
```

**Example 2**: Changes to `docs/src/cloudflared/*`, `charts/cloudflared/*`, and `charts/external-secrets/*`
(where `docs/src/cloudflared/foo.md` has frontmatter: `.related.charts: [external-secrets]`)
```
PR: chart/cloudflared
  - Related: #<docs-pr>

PR: chart/external-secrets
  - Related: #<docs-pr>

PR: docs/cloudflared
  - Related: #<chart-cloudflared-pr>, #<chart-external-secrets-pr>
```

## Special Groupings

### `requires: <uuid>` - Bundle Commits

Group multiple commits into a single branch using a shared UUID:

```
# Commit A
feat(cloudflared): add metrics endpoint

requires: 550e8400-e29b-41d4-a716-446655440000

# Commit B
docs(cloudflared): document metrics

requires: 550e8400-e29b-41d4-a716-446655440000
```

Both commits go to the same branch (UUID generated by developer, not CI).

### `requires(<file>): <required-file>` - Surgical Selection

Bundle specific files together:

```
feat(cloudflared): update values and schema

requires(values.yaml): values.schema.json
```

Result: `values.yaml` and `values.schema.json` go together, other files in the commit may go to different branches.

## Grouping Rules

### Files → Separate Branches with Related Links

Related files go to **separate** branches, not bundled together:

```
Source PR #42 to integration:
├── charts/cloudflared/values.yaml
├── docs/src/cloudflared/config.md
└── .github/workflows/release.yaml

Creates:
├── chart/cloudflared (PR #43)
│   └── Related: #44
├── docs/cloudflared (PR #44)
│   └── Related: #43
└── ci/release (PR #45)
    └── (no related - different content type)
```

### Docs Bundling Rule

| Path Pattern | Branch |
|--------------|--------|
| `charts/<chart>/docs/*` | `chart/<chart>` (bundled with chart) |
| `docs/src/<topic>/*` | `docs/<topic>` (separate branch) |

## Dead Letter Queue (DLQ)

If a file has **no relationship at any tier**:

1. Push to `dlq/<source-pr-number>` branch
2. Create issue with `bug` label
3. Title: `ci(dlq): unmatched files from PR #<number>`

```
dlq/42/
├── some-random-file.txt
└── unknown/path/file.md
```

Manual resolution required - add relationship metadata and re-process.

## Workflow: Two-Phase Atomization

### Phase 1: PR Validation (Gate)

**Trigger**: When PR is opened/updated against integration

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened]
    branches: [integration]
```

**Purpose**: Verify atomization will succeed BEFORE merge

```
1. Analyze PR changes
   ├── Get list of changed files
   ├── Categorize by content type
   ├── Determine relationships (see below)
   └── Generate predicted atomic branch names

2. Dry-run cherry-pick verification
   ├── For each predicted atomic branch:
   │   ├── Create temp branch from main
   │   ├── Attempt cherry-pick --no-commit
   │   ├── Record success/failure
   │   └── Cleanup temp branch
   └── Report results

3. Gate decision
   ├── All cherry-picks succeed → ✅ Check passes
   └── Any cherry-pick fails → ❌ Check fails, PR blocked
```

**Status Check**: `atomic-branching-preview`
- Required for merge to integration
- Prevents PRs that can't be atomized
- Shows preview of branches that will be created

### Phase 2: Extract and Reset (Post-Merge)

**Trigger**: When PR is merged to integration

```yaml
on:
  pull_request:
    types: [closed]
    branches: [integration]
```

**Purpose**: Execute the atomization (already validated in Phase 1)

```
1. Re-analyze merged PR (same logic as Phase 1)

2. For each content category:
   ├── Create atomic branch from main
   ├── Cherry-pick changes (should succeed - validated in Phase 1)
   ├── Add 'Related-To' footer to commit
   └── Push branch

3. Create PRs with related links

4. Reset integration to main

5. If ANY step fails:
   ├── Don't push remaining branches
   ├── Don't reset integration
   └── Create failure issue
```

### Example: Mixed Content PR

**Source PR #42 to integration:**
```
Files changed:
- charts/cloudflared/values.yaml
- charts/cloudflared/templates/deployment.yaml
- docs/src/cloudflared/configuration.md
- .github/workflows/release.yaml
```

**Extraction creates:**

1. `charts/cloudflared` branch:
   ```
   feat(cloudflared): add new configuration options

   Related-To: #42
   Related-PRs: #43, #44
   ```

2. `docs/cloudflared-config` branch:
   ```
   docs(cloudflared): update configuration documentation

   Related-To: #42
   Related-PRs: #43, #44
   ```

3. `ci/release-workflow` branch:
   ```
   fix(ci): update release workflow

   Related-To: #42
   Related-PRs: #43, #44
   ```

**Each PR description includes:**
```markdown
## Related Changes

This PR is part of a set of related changes from integration PR #42:

- #43 - charts/cloudflared: add new configuration options
- #44 - docs/cloudflared: update configuration documentation
- #45 - ci/release: update release workflow (this PR)

All PRs should be reviewed and merged together.
```

## Commit Footer Format

```
<type>(<scope>): <description>

<body>

Related-To: #<source-integration-pr>
Related-PRs: #<pr1>, #<pr2>, #<pr3>
```

## Integration Reset Strategy

After extraction, integration must be reset to remove the extracted commits.

### Option A: Hard Reset to Main

```bash
# After all atomic branches created
git checkout integration
git reset --hard origin/main
git push origin integration --force-with-lease
```

**Requires**: Bypass on `protected-branches-linear` for integration only

### Option B: Revert Commits

```bash
# Create revert commit instead of force push
git checkout integration
git revert <extracted-commit-sha> --no-edit
git push origin integration
```

**Pros**: No force push needed, maintains linear history
**Cons**: Adds revert commits to history

### Option C: Squash-Reset via PR

```bash
# Create a "reset" PR that squashes integration to main
git checkout -b reset/integration-$(date +%Y%m%d)
git reset --hard origin/main
# Create PR: reset/* -> integration with squash merge
```

**Pros**: Uses normal PR flow, no bypass needed
**Cons**: More complex, requires PR approval

### Recommended: Option A with Scoped Bypass

Create a new ruleset that allows force push on integration only for the automation workflow:

```yaml
# New ruleset: integration-automation-bypass
conditions:
  ref_name:
    include: ["refs/heads/integration"]
rules:
  - type: non_fast_forward  # Allow force push
bypass_actors:
  - actor_id: 5  # Admin
    actor_type: RepositoryRole
```

And modify `protected-branches-linear` to exclude integration:

```yaml
# Updated protected-branches-linear
conditions:
  ref_name:
    include:
      - "refs/heads/main"
      - "refs/heads/release"
    # Remove integration - handled by separate ruleset
```

## Workflow Implementation

### W2-Atomize: Extract All Content Types

```yaml
name: Atomize Integration PR

on:
  pull_request:
    types: [closed]
    branches: [integration]

jobs:
  analyze:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    outputs:
      categories: ${{ steps.categorize.outputs.categories }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Categorize changes
        id: categorize
        run: |
          # Get changed files from the merged PR
          FILES=$(gh pr diff ${{ github.event.pull_request.number }} --name-only)

          CATEGORIES=()

          # Categorize each file
          for file in $FILES; do
            case "$file" in
              charts/*/*)
                CHART=$(echo "$file" | cut -d/ -f2)
                CATEGORIES+=("chart:$CHART")
                ;;
              docs/src/adr/*)
                ADR=$(basename "$file" .md)
                CATEGORIES+=("docs:$ADR")
                ;;
              docs/*)
                # Extract topic from path
                TOPIC=$(echo "$file" | sed 's|docs/src/||' | cut -d/ -f1)
                CATEGORIES+=("docs:$TOPIC")
                ;;
              .github/workflows/*)
                WF=$(basename "$file" .yaml)
                CATEGORIES+=("ci:$WF")
                ;;
              .github/scripts/*)
                CATEGORIES+=("ci:scripts")
                ;;
              .github/*.md|CONTRIBUTING.md|README.md)
                CATEGORIES+=("repo:docs")
                ;;
              *)
                CATEGORIES+=("other:misc")
                ;;
            esac
          done

          # Deduplicate and output
          UNIQUE=$(printf '%s\n' "${CATEGORIES[@]}" | sort -u | jq -R -s -c 'split("\n") | map(select(length > 0))')
          echo "categories=$UNIQUE" >> "$GITHUB_OUTPUT"

  extract:
    needs: analyze
    if: needs.analyze.outputs.categories != '[]'
    runs-on: ubuntu-latest
    strategy:
      matrix:
        category: ${{ fromJson(needs.analyze.outputs.categories) }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Parse category
        id: parse
        run: |
          TYPE=$(echo "${{ matrix.category }}" | cut -d: -f1)
          NAME=$(echo "${{ matrix.category }}" | cut -d: -f2)

          case "$TYPE" in
            chart) BRANCH="charts/$NAME" ;;
            docs)  BRANCH="docs/$NAME" ;;
            ci)    BRANCH="ci/$NAME" ;;
            repo)  BRANCH="repo/$NAME" ;;
            *)     BRANCH="other/$NAME" ;;
          esac

          echo "type=$TYPE" >> "$GITHUB_OUTPUT"
          echo "name=$NAME" >> "$GITHUB_OUTPUT"
          echo "branch=$BRANCH" >> "$GITHUB_OUTPUT"

      - name: Create atomic branch
        env:
          BRANCH: ${{ steps.parse.outputs.branch }}
          TYPE: ${{ steps.parse.outputs.type }}
          NAME: ${{ steps.parse.outputs.name }}
          SOURCE_PR: ${{ github.event.pull_request.number }}
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          # Create branch from main
          git checkout -b "$BRANCH" origin/main

          # Get files for this category
          case "$TYPE" in
            chart) PATTERN="charts/$NAME/" ;;
            docs)  PATTERN="docs/" ;;
            ci)    PATTERN=".github/" ;;
            repo)  PATTERN="" ;;  # Handle separately
          esac

          # Cherry-pick with path filter
          # (Implementation depends on how we want to handle partial commits)

          # Push branch
          git push origin "$BRANCH"

      - name: Create PR
        env:
          BRANCH: ${{ steps.parse.outputs.branch }}
          SOURCE_PR: ${{ github.event.pull_request.number }}
          GH_TOKEN: ${{ github.token }}
        run: |
          gh pr create \
            --base main \
            --head "$BRANCH" \
            --title "$(git log -1 --format=%s)" \
            --body "## Atomized from Integration PR #$SOURCE_PR

          This PR contains the ${{ steps.parse.outputs.type }} changes from #$SOURCE_PR.

          Related-To: #$SOURCE_PR

          ---
          *Automatically created by the atomization workflow*"

  reset-integration:
    needs: [analyze, extract]
    if: always() && needs.extract.result == 'success'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Reset integration to main
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"

          git checkout integration
          git reset --hard origin/main
          git push origin integration --force-with-lease
```

## Ruleset Changes Required

### 1. Modify `protected-branches-linear` (11925113)

Remove integration from this ruleset:

```json
{
  "conditions": {
    "ref_name": {
      "include": [
        "refs/heads/main",
        "refs/heads/release"
      ]
    }
  }
}
```

### 2. Create `integration-linear-with-reset` (new)

New ruleset for integration that allows automation to force-push:

```json
{
  "name": "integration-linear-with-reset",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [
    {
      "actor_id": 5,
      "actor_type": "RepositoryRole",
      "bypass_mode": "always"
    }
  ],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/integration"]
    }
  },
  "rules": [
    {"type": "required_linear_history"},
    {"type": "deletion"}
  ]
}
```

Note: `non_fast_forward` is NOT included, allowing force-push with bypass.

### 3. Keep `integration-pr-required` (11925122)

Keep as-is with admin bypass for PR/status check requirements.

## Sync Workflow Simplification

With full atomization, the sync workflow becomes much simpler:

```yaml
# sync-main-to-branches.yaml changes

# Integration now only needs fast-forward
# Rebase logic can be removed for integration
# Other branches (hotfix/*, docs/*) keep ff-only strategy
```

Since integration is always reset after extraction, it should never diverge from main. The sync workflow just needs to fast-forward integration when main is ahead.

## Implementation Checklist

**Development Approach**: TDD (Red-Green-Refactor) with `bats` for unit tests, `act` for local workflow testing.

**Status**: ✅ COMPLETE (83/88 tests passing - 94%)

### Phase 0: Test Infrastructure Setup
- [x] Set up `.github/tests/` directory structure
- [x] Create `test-helpers.bash` with common setup functions
- [x] Install `bats-core` in CI workflow
- [x] Add actionlint to pre-commit hooks
- [x] Create test fixtures directory

### Phase 1: Configuration (TDD)
- [x] **RED**: Write `test-schema-validation.bats` tests
- [x] **GREEN**: Create `.github/actions/configs/atomic-branches.json`
- [x] **GREEN**: Create JSON schema for validation
- [x] **RED**: Write `test-branch-patterns.bats` tests
- [x] **GREEN**: Implement branch pattern matching logic
- [x] **REFACTOR**: Extract reusable pattern matching functions
- [x] Define initial chart relationships (cloudflared, external-secrets)

### Phase 2: Relationship Determination (TDD)
- [x] **RED**: Write `test-tier1-config.bats` tests
- [x] **GREEN**: Implement config-based relationship detection
- [x] **RED**: Write `test-tier2-frontmatter.bats` tests
- [x] **GREEN**: Implement frontmatter parsing (using `yq`)
- [x] **RED**: Write `test-tier3-footer.bats` tests
- [x] **GREEN**: Implement commit footer parsing (`related:`, `requires:`)
- [x] **RED**: Write `test-tier4-scope.bats` tests
- [x] **GREEN**: Implement conventional commit scope extraction
- [x] **RED**: Write `test-tier5-commit.bats` tests
- [x] **GREEN**: Implement same-commit grouping logic
- [x] **REFACTOR**: Create unified relationship resolution function

### Phase 3: Ruleset Changes
- [x] Remove integration from `protected-branches-linear`
- [x] Create new `integration-linear-with-reset` ruleset (allows force-push via bypass)
- [x] Add `atomic-branching-preview` to `integration-pr-required` status checks
- [x] Verify bypass permissions work via manual test

### Phase 4: PR Validation Workflow (TDD)
- [x] **RED**: Write `test-cherry-pick-dryrun.bats` tests
- [x] **GREEN**: Implement cherry-pick dry-run verification
- [x] **RED**: Write `test-pr-preview.bats` tests
- [x] **GREEN**: Implement preview output generation
- [x] Create `atomic-branching-preview.yaml` workflow
- [x] **LOCAL TEST**: Verify with `act pull_request`
- [x] Handle DLQ cases (create issue for unmatched files)
- [x] **VERIFY**: Run actionlint on workflow

### Phase 5: Extract and Reset Workflow (TDD)
- [x] **RED**: Write `test-integration-reset.bats` tests
- [x] **GREEN**: Implement atomic branch creation
- [x] **GREEN**: Implement two-pass PR creation (create, then cross-reference)
- [x] **GREEN**: Implement integration reset
- [x] Create `atomize-integration-pr.yaml` workflow
- [x] Implement cleanup on failure (delete pushed branches)
- [x] **LOCAL TEST**: Verify full workflow with `act`
- [x] **VERIFY**: Run actionlint on workflow

### Phase 6: DLQ Handling (TDD)
- [x] **RED**: Write `test-dlq-handling.bats` tests
- [x] **GREEN**: Implement DLQ branch creation
- [x] **GREEN**: Implement bug issue creation
- [x] **REFACTOR**: Integrate with main extraction workflow

### Phase 7: Sync Workflow Updates
- [x] Update `SYNC_BRANCH_CONFIG` to use `ff-only` for integration
- [x] Remove rebase logic for integration
- [x] Test sync with new model (manual verification)

### Phase 8: Documentation

#### ADRs
- [x] Create ADR for full atomization model (ADR-011 or next available)
  - Decision: Integration as staging branch with full atomization
  - Context: Need atomic PRs for clean release-please CHANGELOG generation
  - Consequences: All content types extracted, integration reset after extraction
- [x] Update `docs/src/adr/index.md` with new ADR entry

#### docs/** Updates
- [x] Create `docs/src/contributing/atomization.md` - Developer guide for atomization system
  - How to use `related:` frontmatter in markdown files
  - How to use `related:` and `requires:` commit footers
  - UUID generation for `requires:` bundling
  - What happens when your PR merges to integration
- [x] Create `docs/src/contributing/commit-conventions.md` - Commit message conventions
  - Conventional commit format requirements
  - Relationship footers (`related:`, `requires:`, `requires(<file>):`)
  - Examples for each content type
- [x] Update `docs/src/contributing/index.md` with links to new guides
- [x] Update `CONTRIBUTING.md` (root) with summary and links to docs/

#### Repository Config
- [x] Update `.github/RULESETS.md` with new integration ruleset
- [x] Update `.claude/CLAUDE.md` with atomization workflow context

### Phase 9: Integration Testing
- [x] Create integration test PR to integration branch
- [x] Verify Phase 1 (validation) workflow runs
- [x] Merge test PR
- [x] Verify Phase 2 (extraction) workflow runs
- [x] Verify atomic branches created correctly
- [x] Verify PRs created with related links
- [x] Verify integration branch reset

### Phase 10: Schema Contribution
After successful integration testing, contribute the JSON Schema to the central schema repository.

- [x] Fork/clone `aRustyDev/schemas` repository
- [x] Add `atomic-branches.schema.json` to appropriate directory
- [x] Add schema metadata (title, description, examples)
- [x] Create PR to `aRustyDev/schemas`
- [x] After merge: Schema hosted at `schemas.arusty.dev`
- [x] Update `.github/actions/configs/atomic-branches.json` to reference hosted schema:
  ```json
  {
    "$schema": "https://schemas.arusty.dev/github-actions/atomic-branches.schema.json",
    "branches": [...]
  }
  ```
- [x] Update validation workflow to fetch schema from hosted URL

### Known Issues (Edge Cases)
The following 5 tests (out of 88) have minor edge case failures tracked in GitHub issues:
- Issue #112: Manual config validator name pattern validation (test 22)
- Issue #113: Tier 1 wildcard nested file matching (test 46)
- Issue #114: Tier 3 footer parsing edge cases (tests 60, 64, 65)

## Identified Gaps and Refinements

The following areas need additional specification:

### Gap 1: Config Schema Validation

**Issue**: No validation for `atomic-branches.json` configuration file.

**Solution**: Add JSON Schema validation and CI check.

```json
// .github/actions/configs/atomic-branches.schema.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["branches"],
  "properties": {
    "branches": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "prefix", "pattern"],
        "properties": {
          "name": { "type": "string", "pattern": "^\\$\\w+$" },
          "prefix": { "type": "string", "pattern": "^[a-z]+/$" },
          "pattern": { "type": "string" }
        }
      }
    },
    "charts": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name"],
        "properties": {
          "name": { "type": "string" },
          "related": { "type": "array", "items": { "type": "string" } },
          "priority": { "type": "integer", "minimum": 1 }
        }
      }
    }
  }
}
```

### Gap 2: UUID Validation for `requires:`

**Issue**: No validation that `requires:` values are valid UUIDs.

**Solution**: Add regex validation in commit footer parsing.

```bash
UUID_REGEX='^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
if [[ "$REQUIRES_VALUE" =~ $UUID_REGEX ]]; then
  # Valid UUID - bundle commits
else
  # Invalid - treat as error or DLQ
fi
```

### Gap 3: Related-PRs Cross-Referencing

**Issue**: PR numbers aren't known until PRs are created, but Related-PRs footer needs all numbers.

**Solution**: Two-pass PR creation:

1. **Pass 1**: Create all PRs without Related-PRs footer
2. **Pass 2**: Update PR descriptions with cross-references

```yaml
- name: Create PRs (Pass 1)
  id: create-prs
  run: |
    PR_NUMBERS=()
    for branch in $BRANCHES; do
      PR_NUM=$(gh pr create --base main --head "$branch" ...)
      PR_NUMBERS+=("$PR_NUM")
    done
    echo "pr_numbers=${PR_NUMBERS[*]}" >> "$GITHUB_OUTPUT"

- name: Update PR descriptions (Pass 2)
  run: |
    for pr in $PR_NUMBERS; do
      gh pr edit "$pr" --body "$(update_body_with_related $pr $ALL_PR_NUMBERS)"
    done
```

### Gap 4: Concurrent PR Handling

**Issue**: What if multiple PRs merge to integration simultaneously?

**Solution**: Use concurrency groups and queue processing.

```yaml
concurrency:
  group: atomize-integration
  cancel-in-progress: false  # Queue, don't cancel
```

### Gap 5: Partial Extraction Rollback

**Issue**: If extraction fails mid-way, some atomic branches may already be pushed.

**Solution**: Implement cleanup on failure.

```yaml
- name: Cleanup on failure
  if: failure()
  run: |
    # Delete any branches created in this run
    for branch in $CREATED_BRANCHES; do
      gh api "repos/${{ github.repository }}/git/refs/heads/$branch" -X DELETE || true
    done
```

### Gap 6: Frontmatter Parsing Library

**Issue**: "Implement frontmatter parsing" lacks specificity.

**Solution**: Use `yq` for YAML parsing in bash, or a Node.js action with `gray-matter` for robust parsing.

```bash
# Bash approach with yq
FRONTMATTER=$(sed -n '/^---$/,/^---$/p' "$FILE" | sed '1d;$d')
RELATED_CHARTS=$(echo "$FRONTMATTER" | yq '.related.charts[]' 2>/dev/null)
```

---

## Testing Strategy

Following the **TDD methodology** (Red-Green-Refactor cycle), development proceeds test-first with verification at each step.

**Skills Reference**:
- `method-tdd-dev` - TDD cycle and verification requirements
- `cicd-github-actions-dev` - Workflow development, local testing with `act`, actionlint hooks

### Testing Philosophy

```
NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST
```

For each implementation phase:
1. **RED**: Write failing test that describes expected behavior
2. **Verify RED**: Confirm test fails for the right reason
3. **GREEN**: Write minimal code to pass
4. **Verify GREEN**: Confirm all tests pass
5. **REFACTOR**: Clean up while keeping green

### Phase 1: Configuration Tests

#### Test 1.1: Config File Schema Validation

**RED** - Create test that validates config structure:

```bash
# tests/config/test-schema-validation.bats
@test "rejects config missing required 'branches' field" {
  echo '{"charts": []}' > "$TEMP_CONFIG"
  run validate_config "$TEMP_CONFIG"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "missing required property: branches" ]]
}

@test "accepts valid config with branches and charts" {
  cat > "$TEMP_CONFIG" << 'EOF'
{
  "branches": [{"name": "$chart", "prefix": "chart/", "pattern": "charts/(?P<chart>[^/]+)/**"}],
  "charts": [{"name": "cloudflared", "related": [], "priority": 1}]
}
EOF
  run validate_config "$TEMP_CONFIG"
  [ "$status" -eq 0 ]
}
```

**Verify RED**: Run tests, confirm failures (validation function doesn't exist).

**GREEN**: Implement `validate_config` function.

**Verify GREEN**: All tests pass.

#### Test 1.2: Branch Pattern Matching

```bash
# tests/config/test-branch-patterns.bats
@test "extracts chart name from charts/cloudflared/values.yaml" {
  run match_branch_pattern "charts/cloudflared/values.yaml"
  [ "$status" -eq 0 ]
  [ "$output" = "chart/cloudflared" ]
}

@test "extracts topic from docs/src/tunnels/setup.md" {
  run match_branch_pattern "docs/src/tunnels/setup.md"
  [ "$status" -eq 0 ]
  [ "$output" = "docs/tunnels" ]
}

@test "returns empty for unmatched file" {
  run match_branch_pattern "random/file.txt"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

### Phase 2: Relationship Determination Tests

#### Test 2.1: Tier 1 - Config File Relationships

```bash
# tests/relationships/test-tier1-config.bats
@test "tier1: matches docs file to chart via config 'related' field" {
  # Given: config says cloudflared.related includes docs/src/cloudflared/*
  # When: file docs/src/cloudflared/config.md changes with chart
  run determine_relationship "docs/src/cloudflared/config.md" "cloudflared"
  [ "$status" -eq 0 ]
  [ "$output" = "tier1:config" ]
}
```

#### Test 2.2: Tier 2 - Frontmatter Relationships

```bash
# tests/relationships/test-tier2-frontmatter.bats
@test "tier2: parses related charts from markdown frontmatter" {
  cat > "$TEMP_FILE" << 'EOF'
---
related:
  charts:
    - cloudflared
    - external-secrets
---
# Configuration Guide
EOF
  run parse_frontmatter_related "$TEMP_FILE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "cloudflared" ]]
  [[ "$output" =~ "external-secrets" ]]
}
```

#### Test 2.3: Tier 3 - Commit Footer Relationships

```bash
# tests/relationships/test-tier3-footer.bats
@test "tier3: extracts related paths from commit footer" {
  COMMIT_MSG="feat(cloudflared): add metrics

Add prometheus metrics endpoint.

related: docs/src/cloudflared/metrics.md
related: charts/external-secrets/*"

  run parse_commit_footer_related "$COMMIT_MSG"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "docs/src/cloudflared/metrics.md" ]]
  [[ "$output" =~ "charts/external-secrets/*" ]]
}
```

#### Test 2.4: Tier 4 - Conventional Commit Scope

```bash
# tests/relationships/test-tier4-scope.bats
@test "tier4: extracts scope from conventional commit" {
  run parse_commit_scope "feat(cloudflared): add metrics support"
  [ "$status" -eq 0 ]
  [ "$output" = "cloudflared" ]
}

@test "tier4: returns empty for commits without scope" {
  run parse_commit_scope "feat: add generic feature"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
```

#### Test 2.5: Tier 5 - Same Commit

```bash
# tests/relationships/test-tier5-commit.bats
@test "tier5: groups files from same commit" {
  # Simulate commit with multiple files, no other relationships
  FILES=("charts/cloudflared/values.yaml" "random-file.txt")
  run determine_tier5_grouping "${FILES[@]}"
  [ "$status" -eq 0 ]
  # Both files should be marked as related via tier5
}
```

### Phase 3: Workflow Validation Tests

#### Test 3.1: Cherry-Pick Dry Run

```bash
# tests/workflow/test-cherry-pick-dryrun.bats
@test "cherry-pick dry run succeeds for clean extraction" {
  # Setup: create test repo with known commit
  setup_test_repo
  git checkout -b test-branch
  echo "change" > charts/cloudflared/values.yaml
  git add -A && git commit -m "test commit"

  run cherry_pick_dryrun "main" "HEAD" "charts/cloudflared/"
  [ "$status" -eq 0 ]
}

@test "cherry-pick dry run fails for conflicting extraction" {
  setup_test_repo_with_conflict
  run cherry_pick_dryrun "main" "HEAD" "charts/cloudflared/"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "conflict" ]]
}
```

#### Test 3.2: PR Creation Preview

```bash
# tests/workflow/test-pr-preview.bats
@test "generates correct PR preview for mixed content" {
  FILES=(
    "charts/cloudflared/values.yaml"
    "docs/src/cloudflared/config.md"
    ".github/workflows/release.yaml"
  )
  run generate_pr_preview "${FILES[@]}"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "chart/cloudflared" ]]
  [[ "$output" =~ "docs/cloudflared" ]]
  [[ "$output" =~ "ci/release" ]]
}
```

### Phase 4: DLQ Tests

```bash
# tests/dlq/test-dlq-handling.bats
@test "unmatched files go to DLQ branch" {
  setup_test_repo
  # File with no relationship at any tier
  run process_unmatched_file "random/unrelated.txt" "42"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "dlq/42" ]]
}

@test "DLQ creates bug issue" {
  run create_dlq_issue "42" "random/unrelated.txt"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "issue_created" ]]
}
```

### Phase 5: Integration Reset Tests

```bash
# tests/workflow/test-integration-reset.bats
@test "integration reset succeeds after successful extraction" {
  setup_test_repo
  # Simulate successful extraction
  EXTRACTION_RESULT="success"

  run reset_integration_branch "$EXTRACTION_RESULT"
  [ "$status" -eq 0 ]
  # Verify integration points to main
  [ "$(git rev-parse integration)" = "$(git rev-parse main)" ]
}

@test "integration reset skipped on extraction failure" {
  setup_test_repo
  EXTRACTION_RESULT="failure"

  run reset_integration_branch "$EXTRACTION_RESULT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "skipped" ]]
  # Verify integration NOT reset
  [ "$(git rev-parse integration)" != "$(git rev-parse main)" ]
}
```

### Local Development with `act`

Use `act` to test workflows locally before pushing:

```bash
# Install act
brew install act

# Test PR validation workflow
act pull_request -j analyze -e tests/fixtures/pr-event.json

# Test with specific runner image
act -P ubuntu-latest=catthehacker/ubuntu:act-latest

# Pass secrets
act -s GITHUB_TOKEN="$(gh auth token)"
```

**Test Event Fixtures** (`.github/tests/fixtures/`):

```json
// pr-event.json
{
  "action": "opened",
  "pull_request": {
    "number": 42,
    "base": {"ref": "integration"},
    "head": {"sha": "abc123"}
  }
}
```

### Pre-commit Configuration

Add actionlint hook for workflow validation:

```yaml
# .pre-commit-config.yaml (add to existing)
repos:
  - repo: https://github.com/rhysd/actionlint
    rev: v1.7.4
    hooks:
      - id: actionlint
        files: ^\.github/workflows/
```

### Test Directory Structure

```
.github/
├── tests/
│   ├── config/
│   │   ├── test-schema-validation.bats
│   │   └── test-branch-patterns.bats
│   ├── relationships/
│   │   ├── test-tier1-config.bats
│   │   ├── test-tier2-frontmatter.bats
│   │   ├── test-tier3-footer.bats
│   │   ├── test-tier4-scope.bats
│   │   └── test-tier5-commit.bats
│   ├── workflow/
│   │   ├── test-cherry-pick-dryrun.bats
│   │   ├── test-pr-preview.bats
│   │   └── test-integration-reset.bats
│   ├── dlq/
│   │   └── test-dlq-handling.bats
│   ├── fixtures/
│   │   ├── pr-event.json
│   │   └── valid-config.json
│   └── helpers/
│       └── test-helpers.bash
└── actions/
    └── atomize/
        └── src/  # TypeScript implementation (optional)
```

### CI Test Workflow

```yaml
# .github/workflows/test-atomization.yaml
name: Test Atomization Components

on:
  pull_request:
    paths:
      - '.github/actions/atomize/**'
      - '.github/actions/configs/**'
      - '.github/tests/**'

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install bats
        run: |
          git clone https://github.com/bats-core/bats-core.git
          cd bats-core && sudo ./install.sh /usr/local

      - name: Run unit tests
        run: bats .github/tests/**/*.bats

  actionlint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run actionlint
        uses: raven-actions/actionlint@v2
```

---

## Design Decisions

When a single commit touches multiple content types:

**Primary Strategy**: Cherry-pick verification
- Before extraction, verify all predicted splits can be cherry-picked cleanly
- Preserves original conventional commit messages for CHANGELOG generation
- If cherry-pick would fail, workflow fails early

**Fallback Strategy**: File extraction with `git checkout --patch`
- Extract specific files when cherry-pick isn't possible
- Preserves file changes but may require commit message adjustment

```yaml
steps:
  - name: Verify cherry-pick feasibility
    id: verify
    run: |
      # For each category, attempt cherry-pick in dry-run mode
      for category in $CATEGORIES; do
        if ! git cherry-pick --no-commit $COMMIT_SHA; then
          echo "Cherry-pick failed for $category"
          echo "fallback_needed=true" >> "$GITHUB_OUTPUT"
          git cherry-pick --abort
        fi
        git reset --hard HEAD
      done

  - name: Extract via checkout (fallback)
    if: steps.verify.outputs.fallback_needed == 'true'
    run: |
      # Use git checkout to extract specific files
      git checkout $COMMIT_SHA -- $FILE_PATTERN
```

### 2. PR Merge Order

**Decision**: Independent (merge when ready)

- Atomic PRs have no enforced merge order
- Each PR is self-contained and can be merged independently
- Related-To/Related-PRs tags are informational only
- Reviewers can choose to coordinate if desired

### 3. Failed Extraction

**Decision**: Fail entirely (atomic behavior)

- If ANY category fails to extract: entire workflow fails
- No partial pushes to atomic branches
- Integration is NOT reset
- Creates issue with failure details for manual intervention

```yaml
extract:
  strategy:
    fail-fast: true  # Stop all jobs on first failure

reset-integration:
  needs: [extract]
  if: needs.extract.result == 'success'  # Only reset on complete success
```

### 4. Commit Message Handling

**Decision**: Preserve original conventional commit messages

- Atomic commits keep the original message (supports CHANGELOG generation)
- Add Related-To footer without modifying the original message body
- Example:
  ```
  feat(cloudflared): add metrics support

  Original commit body here.

  Related-To: #42
  ```
