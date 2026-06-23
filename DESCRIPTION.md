# SigNoz for Cloudron

[SigNoz](https://signoz.io/) is an open source OpenTelemetry-native observability platform: traces, metrics, logs, dashboards, and alerting in one place. This package runs the **Community Edition** stack (ZooKeeper, ClickHouse, SigNoz server, OTel collector) in a single Cloudron app container.

**What you get**

- **Telemetry storage**: embedded ClickHouse and ZooKeeper on [local storage](https://docs.cloudron.io/packaging/addons/) (`/app/data`).
- **Metadata**: Cloudron [PostgreSQL](https://docs.cloudron.io/packaging/addons/) for users, dashboards, and org settings.
- **Alert email**: [Sendmail](https://docs.cloudron.io/packaging/addons/) addon mapped to SigNoz Alertmanager SMTP settings.
- **OTLP ingestion**: expose ports **4317** (gRPC) and **4318** (HTTP) via Cloudron TCP port bindings for instrumented apps.

**Relationship to upstream**

This is *unofficial* packaging. Application binaries come from official [SigNoz/signoz](https://github.com/SigNoz/signoz) Docker images; this repository adds Cloudron base, orchestration, and manifest. Report product bugs to SigNoz; report packaging issues to this repo’s issue tracker.

**Licensing**

SigNoz Community Edition is open source ([MIT](https://github.com/SigNoz/signoz/blob/main/LICENSE)). Enterprise-only features (SAML/OIDC SSO, etc.) are per upstream.
