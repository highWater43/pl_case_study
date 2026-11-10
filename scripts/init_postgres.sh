#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_ROOT="$PROJECT_DIR/.postgres"
PG_DATA="$PG_ROOT/data"
PG_SOCKET="$PG_ROOT/socket"
PG_LOG="$PG_ROOT/postgres.log"
PG_PORT="${FORKDASH_PG_PORT:-55432}"
PG_USER="${FORKDASH_PG_USER:-case_study_admin}"

mkdir -p "$PG_ROOT" "$PG_SOCKET"

if [[ ! -s "$PG_DATA/PG_VERSION" ]]; then
  initdb --pgdata="$PG_DATA" --username="$PG_USER" --auth=trust --encoding=UTF8 --locale=C
fi

if ! pg_isready -h "$PG_SOCKET" -p "$PG_PORT" -U "$PG_USER" >/dev/null 2>&1; then
  pg_ctl -D "$PG_DATA" -l "$PG_LOG" -o "-p $PG_PORT -k $PG_SOCKET" start
fi

for _attempt in {1..30}; do
  if pg_isready -h "$PG_SOCKET" -p "$PG_PORT" -U "$PG_USER" >/dev/null 2>&1; then
    printf 'PostgreSQL is ready on socket %s, port %s.\n' "$PG_SOCKET" "$PG_PORT"
    exit 0
  fi
  sleep 1
done

printf 'PostgreSQL did not become ready. Review %s.\n' "$PG_LOG" >&2
exit 1
