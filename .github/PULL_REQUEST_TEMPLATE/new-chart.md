## New Chart

**Chart Name:** <!-- e.g., my-application -->
**Upstream Project:** <!-- Link to upstream repository -->
**Initial Version:** <!-- e.g., 0.1.0 -->

### Description

<!-- Describe the application and what this chart deploys -->

### Features

<!-- What features does this chart include? -->

- [ ] Deployment/StatefulSet/DaemonSet
- [ ] Service
- [ ] Ingress (optional)
- [ ] ServiceAccount
- [ ] ConfigMap/Secret management
- [ ] PersistentVolumeClaim (if stateful)
- [ ] ServiceMonitor for Prometheus (optional)
- [ ] NetworkPolicy (optional)
- [ ] PodDisruptionBudget (optional)
- [ ] HorizontalPodAutoscaler (optional)

### Documentation

- [ ] `Chart.yaml` with complete metadata
- [ ] `values.yaml` with comments for all options
- [ ] `README.md` with installation and configuration guide
- [ ] `templates/NOTES.txt` with post-install instructions
- [ ] MDBook page in `docs/src/charts/`

### Testing

- [ ] `helm lint` passes
- [ ] `helm template` renders valid manifests
- [ ] Chart installs successfully on local cluster
- [ ] Application functions correctly after deployment
- [ ] Tested with default values
- [ ] Tested with custom values

### ArtifactHub

- [ ] `artifacthub-repo.yml` annotations added (if needed)
- [ ] Chart annotations include maintainers

### Checklist

- [ ] Follows chart best practices
- [ ] No hardcoded values that should be configurable
- [ ] Resource requests/limits are configurable
- [ ] Security context is properly configured
- [ ] No secrets or sensitive data committed

Closes #<!-- issue number -->
