# Changelog

## [0.1.0](https://github.com/aRustyDev/helm-charts/releases/tag/cloudflared-v0.1.0) (2024-01-14)

### Features

* Initial release of cloudflared Helm chart
* External Secrets Operator integration for managing tunnel credentials
* Linkerd service mesh support with automatic proxy injection for mTLS
* Prometheus monitoring with ServiceMonitor and PodMonitor resources
* Configurable liveness and readiness probes
* NetworkPolicy support for network segmentation
* Extensibility via extraEnv, extraVolumes, and extraVolumeMounts
* Metrics service for service discovery

### Based On

* community-charts/cloudflared v2.2.4
