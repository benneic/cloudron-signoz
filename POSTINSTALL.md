<nosso>
## First steps

1. Open your app URL in a browser. **The first user to register becomes the org admin.**
2. Instrument apps with OpenTelemetry and send data to your Cloudron OTLP endpoints (HTTP **4318** or gRPC **4317** port bindings).
3. Configure alert notification channels under **Settings → Alert Channels** (email SMTP is pre-wired from the Sendmail addon).

## Authentication

SigNoz uses its own login (not Cloudron SSO). Optional **Google Workspace SSO** can be configured under **Settings → Organization Settings → Authenticated Domains**. SAML/OIDC require SigNoz Enterprise.

## Data and backups

- **PostgreSQL addon**: users, dashboards, org metadata.
- **Local storage**: ClickHouse telemetry (largest disk use) and app secrets.
- Enable Cloudron backups for this app — restore needs **both** postgres and localstorage to stay consistent.

## Resources

- Default memory: **6 GB**. Increase if you ingest high telemetry volume.
- Plan disk for `/app/data/clickhouse` — telemetry grows quickly.

## Docs

- Application: <https://signoz.io/docs/>
- This package: <https://github.com/benneic/cloudron-signoz>
</nosso>
