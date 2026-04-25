#!/usr/bin/env sh
set -eu

if [ "$#" -lt 2 ] || [ "$#" -gt 4 ]; then
  echo "Usage: $0 <slug> <domain> [db_name] [env_file]" >&2
  exit 1
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SLUG=$1
DOMAIN=$2
DB_NAME=${3:-ns_$SLUG}
ENV_FILE=${4:-sites/$SLUG.env}
CONFIG_FILE="$ROOT_DIR/config/sites.csv"
EXAMPLE_ENV="$ROOT_DIR/sites/jay.env.example"
TARGET_ENV="$ROOT_DIR/$ENV_FILE"

mkdir -p "$ROOT_DIR/config" "$(dirname "$TARGET_ENV")"

if [ ! -f "$CONFIG_FILE" ]; then
  printf '%s\n' 'slug,domain,db_name,env_file' >"$CONFIG_FILE"
fi

if tail -n +2 "$CONFIG_FILE" | cut -d, -f1 | grep -Fx "$SLUG" >/dev/null 2>&1; then
  echo "Site slug already exists in $CONFIG_FILE: $SLUG" >&2
  exit 1
fi

printf '%s,%s,%s,%s\n' "$SLUG" "$DOMAIN" "$DB_NAME" "$ENV_FILE" >>"$CONFIG_FILE"

if [ ! -f "$TARGET_ENV" ]; then
  cp "$EXAMPLE_ENV" "$TARGET_ENV"
fi

"$ROOT_DIR/scripts/render-sites.sh"

cat <<EOF
New site added.

Site:
  slug: $SLUG
  domain: $DOMAIN
  database: $DB_NAME
  env file: $ENV_FILE

Next steps:
  1. Edit $ENV_FILE and set at least API_SECRET.
  2. Start or reload the stack:
     docker compose -f compose.yaml -f generated/compose.sites.yaml up -d
EOF
