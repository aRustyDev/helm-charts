# ADR-007: Separate Chart-Testing Configs for Lint vs Install

**Status:** Accepted
**Date:** 2025-01-14

## Context

Some Helm charts require external services (e.g., Cloudflare API, AWS credentials, databases) to run successfully. While these charts can be linted to verify template syntax and structure, they cannot be installed in CI without real credentials because the application validates credentials at runtime.

## Decision

Maintain two chart-testing configuration files:
- `ct.yaml` - Used for linting all charts
- `ct-install.yaml` - Used for install tests, with `excluded-charts` for charts requiring external services

## Rationale

1. **Lint Everything**: All charts should pass `helm lint` regardless of external dependencies. Linting catches template syntax errors, missing required values, and schema violations.

2. **Install What We Can**: Charts that can run with dummy values (or no external dependencies) should be install-tested to verify they deploy correctly to a Kubernetes cluster.

3. **Explicit Exclusions**: Charts requiring external services are explicitly listed with documented reasons, making it clear why they're excluded rather than silently skipping them.

## Configuration

```yaml
# ct-install.yaml
excluded-charts:
  - cloudflared  # Requires real Cloudflare tunnel credentials
```

```yaml
# .github/workflows/lint-test.yaml
- name: Run chart-testing (lint)
  run: ct lint --config ct.yaml

- name: Run chart-testing (install)
  run: ct install --config ct-install.yaml
```

## Consequences

### Positive
- All charts are linted for syntax/structure errors
- Charts that can be tested are tested
- Clear documentation of why specific charts are excluded
- CI passes for charts that genuinely cannot run without external services

### Negative
- Install tests don't cover all charts
- Excluded charts may have deployment issues not caught until production
- Must remember to add charts to exclusion list when they require external services

## Alternatives Considered

### Single ct.yaml with excluded-charts for both lint and install
Rejected because we want to lint ALL charts, even those that can't be installed.

### Mock services in CI
Rejected because it adds complexity and mock behavior may not match real service behavior.

### Skip install tests entirely
Rejected because install tests catch real deployment issues that linting misses.
