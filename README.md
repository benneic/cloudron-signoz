# SigNoz for Cloudron

Unofficial [Cloudron](https://www.cloudron.io/) packaging for [SigNoz](https://github.com/SigNoz/signoz) — an OpenTelemetry-native observability platform (traces, metrics, logs, dashboards, and alerting).

**This repository** does not fork SigNoz. The container image bundles official upstream binaries (SigNoz server, OTel collector, ClickHouse, ZooKeeper) on top of `cloudron/base:5.0.0`, with a `start.sh` that maps [Cloudron addon](https://docs.cloudron.io/packaging/addons/) environment variables and orchestrates all services via supervisor.

## What you get

| Layer | Role |
|--------|------|
| **PostgreSQL** (addon) | Metadata: users, dashboards, org settings. |
| **Sendmail** (addon) | Outbound SMTP for alert email notifications. |
| **Local storage** (addon) | `/app/data` — ClickHouse telemetry, ZooKeeper state, JWT secrets. |
| **TCP ports** | OTLP gRPC **4317** and HTTP **4318** for telemetry ingestion. |

Default memory limit: **6 GB**. SigNoz upstream requires at least 4 GB; 6 GB is the manifest default for typical self-hosted use.

## Install

### End users (recommended):

The package is published through a version catalog file:

```bash
https://raw.githubusercontent.com/benneic/cloudron-signoz/main/CloudronVersions.json
```

Choose one install path:

1. **Cloudron dashboard (Community Apps)**
   - Open Cloudron dashboard as admin.
   - Go to **App Store** → **Community Apps**.
   - Add the catalog URL above.
   - Install **SigNoz** from the community list.

2. **Cloudron CLI**

   ```bash
   cloudron install --versions-url https://raw.githubusercontent.com/benneic/cloudron-signoz/main/CloudronVersions.json
   ```

### Maintainers / developers: build from source

1. **Clone** this repository:

   ```bash
   git clone https://github.com/benneic/cloudron-signoz.git
   cd cloudron-signoz
   ```

2. **Build the image** without pushing to a registry:

   ```bash
   cloudron build --no-push
   ```

3. **Install** on your Cloudron:

   ```bash
   cloudron install
   ```

### Update

After new commits or catalog releases:

- **Community catalog installs:** update from the Cloudron dashboard when a newer catalog version appears.
- **Local builds:** `git pull` → `cloudron build --no-push` → `cloudron update`

## First run and security

- The **first user to register** becomes the **org admin** (SigNoz’s own user database).
- This package does **not** use Cloudron `ldap`, `oidc`, or `proxyauth` addons. Optional **Google Workspace SSO** is configured inside SigNoz under **Settings → Authenticated Domains** (Community Edition). SAML/OIDC require SigNoz Enterprise.
- JWT secrets are generated once under `/app/data/config` and persist across restarts and backups.

## OTLP ingestion

Configure your instrumented applications to send telemetry to this app’s OTLP endpoints. In Cloudron, enable TCP port bindings for **4317** (gRPC) and/or **4318** (HTTP) when installing or via app location settings.

Example (HTTP): `http://your-signoz-domain:4318/v1/traces`

## Backups

Cloudron [backups](https://docs.cloudron.io/backups/) must include:

- **PostgreSQL addon** — metadata (users, dashboards, org config)
- **Local storage** — ClickHouse telemetry data and secrets

Restore both together for a consistent system.

## Automation in this repo

Fully automated release pipeline:

1. **Upstream watch (weekly / manual)** — [upstream-watch.yml](.github/workflows/upstream-watch.yml) checks [SigNoz/signoz](https://github.com/SigNoz/signoz) for a newer release. When needed it bumps component versions on `main`, builds and pushes `ghcr.io/benneic/signoz-cloudron:<ver>`, runs [scripts/verify-image.sh](scripts/verify-image.sh), commits the new entry to [CloudronVersions.json](CloudronVersions.json), and pushes tag `vX.Y.Z`. If `main` already matches upstream but the catalog entry is missing, it builds and publishes without re-bumping.
2. **Release build (manual)** — [build.yml](.github/workflows/build.yml) is for hand-cut tags or **Actions → Release build → Run workflow**. Tag pushes and `workflow_dispatch` still build and (for tag pushes) update the catalog; the weekly upstream pipeline does not depend on a second workflow run.

**Requirements:** GitHub → Settings → Actions → General → workflow permissions **Read and write**. Make the `ghcr.io/benneic/signoz-cloudron` package **public**. If `main` is branch-protected, allow `github-actions[bot]` to push.

**Manual release:**

```bash
git tag -a vX.Y.Z -m "Release SigNoz X.Y.Z for Cloudron"
git push origin vX.Y.Z
```

## GitHub repository setup

1. Create public repo `benneic/cloudron-signoz` and push this tree.
2. Settings → Actions → General → **Read and write** workflow permissions.
3. Settings → Packages → `signoz-cloudron` → **Public**.

## Troubleshooting

| Issue | What to do |
|-------|------------|
| Unhealthy in dashboard | `cloudron logs --app <fqdn> -f`; health check is `GET /api/v1/health`. Startup can take 2–3 minutes (ClickHouse + migrations). |
| High memory use | Increase app memory in Cloudron; telemetry volume drives ClickHouse RAM. |
| No alert emails | Verify Sendmail addon is provisioned; test SMTP in SigNoz **Settings → Alert Channels**. |
| Postgres errors | `cloudron exec --app <fqdn> -- printenv \| grep POSTGRES`; ensure postgres addon is healthy. |
| OTLP not receiving data | Confirm TCP port bindings 4317/4318 are enabled and reachable from clients. |

## License

- This packaging: [LICENSE](LICENSE) (MIT).
- [SigNoz](https://github.com/SigNoz/signoz) upstream: [MIT](https://github.com/SigNoz/signoz/blob/main/LICENSE).
