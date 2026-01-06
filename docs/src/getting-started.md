# Getting Started

## Prerequisites

- [Helm](https://helm.sh) 3.8+ installed
- Kubernetes cluster access
- `kubectl` configured for your cluster

## Installation

### Using Helm Repository

```bash
# Add the repository
helm repo add arustydev https://arustydev.github.io/helm-charts

# Update repository cache
helm repo update

# Search available charts
helm search repo arustydev

# Install a chart
helm install my-release arustydev/<chart-name>
```

### Using OCI Registry

No repository setup required:

```bash
# Install directly from GHCR
helm install my-release oci://ghcr.io/arustydev/charts/<chart-name>

# Specify version
helm install my-release oci://ghcr.io/arustydev/charts/<chart-name> --version 1.0.0
```

## Verifying Installation

```bash
# Check release status
helm status my-release

# List all releases
helm list

# Get release values
helm get values my-release
```

## Upgrading

```bash
# Update repository (if using Helm repo)
helm repo update

# Upgrade release
helm upgrade my-release arustydev/<chart-name>

# Or with custom values
helm upgrade my-release arustydev/<chart-name> -f values.yaml
```

## Uninstalling

```bash
helm uninstall my-release
```
