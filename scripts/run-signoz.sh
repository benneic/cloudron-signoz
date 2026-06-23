#!/bin/bash
set -euo pipefail

if [[ -f /run/signoz/runtime.env ]]; then
  set -a
  # shellcheck source=/dev/null
  . /run/signoz/runtime.env
  set +a
fi

# Prometheus active-query log (queries.active) must live on writable localstorage
mkdir -p /app/data/signoz
cd /app/data/signoz
exec /opt/signoz/signoz server
