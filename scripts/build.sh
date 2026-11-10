#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_SOCKET="$PROJECT_DIR/.postgres/socket"
PG_PORT="${FORKDASH_PG_PORT:-55432}"
PG_USER="${FORKDASH_PG_USER:-case_study_admin}"
PG_DATABASE="${FORKDASH_PG_DATABASE:-forkdash_case}"

"$PROJECT_DIR/scripts/init_postgres.sh"
python3 "$PROJECT_DIR/scripts/generate_synthetic_data.py"

dropdb --if-exists -h "$PG_SOCKET" -p "$PG_PORT" -U "$PG_USER" "$PG_DATABASE"
createdb -h "$PG_SOCKET" -p "$PG_PORT" -U "$PG_USER" "$PG_DATABASE"

PSQL=(psql -X -v ON_ERROR_STOP=1 -h "$PG_SOCKET" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DATABASE")

"${PSQL[@]}" -f "$PROJECT_DIR/sql/00_foundation.sql"
"${PSQL[@]}" \
  -v orders_csv="$PROJECT_DIR/data/raw/orders_ops.csv" \
  -v contacts_csv="$PROJECT_DIR/data/raw/support_contacts.csv" \
  -v finance_csv="$PROJECT_DIR/data/raw/finance_ledger.csv" \
  -v map_csv="$PROJECT_DIR/data/raw/customer_map.csv" \
  -v assignment_csv="$PROJECT_DIR/data/raw/experiment_assignment.csv" \
  -v loyalty_csv="$PROJECT_DIR/data/raw/loyalty_scenario.csv" \
  -v issues_csv="$PROJECT_DIR/data/raw/order_issues.csv" \
  -v journey_csv="$PROJECT_DIR/data/raw/support_journey_events.csv" \
  -f "$PROJECT_DIR/sql/01_load_raw.sql"
"${PSQL[@]}" -f "$PROJECT_DIR/sql/10_staging.sql"
"${PSQL[@]}" -f "$PROJECT_DIR/sql/20_intermediate.sql"
"${PSQL[@]}" -f "$PROJECT_DIR/sql/30_mart.sql"
"${PSQL[@]}" -f "$PROJECT_DIR/sql/40_business_mart.sql"
"${PSQL[@]}" -f "$PROJECT_DIR/sql/45_simulation_mart.sql"
"${PSQL[@]}" -f "$PROJECT_DIR/sql/50_tests.sql"

"$PROJECT_DIR/scripts/run_tests.sh"
"$PROJECT_DIR/scripts/export_artifacts.sh"

PDF_PYTHON="$PROJECT_DIR/.venv-pdf/bin/python"
if [[ ! -x "$PDF_PYTHON" ]]; then
  printf 'PDF environment is missing. Run:\n'
  printf 'python3 -m venv .venv-pdf\n'
  printf '.venv-pdf/bin/pip install -r requirements-pdf.txt\n'
  exit 1
fi

"$PDF_PYTHON" "$PROJECT_DIR/scripts/build_report_pdf.py"

printf 'Build complete. Connect with:\n'
printf 'psql -h %q -p %q -U %q -d %q\n' "$PG_SOCKET" "$PG_PORT" "$PG_USER" "$PG_DATABASE"
