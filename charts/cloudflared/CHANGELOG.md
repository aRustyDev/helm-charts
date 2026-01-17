# Changelog

## [0.5.0](https://github.com/aRustyDev/helm-charts/compare/cloudflared-v0.4.0...cloudflared-v0.5.0) (2026-01-17)


### Features

* **cloudflared:** add ztna keyword for discoverability ([#46](https://github.com/aRustyDev/helm-charts/issues/46)) ([c9d11ba](https://github.com/aRustyDev/helm-charts/commit/c9d11ba00525354c3ccc99069bccb68e71c56956))


### Bug Fixes

* **cloudflared:** update chart source links to this repository ([#61](https://github.com/aRustyDev/helm-charts/issues/61)) ([c8e90ba](https://github.com/aRustyDev/helm-charts/commit/c8e90ba30223d3576ec164a05d21f06c9f659807))

## [0.4.0](https://github.com/aRustyDev/helm-charts/compare/cloudflared-v0.3.0...cloudflared-v0.4.0) (2026-01-14)


### Features

* **cloudflared:** add base cloudflared helm chart (MVP) ([#35](https://github.com/aRustyDev/helm-charts/issues/35)) ([136686b](https://github.com/aRustyDev/helm-charts/commit/136686b17c5b1439d71dbb604884ef94f0a42240))
* **cloudflared:** add External Secrets Operator integration ([#37](https://github.com/aRustyDev/helm-charts/issues/37)) ([ad17042](https://github.com/aRustyDev/helm-charts/commit/ad170427bf438a719de81acb8822f3970f055304))
* **cloudflared:** add Linkerd service mesh integration ([#43](https://github.com/aRustyDev/helm-charts/issues/43)) ([47ba9dd](https://github.com/aRustyDev/helm-charts/commit/47ba9ddda9f1a9037db88277ffec6bc03aa48ded))
* **cloudflared:** add Prometheus metrics support ([#41](https://github.com/aRustyDev/helm-charts/issues/41)) ([44432d0](https://github.com/aRustyDev/helm-charts/commit/44432d0d036942282f7f4209f25f1766e11b95cc))

## [0.3.0](https://github.com/aRustyDev/helm-charts/compare/cloudflared-v0.2.0...cloudflared-v0.3.0) (2026-01-14)


### Features

* **cloudflared:** add External Secrets Operator integration ([#37](https://github.com/aRustyDev/helm-charts/issues/37)) ([ad17042](https://github.com/aRustyDev/helm-charts/commit/ad170427bf438a719de81acb8822f3970f055304))

## [0.2.0](https://github.com/aRustyDev/helm-charts/compare/cloudflared-v0.1.0...cloudflared-v0.2.0) (2026-01-14)


### Features

* **cloudflared:** add base cloudflared helm chart (MVP) ([#35](https://github.com/aRustyDev/helm-charts/issues/35)) ([136686b](https://github.com/aRustyDev/helm-charts/commit/136686b17c5b1439d71dbb604884ef94f0a42240))

## [0.1.0](https://github.com/aRustyDev/helm-charts/releases/tag/cloudflared-v0.1.0) (2024-01-14)

### Features

* Initial release of cloudflared Helm chart
* Based on community-charts/cloudflared v2.2.4
* Supports DaemonSet or Deployment modes
* Configurable tunnel settings
* Support for existing secrets or inline base64 credentials
