#!/usr/bin/env sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
UPSTREAM_DIR="${1:-$ROOT_DIR/upstream/cgm-remote-monitor}"
UPSTREAM_URL="${NIGHTSCOUT_UPSTREAM_REPO:-https://github.com/nightscout/cgm-remote-monitor.git}"

mkdir -p "$(dirname "$UPSTREAM_DIR")"

if [ ! -d "$UPSTREAM_DIR/.git" ]; then
  git clone --depth 1 "$UPSTREAM_URL" "$UPSTREAM_DIR"
else
  git -C "$UPSTREAM_DIR" fetch --depth 1 origin
  CURRENT_BRANCH=$(git -C "$UPSTREAM_DIR" rev-parse --abbrev-ref HEAD)
  git -C "$UPSTREAM_DIR" pull --ff-only origin "$CURRENT_BRANCH"
fi

git -C "$UPSTREAM_DIR" rev-parse HEAD
