#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_DATA="$PROJECT_DIR/.postgres/data"

if [[ -s "$PG_DATA/PG_VERSION" ]]; then
  pg_ctl -D "$PG_DATA" stop
fi
