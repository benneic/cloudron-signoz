#!/bin/bash
set -euo pipefail

wait_for() {
  local name="$1"
  local cmd="$2"
  local tries="${3:-90}"
  local delay="${4:-2}"
  local i
  for ((i = 1; i <= tries; i++)); do
    if eval "$cmd"; then
      echo "${name} is ready"
      return 0
    fi
    echo "Waiting for ${name} (${i}/${tries})..."
    sleep "$delay"
  done
  echo "Timed out waiting for ${name}" >&2
  return 1
}

start_background() {
  local name="$1"
  shift
  echo "Starting ${name} (background init)..."
  "$@" &
  echo $! >"/run/signoz/${name}.pid"
}

stop_background() {
  local name="$1"
  local pidfile="/run/signoz/${name}.pid"
  if [[ -f "$pidfile" ]]; then
    local pid
    pid="$(cat "$pidfile")"
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    rm -f "$pidfile"
  fi
}

mkdir -p /app/data/clickhouse /app/data/zookeeper /app/data/config /run/signoz /run/supervisor
chown -R cloudron:cloudron /app/data/clickhouse /app/data/config /run/signoz /run/supervisor
# Bitnami ZooKeeper drops to UID 1001; keep data dir writable by that user
chown -R 1001:1001 /app/data/zookeeper

# Bitnami ZooKeeper expects data under /bitnami/zookeeper (persisted via localstorage)
rm -rf /bitnami/zookeeper
ln -sfn /app/data/zookeeper /bitnami/zookeeper

# Persistent ClickHouse data under localstorage
if [[ ! -L /var/lib/clickhouse ]]; then
  rm -rf /var/lib/clickhouse
  ln -sfn /app/data/clickhouse /var/lib/clickhouse
fi
chown -h cloudron:cloudron /var/lib/clickhouse
chown -R cloudron:cloudron /app/data/clickhouse

