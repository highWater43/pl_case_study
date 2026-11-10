#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_SOCKET="$PROJECT_DIR/.postgres/socket"
PG_PORT="${FORKDASH_PG_PORT:-55432}"
PG_USER="${FORKDASH_PG_USER:-case_study_admin}"
PG_DATABASE="${FORKDASH_PG_DATABASE:-forkdash_case}"

PSQL=(psql -X -h "$PG_SOCKET" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE")

"${PSQL[@]}" -P pager=off -c "SELECT test_name, test_category, passed, observed_value, expectation FROM audit.test_results ORDER BY test_category, test_name;"

FAILED_COUNT="$("${PSQL[@]}" -Atqc "SELECT count(*) FROM audit.v_failed_tests;")"
if [[ "$FAILED_COUNT" != "0" ]]; then
  printf '%s validation test(s) failed.\n' "$FAILED_COUNT" >&2
  "${PSQL[@]}" -P pager=off -c "SELECT * FROM audit.v_failed_tests;" >&2
  exit 1
fi

printf 'All warehouse validation tests passed.\n'
