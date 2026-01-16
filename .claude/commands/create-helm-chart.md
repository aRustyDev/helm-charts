---
description: Create a helm chart progressively using worktrees, PRs, and staged development
---

# Create Helm Chart

Develop a new Helm chart through progressive stages, using git worktrees for isolation and creating PRs for each development phase.

## Prerequisites

Before starting, load the Helm chart skill for comprehensive guidance:

> Load skill: k8s-helm-charts-dev

This skill provides:
- **assets/Chart.yaml.template**: Chart metadata with kubeVersion, annotations, dependencies
- **assets/values.yaml.template**: Complete values structure including security, probes, autoscaling
- **assets/patterns/**: External service configuration patterns (database, search, messaging)
- **scripts/validate-chart.sh**: Validation script for structure, security, and best practices
- **references/chart-structure.md**: Detailed chart organization reference
- **references/chart-complexity.md**: Chart complexity classification (Simple/Standard/Complex/Operator)
- **references/research-strategy.md**: How to find existing charts and gather configuration details

## Repository Context

### Versioning
This repo uses **release-please** for automated versioning. See [ADR-006](../docs/src/adr/006-release-please-versioning.md).

- **DO NOT** manually bump chart versions
- Use **conventional commits** for automatic changelog generation
- `check-version-increment: false` in ct.yaml

### CI Testing
Charts are tested with **chart-testing**. See [ADR-007](../docs/src/adr/007-separate-ct-configs.md).

- `ct.yaml` - Lint configuration (all charts)
- `ct-install.yaml` - Install configuration (excludes external-service charts)
- `validate-maintainers: true` - Maintainer GitHub usernames must be valid

---

## Workflow

### Phase 1: Gather Information

> **Note**: Skip questions if user provides chart name and reference source in command arguments.

1. **Ask for chart name** (if not provided) using AskUserQuestion:
   - Validate: lowercase, alphanumeric with hyphens, max 63 chars
   - Check if chart already exists in `charts/` directory

2. **Ask for reference source** (if not provided):
   - Path to existing docker-compose.yml (preferred)
   - Existing Kubernetes manifests
   - **Documentation URLs** (will research and extract config)
   - Start from scratch (basic template)

3. **Ask for chart type** (defaults to `application`):
   - `application` - Deployable application
   - `library` - Reusable chart templates

**If documentation URLs provided**, research using WebFetch/firecrawl to extract:

| Information | Example |
|-------------|---------|
| Docker image name/tag | `thatdot/quine:1.10.0` |
| Default ports | Web UI: 8080, Metrics: 9090 |
| Environment variables | `JAVA_OPTS`, `LOG_LEVEL` |
| Health check endpoints | `/health`, `/api/v1/admin/status` |
| Resource recommendations | 8-32 cores, 16-20 GB RAM |
| Persistence requirements | Data directory, database connection |

### Phase 1.5: Research Existing Solutions

Before creating from scratch, check if the project maintains an official chart:

1. **Check for official Helm chart** in project's GitHub or Artifact Hub
2. **If exists**: Review their patterns, decide whether to adapt or create new
3. **If documentation scraping fails**: Use alternative research methods

> **Details**: See skill's `references/research-strategy.md` for commands, fallback strategies, and information gathering checklist.

**Quick checks:**
```bash
# Search GitHub for existing charts
gh search repos "<project> helm" --owner <org>

# Search Artifact Hub
curl -s "https://artifacthub.io/api/v1/packages/search?ts_query_web=<project>&kind=0" | jq '.packages[].name'
```

### Phase 2: Setup Git Worktree

1. **Ensure `.worktrees/` is in `.gitignore`**:
   ```bash
   grep -q "^.worktrees/$" .gitignore || echo ".worktrees/" >> .gitignore
   ```

2. **Fetch latest main**:
   ```bash
   git fetch origin main
   ```

3. **Create feature branch in worktree**:
   ```bash
   git worktree add .worktrees/<chart-name>-mvp -b feat/chart-<chart-name>-mvp origin/main
   cd .worktrees/<chart-name>-mvp
   ```

### Phase 2.5: Analyze Existing Patterns

Before creating templates, examine existing charts for consistency:

```bash
# Check comment style (should use # --)
head -20 charts/*/values.yaml | grep -E "^# --"

