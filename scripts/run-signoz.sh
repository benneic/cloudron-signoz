#!/bin/bash
set -euo pipefail

if [[ -f /run/signoz/runtime.env ]]; then
  set -a
  # shellcheck source=/dev/null
  . /run/signoz/runtime.env
  set +a
fi

cd /opt/signoz
exec ./signoz server
