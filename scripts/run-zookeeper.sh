#!/bin/bash
set -euo pipefail

export BITNAMI_APP_NAME=zookeeper
export JAVA_HOME="${JAVA_HOME:-/opt/bitnami/java}"
export PATH="/opt/bitnami/common/bin:/opt/bitnami/java/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export ZOO_SERVER_ID="${ZOO_SERVER_ID:-1}"
export ALLOW_ANONYMOUS_LOGIN="${ALLOW_ANONYMOUS_LOGIN:-yes}"
export ZOO_AUTOPURGE_INTERVAL="${ZOO_AUTOPURGE_INTERVAL:-1}"
export ZOO_ENABLE_PROMETHEUS_METRICS="${ZOO_ENABLE_PROMETHEUS_METRICS:-yes}"
export ZOO_PROMETHEUS_METRICS_PORT_NUMBER="${ZOO_PROMETHEUS_METRICS_PORT_NUMBER:-9141}"

exec /opt/bitnami/scripts/zookeeper/entrypoint.sh /opt/bitnami/scripts/zookeeper/run.sh
