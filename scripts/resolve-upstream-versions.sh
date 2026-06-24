#!/usr/bin/env bash
# Resolve pinned component versions from upstream compose manifests.
# SigNoz v0.130+ removed deploy/docker/docker-compose.yaml; fall back to .devenv compose files.
set -euo pipefail

TAG="${1:?usage: resolve-upstream-versions.sh <vX.Y.Z>}"
TAG="${TAG#v}"
TAG="v${TAG}"

SIGNOZ_VERSION="${TAG#v}"

COMPOSE=""
for path in \
  deploy/docker/docker-compose.yaml \
  .devenv/docker/clickhouse/compose.yaml \
  .devenv/docker/signoz-otel-collector/compose.yaml
do
  url="https://raw.githubusercontent.com/SigNoz/signoz/${TAG}/${path}"
  if content="$(curl -fsSL "$url" 2>/dev/null)"; then
    COMPOSE+="${content}"$'\n'
  fi
done

if [[ -z "$COMPOSE" ]]; then
  echo "Could not fetch compose manifests for ${TAG}" >&2
  exit 1
fi

strip_v() {
  echo "${1#v}"
}

OTEL_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*signoz-otel-collector:\${OTELCOL_TAG:-\([^}]*\)}.*/\1/p' | head -1)"
if [[ -z "$OTEL_RAW" ]]; then
  OTEL_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*signoz\/signoz-otel-collector:\(v[0-9.]*\).*/\1/p' | head -1)"
fi
CH_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*clickhouse\/clickhouse-server:\([0-9.]*\).*/\1/p' | head -1)"
ZK_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*signoz\/zookeeper:\([0-9.]*\).*/\1/p' | head -1)"

OTELCOL_VERSION="$(strip_v "${OTEL_RAW:-}")"
CLICKHOUSE_VERSION="${CH_RAW:-}"
ZOOKEEPER_VERSION="${ZK_RAW:-}"

for var in OTELCOL_VERSION CLICKHOUSE_VERSION ZOOKEEPER_VERSION; do
  if [[ -z "${!var}" ]]; then
    echo "Could not parse ${var} from ${TAG} compose" >&2
    exit 1
  fi
done

echo "SIGNOZ_VERSION=${SIGNOZ_VERSION}"
echo "OTELCOL_VERSION=${OTELCOL_VERSION}"
echo "CLICKHOUSE_VERSION=${CLICKHOUSE_VERSION}"
echo "ZOOKEEPER_VERSION=${ZOOKEEPER_VERSION}"
