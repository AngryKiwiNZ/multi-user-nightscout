#!/usr/bin/env sh
set -eu

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <old_mongo_container> <old_db_name> <new_db_name>" >&2
  exit 1
fi

OLD_CONTAINER=$1
OLD_DB=$2
NEW_DB=$3
NEW_CONTAINER="${MONGO_CONTAINER_NAME:-shared-mongo}"
MONGO_USER="${MONGO_ROOT_USERNAME:?set MONGO_ROOT_USERNAME}"
MONGO_PASS="${MONGO_ROOT_PASSWORD:?set MONGO_ROOT_PASSWORD}"
TMP_ARCHIVE="/tmp/nightscout-migration.archive"

echo "Dumping $OLD_DB from $OLD_CONTAINER"
docker exec "$OLD_CONTAINER" sh -lc "mongodump --db '$OLD_DB' --archive" >"$TMP_ARCHIVE"

echo "Restoring into $NEW_DB on $NEW_CONTAINER"
cat "$TMP_ARCHIVE" | docker exec -i "$NEW_CONTAINER" sh -lc \
  "mongorestore --username '$MONGO_USER' --password '$MONGO_PASS' --authenticationDatabase admin --nsFrom '$OLD_DB.*' --nsTo '$NEW_DB.*' --archive"

rm -f "$TMP_ARCHIVE"

echo "Migration complete: $OLD_DB -> $NEW_DB"
