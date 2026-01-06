---
description: Create a helm chart progressively using worktrees, PRs, and staged development
---

# Create Helm Chart

Develop a new Helm chart through progressive stages, using git worktrees for isolation and creating PRs for each development phase.

## Workflow

### Phase 1: Gather Information

1. **Ask for chart name** using AskUserQuestion:
   - Validate: lowercase, alphanumeric with hyphens, max 63 chars
   - Check if chart already exists in `charts/` directory

2. **Ask for reference source**:
   - Path to existing docker-compose.yml (preferred)
   - Existing Kubernetes manifests
   - Start from scratch (basic template)

3. **Ask for chart type**:
   - `application` (default) - Deployable application
   - `library` - Reusable chart templates

### Phase 2: Setup Git Worktree

1. **Ensure you're in the helm-charts repo**:
   ```bash
   # Verify repo
   git remote get-url origin | grep -q "aRustyDev/helm-charts"
   ```

2. **Fetch latest main**:
   ```bash
   git fetch origin main
   ```

3. **Create feature branch in worktree**:
   ```bash
   # Create worktree for this chart's development
   git worktree add ../helm-charts-<chart-name> -b feat/chart-<chart-name>-mvp origin/main
   cd ../helm-charts-<chart-name>
   ```

### Phase 3: MVP Chart Creation (Stage 1)

Create the absolute minimum viable chart:

1. **Create chart structure**:
   ```
   charts/<chart-name>/
   ├── Chart.yaml
   ├── values.yaml
   ├── templates/
   │   ├── _helpers.tpl
   │   ├── deployment.yaml
   │   └── service.yaml
   └── README.md
   ```

2. **If docker-compose provided**:
   - Extract image name and tag
   - Map ports to service/container ports
   - Convert environment variables to values.yaml
   - Ignore volumes, networks, depends_on for MVP

3. **MVP scope constraints**:
   - Single Deployment (1 replica)
   - Single Service (ClusterIP)
   - Basic container probe (if healthcheck in compose)
   - No ingress, no HPA, no PDB, no RBAC

4. **Validate MVP**:
   ```bash
   helm lint charts/<chart-name>
   helm template charts/<chart-name>
   ```

5. **Commit and create PR**:
   ```bash
   git add charts/<chart-name>
   git commit -m "feat(<chart-name>): add MVP helm chart

   ### Added
   - Basic Chart.yaml with metadata
   - Deployment template with single replica
   - ClusterIP Service template
   - Default values.yaml"

   git push -u origin feat/chart-<chart-name>-mvp
   gh pr create --title "feat(<chart-name>): MVP helm chart" \
     --body "## Summary
   - Initial MVP chart for <chart-name>
   - Single deployment + service
   - Based on: <docker-compose path or 'scratch'>

   ## Test Plan
   - [ ] \`helm lint charts/<chart-name>\`
   - [ ] \`helm template charts/<chart-name>\`
   - [ ] Deploy to test cluster (optional)"
   ```

### Phase 4: Progressive Enhancement PRs

After MVP PR is merged, create subsequent PRs for each enhancement. **Fix any bugs before starting new features.**

Suggested progression (create separate PRs for each):

| Stage | Branch Suffix | Scope |
|-------|---------------|-------|
| 2 | `-configmap` | Add ConfigMap for configuration |
| 3 | `-ingress` | Add optional Ingress |
| 4 | `-probes` | Add liveness/readiness probes |
| 5 | `-resources` | Add resource requests/limits |
| 6 | `-security` | Add SecurityContext, ServiceAccount |
| 7 | `-hpa` | Add optional HorizontalPodAutoscaler |
| 8 | `-pdb` | Add optional PodDisruptionBudget |

For each stage:

1. **Create new worktree from updated main**:
   ```bash
   git fetch origin main
   git worktree add ../helm-charts-<chart-name>-<stage> -b feat/chart-<chart-name>-<stage> origin/main
   ```

2. **Implement single feature**
3. **Test with lint and template**
4. **Create PR with clear scope**
5. **Wait for merge before starting next stage**

### Phase 5: Cleanup Worktrees

After all PRs are merged:

```bash
# List worktrees
git worktree list

# Remove completed worktrees
git worktree remove ../helm-charts-<chart-name>-mvp
git worktree remove ../helm-charts-<chart-name>-<stage>

# Prune stale worktree references
git worktree prune
```

## Docker-Compose Translation Reference

| Compose Field | Helm Equivalent |
|---------------|-----------------|
| `image` | `values.yaml: image.repository`, `image.tag` |
| `ports` | `values.yaml: service.port`, `containerPort` |
| `environment` | `values.yaml: env[]` or ConfigMap |
| `env_file` | ConfigMap or Secret |
| `volumes` (config) | ConfigMap mount |
| `volumes` (data) | PersistentVolumeClaim (later stage) |
| `healthcheck` | `livenessProbe`, `readinessProbe` |
| `deploy.replicas` | `values.yaml: replicaCount` |
| `deploy.resources` | `values.yaml: resources` |

## Notes

- **Always work in worktrees** - keeps main repo clean
- **One feature per PR** - easier to review and rollback
- **Fix bugs immediately** - don't accumulate tech debt
- **MVP first** - get something working before optimizing
- **Use conventional commits** - enables automatic versioning
