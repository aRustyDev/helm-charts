# holmes (OLM)

Helm chart for deploying the Operator Lifecycle Manager (OLM) in Kubernetes.

## Overview

OLM extends Kubernetes to provide a declarative way to install, manage, and upgrade Operators on a cluster. This chart packages the official OLM components for easy deployment.

## Installation

```bash
# From Helm repository
helm install olm arustydev/holmes

# From OCI registry
helm install olm oci://ghcr.io/arustydev/charts/holmes

# With custom values
helm install olm arustydev/holmes -f values.yaml
```

## Prerequisites

- Kubernetes 1.11.0+
- Helm 3.8+
- Cluster admin privileges (OLM requires cluster-wide CRDs)

## Components

The chart deploys:

| Component | Description |
|-----------|-------------|
| OLM Operator | Manages operator installations |
| Catalog Operator | Resolves operator dependencies |
| Package Server | Serves operator package information |
| Upstream Operators CatalogSource | Default catalog of operators |

## Configuration

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `olm.namespace` | Namespace for OLM components | `olm` |
| `operators.namespace` | Namespace for installed operators | `operators` |
| `olmOperator.replicas` | OLM operator replicas | `1` |
| `catalogOperator.replicas` | Catalog operator replicas | `1` |
| `packageServer.replicas` | Package server replicas | `2` |

### Example values.yaml

```yaml
olm:
  namespace: olm

operators:
  namespace: operators

olmOperator:
  replicas: 1
  resources:
    requests:
      cpu: 10m
      memory: 160Mi

packageServer:
  replicas: 2
```

## CRDs

This chart installs the following CRDs:

- `catalogsources.operators.coreos.com`
- `clusterserviceversions.operators.coreos.com`
- `installplans.operators.coreos.com`
- `olmconfigs.operators.coreos.com`
- `operatorconditions.operators.coreos.com`
- `operatorgroups.operators.coreos.com`
- `operators.operators.coreos.com`
- `subscriptions.operators.coreos.com`

## Usage After Installation

```bash
# View available operators
kubectl get packagemanifests

# Install an operator via subscription
kubectl apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: my-operator
  namespace: operators
spec:
  channel: stable
  name: my-operator
  source: operatorhubio-catalog
  sourceNamespace: olm
EOF
```

## Uninstallation

```bash
helm uninstall olm

# CRDs are not removed by default
# To remove CRDs (will delete all operator data):
kubectl delete crd -l operators.coreos.com/
```

## Troubleshooting

### OLM operator not starting

Check pod logs:
```bash
kubectl logs -n olm -l app=olm-operator
```

### Package server unavailable

Verify package server pods:
```bash
kubectl get pods -n olm -l app=packageserver
```

## Links

- [OLM Documentation](https://olm.operatorframework.io/)
- [OperatorHub.io](https://operatorhub.io/)
- [Chart Source](https://github.com/aRustyDev/helm-charts/tree/main/charts/olm)
