#!/usr/bin/env bash
# Resolve pinned component versions from upstream deploy/docker/docker-compose.yaml
set -euo pipefail

TAG="${1:?usage: resolve-upstream-versions.sh <vX.Y.Z>}"
TAG="${TAG#v}"
TAG="v${TAG}"

COMPOSE="$(curl -fsSL "https://raw.githubusercontent.com/SigNoz/signoz/${TAG}/deploy/docker/docker-compose.yaml")"

strip_v() {
  echo "${1#v}"
}

SIGNOZ_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*signoz\/signoz:\${VERSION:-\([^}]*\)}.*/\1/p' | head -1)"
OTEL_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*signoz-otel-collector:\${OTELCOL_TAG:-\([^}]*\)}.*/\1/p' | head -1)"
CH_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*clickhouse\/clickhouse-server:\([0-9.]*\).*/\1/p' | head -1)"
ZK_RAW="$(printf '%s\n' "$COMPOSE" | sed -n 's/.*signoz\/zookeeper:\([0-9.]*\).*/\1/p' | head -1)"

SIGNOZ_VERSION="$(strip_v "${SIGNOZ_RAW:-}")"
OTELCOL_VERSION="$(strip_v "${OTEL_RAW:-}")"
CLICKHOUSE_VERSION="${CH_RAW:-}"
ZOOKEEPER_VERSION="${ZK_RAW:-}"

for var in SIGNOZ_VERSION OTELCOL_VERSION CLICKHOUSE_VERSION ZOOKEEPER_VERSION; do
  if [[ -z "${!var}" ]]; then
    echo "Could not parse ${var} from ${TAG} compose" >&2
    exit 1
  fi
done

echo "SIGNOZ_VERSION=${SIGNOZ_VERSION}"
echo "OTELCOL_VERSION=${OTELCOL_VERSION}"
echo "CLICKHOUSE_VERSION=${CLICKHOUSE_VERSION}"
echo "ZOOKEEPER_VERSION=${ZOOKEEPER_VERSION}"
