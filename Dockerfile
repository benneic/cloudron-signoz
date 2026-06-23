# Cloudron packaging for SigNoz: unified stack (ZooKeeper, ClickHouse, SigNoz, OTel collector).
# Final stage must use cloudron/base per https://docs.cloudron.io/packaging/guidelines/

ARG SIGNOZ_VERSION=0.129.0
ARG OTELCOL_VERSION=0.144.5
ARG CLICKHOUSE_VERSION=25.5.6
ARG ZOOKEEPER_VERSION=3.7.1

FROM signoz/signoz:v${SIGNOZ_VERSION} AS signoz-upstream
FROM signoz/signoz-otel-collector:v${OTELCOL_VERSION} AS otel-upstream
FROM clickhouse/clickhouse-server:${CLICKHOUSE_VERSION} AS clickhouse-upstream
FROM signoz/zookeeper:${ZOOKEEPER_VERSION} AS zookeeper-upstream

FROM cloudron/base:5.0.0@sha256:04fd70dbd8ad6149c19de39e35718e024417c3e01dc9c6637eaf4a41ec4e596c

ARG SIGNOZ_VERSION=0.129.0
ARG OTELCOL_VERSION=0.144.5
ARG CLICKHOUSE_VERSION=25.5.6
ARG ZOOKEEPER_VERSION=3.7.1

LABEL org.opencontainers.image.title="SigNoz (Cloudron)"
LABEL org.opencontainers.image.version="${SIGNOZ_VERSION}"
LABEL org.opencontainers.image.source="https://github.com/SigNoz/signoz"

RUN set -eux; \
  apt-get update; \
  apt-get install -y --no-install-recommends \
    supervisor curl wget ca-certificates procps netcat-openbsd gosu; \
  rm -rf /var/lib/apt/lists/*

# ClickHouse: copy binaries and support files from upstream image (layout varies by tag)
RUN --mount=from=clickhouse-upstream,source=/,target=/ch,readonly \
  set -eux; \
  for f in /ch/usr/bin/clickhouse /ch/usr/bin/clickhouse-server /ch/usr/bin/clickhouse-client; do \
    if [ -e "$f" ] || [ -L "$f" ]; then cp -a "$f" /usr/bin/; fi; \
  done; \
  if [ -d /ch/usr/lib/clickhouse ]; then cp -a /ch/usr/lib/clickhouse /usr/lib/; fi; \
  if [ -d /ch/usr/share/clickhouse ]; then cp -a /ch/usr/share/clickhouse /usr/share/; fi; \
  command -v clickhouse-server; \
  command -v clickhouse
COPY --from=clickhouse-upstream /entrypoint.sh /usr/local/bin/clickhouse-entrypoint.sh
RUN chmod +x /usr/local/bin/clickhouse-entrypoint.sh

# ZooKeeper (Bitnami layout; Java is bundled under /opt/bitnami/java)
COPY --from=zookeeper-upstream /opt/bitnami /opt/bitnami

# SigNoz server (community binary + UI assets)
COPY --from=signoz-upstream /root/signoz /opt/signoz/signoz
COPY --from=signoz-upstream /root/templates /opt/signoz/templates
COPY --from=signoz-upstream /etc/signoz/web /etc/signoz/web
RUN chmod +x /opt/signoz/signoz

# OTel collector + schema migrator binary
COPY --from=otel-upstream /signoz-otel-collector /usr/local/bin/signoz-otel-collector
RUN chmod +x /usr/local/bin/signoz-otel-collector

RUN mkdir -p \
  /app/code/supervisor/conf.d \
  /etc/clickhouse-server/config.d \
  /var/lib/clickhouse/user_scripts \
  /bitnami/zookeeper \
  /run/signoz \
  /run/supervisor

COPY config/clickhouse/config.xml config/clickhouse/users.xml config/clickhouse/custom-function.xml /etc/clickhouse-server/
COPY config/clickhouse/cluster.xml /etc/clickhouse-server/config.d/cluster.xml
COPY config/clickhouse/user_scripts/ /var/lib/clickhouse/user_scripts/
COPY config/otel-collector-config.yaml config/otel-collector-opamp-config.yaml /app/code/config/
COPY start.sh /app/code/start.sh
COPY scripts/ /app/code/scripts/
COPY supervisor/ /app/code/supervisor/
RUN chmod +x /app/code/start.sh /app/code/scripts/*.sh

EXPOSE 8080 4317 4318

CMD ["/app/code/start.sh"]