# Check common blocks present in existing charts
for block in resources securityContext serviceAccount podSecurityContext; do
  echo "=== $block ==="
  grep -l "$block:" charts/*/values.yaml | wc -l
done

# Check ArtifactHub annotations
grep "artifacthub.io" charts/*/Chart.yaml | head -10
```

**Consistency Checklist:**
- [ ] Using `# --` helm-docs comment prefix
- [ ] Including `resources: {}` block (even if empty)
- [ ] ArtifactHub annotations in Chart.yaml
- [ ] Maintainer has valid GitHub username
- [ ] Using skill templates as base structure

**For charts requiring external services**, use skill pattern templates:
- Database (MySQL/PostgreSQL): `assets/patterns/external-database.yaml`
- Search (Elasticsearch/OpenSearch): `assets/patterns/external-search.yaml`
- Messaging (Airflow/Kafka): `assets/patterns/external-messaging.yaml` *(Phase 3)*

### Phase 3: MVP Chart Creation (Stage 1)

Create the minimum viable chart using skill templates as reference.

**Determine chart complexity** (see skill's `references/chart-complexity.md`):

| Complexity | Characteristics | CI Handling |
|------------|-----------------|-------------|
| Simple | No external deps | Full lint + install |
| Standard | Optional deps (subcharts) | Full lint + install |
| Complex | External services required | Lint only, add to `ct-install.yaml` |
| Operator | Deploys CRDs | Special handling |

> **Complex charts** (requiring external databases, search, etc.) must be added to `ct-install.yaml` exclusions.

**Required structure:**
```
charts/<chart-name>/
├── Chart.yaml              # With ArtifactHub annotations
├── values.yaml             # With helm-docs comments
├── templates/
│   ├── _helpers.tpl        # Standard helpers
│   ├── NOTES.txt           # Post-install guidance
│   ├── deployment.yaml     # With resources block
│   └── service.yaml
└── README.md
```

**Chart.yaml requirements** (based on skill template):
- `apiVersion: v2`
- `name`, `version`, `appVersion`
- `description`, `type: application`
- `keywords`, `home`, `sources`
- `maintainers` with valid GitHub username
- `annotations` with artifacthub.io entries

**values.yaml requirements**:
- All values use `# --` helm-docs comment prefix
- `image:` block with repository, tag, pullPolicy
- `service:` block with type, port
- `resources: {}` (empty but present for future)
- `nodeSelector: {}`, `tolerations: []`, `affinity: {}`
- Application-specific configuration section

**If docker-compose provided**:
- Extract image name and tag
- Map ports to service/container ports
- Convert environment variables to values.yaml
- Ignore volumes, networks, depends_on for MVP

**MVP scope constraints**:
- Single Deployment (1 replica)
- Single Service (ClusterIP)
- NOTES.txt with access instructions
- No ingress, no HPA, no PDB, no security context (MVP)

### Phase 3.5: Validate MVP

**Basic validation:**
```bash
helm lint charts/<chart-name>
helm template test-release charts/<chart-name>
```

**Enhanced validation** (using skill script):
```bash
# Run validation script from skill
bash ~/.claude/skills/k8s-helm-charts-dev/scripts/validate-chart.sh charts/<chart-name>
```

The validation script checks:
1. Chart structure (Chart.yaml, values.yaml, templates/)
2. Template rendering
3. Security best practices (runAsNonRoot, readOnlyRootFilesystem)
4. Resource configuration
5. Health probes
6. Dependencies (if any)

**CI simulation** (if chart-testing available):
```bash
ct lint --charts charts/<chart-name> --config ct.yaml
```

### Phase 3.6: Commit and Create PR

**Detect mode from user instructions:**
- Keywords like "local", "don't push", "no PR", "local feature-branch" → Local-only mode
- Default → Push and create PR

**Local-only mode:**
```bash
git add charts/<chart-name>
git commit -m "feat(<chart-name>): add MVP helm chart

### Added
- Chart.yaml with metadata and ArtifactHub annotations
- Deployment template with single replica
- ClusterIP Service template
- NOTES.txt with access instructions
- Default values.yaml with helm-docs comments"

# Store PR description for later
mkdir -p .claude/plans/<chart-name>-chart
# Write PR description to pull-request.md
```

**Push mode (default):**
```bash
git push -u origin feat/chart-<chart-name>-mvp
gh pr create --title "feat(<chart-name>): MVP helm chart" \
  --body-file .claude/plans/<chart-name>-chart/pull-request.md
```

### Phase 4: Progressive Enhancement PRs

After MVP PR is merged, create subsequent PRs for each enhancement. **Fix any bugs before starting new features.**

**Suggested progression** (fundamentals first):

| Stage | Branch Suffix | Scope | Priority |
|-------|---------------|-------|----------|
| 2 | `-probes` | Add liveness/readiness probes | High |
| 3 | `-resources` | Add resource defaults | High |
| 4 | `-security` | Add SecurityContext, ServiceAccount | High |
| 5 | `-configmap` | Add ConfigMap for configuration | Medium |
| 6 | `-persistence` | Add PVC for data storage | Medium |
| 7 | `-ingress` | Add optional Ingress | Medium |
| 8 | `-hpa` | Add HorizontalPodAutoscaler | Low |
| 9 | `-pdb` | Add PodDisruptionBudget | Low |
| 10 | `-monitoring` | Add ServiceMonitor, metrics | Low |

For each stage:

1. **Create new worktree from updated main**:
   ```bash
   git fetch origin main
   git worktree add .worktrees/<chart-name>-<stage> -b feat/chart-<chart-name>-<stage> origin/main
   ```

2. **Implement single feature** (reference skill templates)
3. **Test with validation script**
4. **Create PR with clear scope**
5. **Wait for merge before starting next stage**

### Phase 5: Cleanup Worktrees

After all PRs are merged:

```bash
# List worktrees
git worktree list

# Remove completed worktrees
git worktree remove .worktrees/<chart-name>-mvp
git worktree remove .worktrees/<chart-name>-<stage>

# Prune stale worktree references
git worktree prune
```

---

## Reference Tables

### Docker-Compose Translation

| Compose Field | Helm Equivalent |
|---------------|-----------------|
| `image` | `values.yaml: image.repository`, `image.tag` |
| `ports` | `values.yaml: service.port`, `containerPort` |
| `environment` | `values.yaml: env[]` or ConfigMap |
| `env_file` | ConfigMap or Secret |
| `volumes` (config) | ConfigMap mount |
| `volumes` (data) | PersistentVolumeClaim (Phase 6) |
| `healthcheck` | `livenessProbe`, `readinessProbe` (Phase 2) |
| `deploy.replicas` | `values.yaml: replicaCount` |
| `deploy.resources` | `values.yaml: resources` (Phase 3) |

### URL Documentation Research Checklist

When researching from documentation URLs, extract:

- [ ] Official Docker image name and default tag
- [ ] Required ports (web UI, API, metrics, internal)
- [ ] Required environment variables
- [ ] Optional/configurable environment variables
- [ ] Health check endpoints
- [ ] Recommended resource allocations
- [ ] Persistence/storage requirements
- [ ] Configuration file format (if any)
- [ ] Known configuration options

### CI Exclusion Guidance

If chart requires external services, add to `ct-install.yaml`:
```yaml
excluded-charts:
  - <chart-name>
```

Charts that typically need exclusion:
- Require external database (PostgreSQL, MySQL, Cassandra)
- Require external API credentials
- Require specific cloud provider resources
- Require custom CRDs not in cluster

---

## Best Practices

- **Always work in worktrees** - keeps main repo clean
- **Load skill first** - comprehensive guidance available
- **One feature per PR** - easier to review and rollback
- **Fix bugs immediately** - don't accumulate tech debt
- **MVP first** - get something working before optimizing
- **Use conventional commits** - enables automatic versioning
- **Use helm-docs comments** - `# --` prefix for all values
- **Validate with skill script** - catches security and best practice issues
- **Reference skill templates** - consistent structure across charts
