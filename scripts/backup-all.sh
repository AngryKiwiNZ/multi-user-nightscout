#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CONFIG_FILE="${1:-$ROOT_DIR/config/sites.csv}"
TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
BACKUP_DIR="$ROOT_DIR/backups/$TIMESTAMP"
MONGO_CONTAINER="${MONGO_CONTAINER_NAME:-shared-mongo}"
MONGO_USER="${MONGO_ROOT_USERNAME:?set MONGO_ROOT_USERNAME}"
MONGO_PASS="${MONGO_ROOT_PASSWORD:?set MONGO_ROOT_PASSWORD}"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "Missing config file: $CONFIG_FILE" >&2
  exit 1
fi

mkdir -p "$BACKUP_DIR"

tail -n +2 "$CONFIG_FILE" | while IFS=, read -r slug _ db_name _; do
  [ -n "${slug:-}" ] || continue

  echo "Backing up $slug ($db_name)"
  docker exec "$MONGO_CONTAINER" sh -lc \
    "mongodump --username '$MONGO_USER' --password '$MONGO_PASS' --authenticationDatabase admin --db '$db_name' --archive" \
    >"$BACKUP_DIR/$slug.archive"
done

echo "Backups written to $BACKUP_DIR"
