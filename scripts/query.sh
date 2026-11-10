#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec psql \
  -h "$PROJECT_DIR/.postgres/socket" \
  -p "${FORKDASH_PG_PORT:-55432}" \
  -U "${FORKDASH_PG_USER:-case_study_admin}" \
  -d "${FORKDASH_PG_DATABASE:-forkdash_case}" \
  "$@"
