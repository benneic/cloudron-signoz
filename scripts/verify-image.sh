#!/usr/bin/env bash
# Verify a built Cloudron SigNoz image starts and passes health checks.
set -euo pipefail

IMAGE="${1:?usage: verify-image.sh <image>}"
NETWORK="signoz-verify-$$"
PG_NAME="signoz-pg-$$"
APP_NAME="signoz-app-$$"

cleanup() {
  docker rm -f "$APP_NAME" "$PG_NAME" >/dev/null 2>&1 || true
  docker network rm "$NETWORK" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "Checking binaries in ${IMAGE}..."
docker run --rm "${IMAGE}" sh -c '
  set -e
  command -v /opt/signoz/signoz
  command -v /usr/local/bin/signoz-otel-collector
  command -v /usr/bin/clickhouse-server
  test -x /opt/bitnami/scripts/zookeeper/run.sh
'

echo "Starting postgres sidecar and app container..."
docker network create "$NETWORK" >/dev/null
docker run -d --name "$PG_NAME" --network "$NETWORK" \
  -e POSTGRES_USER=signoz \
  -e POSTGRES_PASSWORD=signoz \
  -e POSTGRES_DB=signoz \
  postgres:14-alpine >/dev/null

for i in $(seq 1 30); do
  if docker exec "$PG_NAME" pg_isready -U signoz >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
docker exec "$PG_NAME" pg_isready -U signoz

docker run -d --name "$APP_NAME" --network "$NETWORK" \
  -p 18080:8080 \
  -e CLOUDRON_APP_DOMAIN=signoz.test \
  -e CLOUDRON_APP_ORIGIN=https://signoz.test \
  -e CLOUDRON_POSTGRESQL_URL="postgres://signoz:signoz@${PG_NAME}:5432/signoz?sslmode=disable" \
  -e CLOUDRON_MAIL_SMTP_SERVER=mail.test \
  -e CLOUDRON_MAIL_SMTP_PORT=25 \
  -e CLOUDRON_MAIL_SMTP_USERNAME=user \
  -e CLOUDRON_MAIL_SMTP_PASSWORD=pass \
  -e CLOUDRON_MAIL_FROM=alerts@signoz.test \
  "$IMAGE" >/dev/null

echo "Waiting for SigNoz health (up to 6 minutes)..."
for i in $(seq 1 72); do
  if docker exec "$APP_NAME" wget -q -O- http://127.0.0.1:8080/api/v1/health 2>/dev/null | grep -q '"status":"ok"'; then
    echo "Health check passed."
    exit 0
  fi
  sleep 5
done

echo "Health check failed. Recent logs:" >&2
docker logs "$APP_NAME" 2>&1 | tail -80 >&2
exit 1
