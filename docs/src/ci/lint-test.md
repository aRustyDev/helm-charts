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

**Matrix:** Tests against Kubernetes v1.28, v1.29, v1.30

**Steps:**
1. **List Changed** - Detect which charts changed (unless `test_all` is true)
2. **Lint** - Run `ct lint` which includes:
   - `helm lint`
   - Chart version increment check
   - YAML validation
   - Maintainer validation
3. **Install Test** - Create kind cluster and install charts

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

Chart-testing uses `ct.yaml` for configuration:

```yaml
chart-dirs:
  - charts
target-branch: main
helm-extra-args: --timeout 600s
```
