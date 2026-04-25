#!/usr/bin/env sh
set -eu

if [ "$#" -lt 4 ] || [ "$#" -gt 6 ]; then
  echo "Usage: $0 <slug> <domain> <old_mongo_container> <old_db_name> [new_db_name] [env_file]" >&2
  exit 1
fi

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SLUG=$1
DOMAIN=$2
OLD_MONGO_CONTAINER=$3
OLD_DB_NAME=$4
NEW_DB_NAME=${5:-ns_$SLUG}
ENV_FILE=${6:-sites/$SLUG.env}

"$ROOT_DIR/scripts/create-new-site.sh" "$SLUG" "$DOMAIN" "$NEW_DB_NAME" "$ENV_FILE"
"$ROOT_DIR/scripts/migrate-site.sh" "$OLD_MONGO_CONTAINER" "$OLD_DB_NAME" "$NEW_DB_NAME"

cat <<EOF

Existing site imported.

What happened:
  - Added $SLUG to config/sites.csv
  - Created $ENV_FILE if it did not already exist
  - Rendered generated compose and Nginx config
  - Copied data from $OLD_MONGO_CONTAINER/$OLD_DB_NAME into shared Mongo database $NEW_DB_NAME

Next steps:
  1. Edit $ENV_FILE to match the site's Nightscout settings.
  2. Start or reload the stack:
     docker compose -f compose.yaml -f generated/compose.sites.yaml up -d
  3. Verify the site works before removing the old Mongo container.
EOF
