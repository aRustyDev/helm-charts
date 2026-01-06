# Lint and Test Workflow

**File:** `.github/workflows/lint-test.yaml`

**Triggers:**
- Pull requests
- Manual dispatch (with option to test all charts)

## Jobs

### `artifacthub-lint`

Validates ArtifactHub metadata for all charts.

```bash
ah lint --kind helm charts/<chart>/
```

Checks:
- `artifacthub-repo.yml` in repository root
- Chart annotations for ArtifactHub
- Metadata completeness

### `lint-test`

Uses [chart-testing](https://github.com/helm/chart-testing) to validate charts.

**Matrix:** Tests against Kubernetes v1.32, v1.33, v1.34 (SHA-pinned images)

**Job Names:** `lint-test (v1.32.11)`, `lint-test (v1.33.7)`, `lint-test (v1.34.3)` - used by required status checks

**Steps:**
1. **List Changed** - Detect which charts changed (unless `test_all` is true)
2. **Lint** - Run `ct lint` which includes:
   - `helm lint`
   - YAML validation
   - Maintainer validation (disabled)
3. **Install Test** - Create kind cluster and install charts

**Note:** Version increment checking is disabled (`check-version-increment: false`). Version bumps are handled by [release-please](./release-please.md) based on conventional commits.

**Release-Please PRs:** Tests are skipped for release-please PRs (branches starting with `release-please--`) since they only contain version bumps and changelog updates that were already tested in the originating PR. Placeholder jobs report success to satisfy required status checks.

## Manual Testing

To test all charts regardless of changes:

```bash
gh workflow run lint-test.yaml -f test_all=true
```

## Local Testing

```bash
# Install chart-testing
brew install chart-testing

# Lint charts
ct lint --all

# With kind cluster
kind create cluster
ct install --all
```

## Configuration

Chart-testing uses `ct.yaml` for configuration (explicitly passed via `--config ct.yaml`):

```yaml
chart-dirs:
  - charts
target-branch: main
helm-extra-args: --timeout 600s
validate-maintainers: false
check-version-increment: false  # release-please handles versioning
```
