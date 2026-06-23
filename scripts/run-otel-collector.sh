#!/bin/bash
set -euo pipefail

if [[ -f /run/signoz/runtime.env ]]; then
  set -a
  # shellcheck source=/dev/null
  . /run/signoz/runtime.env
  set +a
fi

/usr/local/bin/signoz-otel-collector migrate sync check
exec /usr/local/bin/signoz-otel-collector \
  --config=/run/signoz/otel-collector-config.yaml \
  --manager-config=/run/signoz/otel-collector-opamp-config.yaml \
  --copy-path=/run/signoz/collector-config.yaml
