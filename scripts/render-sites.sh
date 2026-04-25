#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG_FILE="${1:-$ROOT_DIR/config/sites.csv}"
OUTPUT_DIR="$ROOT_DIR/generated"
NGINX_DIR="$OUTPUT_DIR/nginx/conf.d"
COMPOSE_OUT="$OUTPUT_DIR/compose.sites.yaml"
NGINX_OUT="$NGINX_DIR/nightscout.conf"
SOURCE_MODE="${NIGHTSCOUT_SOURCE_MODE:-image}"
UPSTREAM_DIR="${NIGHTSCOUT_UPSTREAM_DIR:-./upstream/cgm-remote-monitor}"

mkdir -p "$OUTPUT_DIR" "$NGINX_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  exit 1
fi

cat >"$COMPOSE_OUT" <<'EOF'
services:
EOF

cat >"$NGINX_OUT" <<'EOF'
server_tokens off;
EOF

tail -n +2 "$CONFIG_FILE" | while IFS=, read -r slug domain db_name env_file; do
  [ -n "${slug:-}" ] || continue

  if [ "$SOURCE_MODE" = "build" ]; then
    SERVICE_SOURCE=$(cat <<EOF
    build:
      context: $UPSTREAM_DIR
      dockerfile: Dockerfile
    image: \${NIGHTSCOUT_IMAGE:-multi-user-nightscout:upstream}
EOF
)
  else
    SERVICE_SOURCE=$(cat <<'EOF'
    image: ${NIGHTSCOUT_IMAGE:-nightscout/cgm-remote-monitor:latest}
EOF
)
  fi

  cat >>"$COMPOSE_OUT" <<EOF
  nightscout-$slug:
${SERVICE_SOURCE}
    container_name: \${COMPOSE_PROJECT_NAME:-multi-user-nightscout}-nightscout-$slug
    restart: unless-stopped
    depends_on:
      - mongo
    env_file:
      - $env_file
    environment:
      NODE_ENV: production
      TZ: \${TZ:-UTC}
      HOSTNAME: $domain
      PORT: 1337
      INSECURE_USE_HTTP: "true"
      MONGO_CONNECTION: mongodb://\${MONGO_ROOT_USERNAME}:\${MONGO_ROOT_PASSWORD}@mongo:\${MONGO_PORT:-27017}/$db_name?authSource=admin
      MONGODB_URI: mongodb://\${MONGO_ROOT_USERNAME}:\${MONGO_ROOT_PASSWORD}@mongo:\${MONGO_PORT:-27017}/$db_name?authSource=admin
    expose:
      - "1337"
    networks:
      - proxy-net
      - mongo-net

EOF

  cat >>"$NGINX_OUT" <<EOF
server {
    listen 80;
    server_name $domain;

    location / {
        proxy_pass http://nightscout-$slug:1337;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}

EOF
done

cat >>"$COMPOSE_OUT" <<'EOF'
networks:
  proxy-net:
    external: true
    name: ${COMPOSE_PROJECT_NAME:-multi-user-nightscout}-proxy-net
  mongo-net:
    external: true
    name: ${COMPOSE_PROJECT_NAME:-multi-user-nightscout}-mongo-net
EOF

echo "Rendered:"
echo "  $COMPOSE_OUT"
echo "  $NGINX_OUT"
echo "  source mode: $SOURCE_MODE"