# Writable otel configs
cp /app/code/config/otel-collector-config.yaml /run/signoz/otel-collector-config.yaml
cp /app/code/config/otel-collector-opamp-config.yaml /run/signoz/otel-collector-opamp-config.yaml
chown cloudron:cloudron /run/signoz/*.yaml

# Public URL for UI links and SSO redirects
if [[ -n "${CLOUDRON_APP_ORIGIN:-}" ]]; then
  export SIGNOZ_GLOBAL_EXTERNAL__URL="${CLOUDRON_APP_ORIGIN}"
else
  export SIGNOZ_GLOBAL_EXTERNAL__URL="https://${CLOUDRON_APP_DOMAIN:-localhost}"
fi

# JWT secret (never use upstream compose default)
if [[ ! -f /app/data/config/.secrets ]]; then
  umask 077
  SIGNOZ_TOKENIZER_JWT_SECRET="$(openssl rand -hex 32)"
  {
    echo "SIGNOZ_TOKENIZER_JWT_SECRET=${SIGNOZ_TOKENIZER_JWT_SECRET}"
  } > /app/data/config/.secrets
  chown cloudron:cloudron /app/data/config/.secrets
  chmod 600 /app/data/config/.secrets
fi
set -a
# shellcheck source=/dev/null
. /app/data/config/.secrets
set +a

# PostgreSQL metadata (Cloudron addon)
export SIGNOZ_SQLSTORE_PROVIDER=postgres
export SIGNOZ_SQLSTORE_POSTGRES_DSN="${CLOUDRON_POSTGRESQL_URL:?CLOUDRON_POSTGRESQL_URL is required}"

# Sendmail → Alertmanager SMTP
if [[ -n "${CLOUDRON_MAIL_SMTPS_PORT:-}" ]]; then
  export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__SMARTHOST="${CLOUDRON_MAIL_SMTP_SERVER}:${CLOUDRON_MAIL_SMTPS_PORT}"
  export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__REQUIRE__TLS="true"
elif [[ -n "${CLOUDRON_MAIL_SMTP_PORT:-}" ]]; then
  export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__SMARTHOST="${CLOUDRON_MAIL_SMTP_SERVER}:${CLOUDRON_MAIL_SMTP_PORT}"
  if [[ "${CLOUDRON_MAIL_SMTP_PORT}" == "587" ]] || [[ "${CLOUDRON_MAIL_SMTP_PORT}" == "465" ]]; then
    export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__REQUIRE__TLS="true"
  else
    export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__REQUIRE__TLS="false"
  fi
else
  export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__SMARTHOST="${CLOUDRON_MAIL_SMTP_SERVER:?CLOUDRON_MAIL_SMTP_SERVER is required}:25"
  export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__REQUIRE__TLS="false"
fi
export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__USERNAME="${CLOUDRON_MAIL_SMTP_USERNAME:?CLOUDRON_MAIL_SMTP_USERNAME is required}"
export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__PASSWORD="${CLOUDRON_MAIL_SMTP_PASSWORD:?CLOUDRON_MAIL_SMTP_PASSWORD is required}"
export SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__FROM="${CLOUDRON_MAIL_FROM:-no-reply@${CLOUDRON_APP_DOMAIN:-localhost}}"

# Shared runtime env for supervisor-managed processes
{
  echo "SIGNOZ_ALERTMANAGER_PROVIDER=signoz"
  echo "SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN=tcp://127.0.0.1:9000"
  echo "SIGNOZ_TOKENIZER_JWT_SECRET=${SIGNOZ_TOKENIZER_JWT_SECRET}"
  echo "SIGNOZ_GLOBAL_EXTERNAL__URL=${SIGNOZ_GLOBAL_EXTERNAL__URL}"
  echo "SIGNOZ_SQLSTORE_PROVIDER=${SIGNOZ_SQLSTORE_PROVIDER}"
  echo "SIGNOZ_SQLSTORE_POSTGRES_DSN=${SIGNOZ_SQLSTORE_POSTGRES_DSN}"
  echo "SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__SMARTHOST=${SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__SMARTHOST}"
  echo "SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__USERNAME=${SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__USERNAME}"
  echo "SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__PASSWORD=${SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__AUTH__PASSWORD}"
  echo "SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__FROM=${SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__FROM}"
  echo "SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__REQUIRE__TLS=${SIGNOZ_ALERTMANAGER_SIGNOZ_GLOBAL_SMTP__REQUIRE__TLS:-false}"
  echo "OTEL_RESOURCE_ATTRIBUTES=host.name=signoz-host,os.type=linux"
  echo "LOW_CARDINAL_EXCEPTION_GROUPING=false"
  echo "SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_DSN=tcp://127.0.0.1:9000"
  echo "SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_CLUSTER=cluster"
  echo "SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_REPLICATION=true"
  echo "SIGNOZ_OTEL_COLLECTOR_TIMEOUT=10m"
} > /run/signoz/runtime.env
chmod 600 /run/signoz/runtime.env
chown cloudron:cloudron /run/signoz/runtime.env

chmod +x /app/code/scripts/run-signoz.sh /app/code/scripts/run-otel-collector.sh /app/code/scripts/run-zookeeper.sh

# --- One-shot init: ZK + ClickHouse + schema migrations ---
start_background zookeeper /app/code/scripts/run-zookeeper.sh
wait_for "ZooKeeper" "curl -sf http://127.0.0.1:8080/commands/ruok | grep -q null"

export CLICKHOUSE_SKIP_USER_SETUP=1
export CLICKHOUSE_RUN_AS_ROOT=1
export CLICKHOUSE_DO_NOT_CHOWN=1
export CLICKHOUSE_CONFIG=/etc/clickhouse-server/config.xml
start_background clickhouse /usr/local/bin/clickhouse-entrypoint.sh
wait_for "ClickHouse" "wget -q -O- http://127.0.0.1:8123/ping | grep -q Ok"

set -a
# shellcheck source=/dev/null
. /run/signoz/runtime.env
set +a

echo "Running schema migrations..."
/usr/local/bin/signoz-otel-collector migrate bootstrap
/usr/local/bin/signoz-otel-collector migrate sync up
/usr/local/bin/signoz-otel-collector migrate async up

stop_background clickhouse
stop_background zookeeper

exec /usr/bin/supervisord -c /app/code/supervisor/supervisord.conf
