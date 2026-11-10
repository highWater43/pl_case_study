# Local runbook

## Build everything

From the project root:

```bash
./scripts/build.sh
```

This command:

1. Initializes a project-local PostgreSQL 17 cluster if needed.
2. Starts it on Unix socket `.postgres/socket` and port `55432`.
3. Regenerates all source CSVs using seed `20261106`.
4. Recreates the `forkdash_case` database.
5. Builds every SQL layer in order.
6. Runs the validation suite and fails if any assertion fails.
7. Exports the governed fact and dimension results used by the report.
8. Builds the 19-slide PDF in `output/pdf/`.

```text
generate synthetic files
          |
          v
initialize PostgreSQL
          |
          v
load raw tables
          |
          v
build staging models
          |
          v
build intermediate models
          |
          v
build fact, dimension, and simulation models
          |
          v
run 37 automated checks
          |
          v
export governed CSV results
          |
          v
build the local presentation PDF
```

The PDF environment must be installed once before the first full build:

```bash
python3 -m venv .venv-pdf
.venv-pdf/bin/pip install -r requirements-pdf.txt
```

## Connect

```bash
./scripts/query.sh
```

Example:

```sql
SELECT *
FROM mart.fct_executive_scorecard
ORDER BY metric_type, metric_name;
```

One-command query:

```bash
./scripts/query.sh -P pager=off -c "SELECT * FROM mart.fct_data_trust;"
```

## Validate

```bash
./scripts/run_tests.sh
```

Test evidence is also persisted in `audit.test_results` and exported to `data/exports/test_results.csv`.

## Export decision artifacts

```bash
./scripts/export_artifacts.sh
```

The export folder contains the executive scorecard, weekly panel, event study, data-trust report, containment reconciliation, loyalty guardrails, promotion balance, finance maturity, metric relationships, negative control, metric catalog, and test results.

## Stop the project-local database

Only stop it when intentionally ending the local service:

```bash
./scripts/stop_postgres.sh
```

The data directory remains under `.postgres/data` and is recoverable on restart.

## Reproducibility controls

- Generator seed: `20261106`
- Source counts and SHA-256 hashes: `data/raw/manifest.json`
- Build order: numbered scripts in `sql/`
- Validation results: `audit.test_results`
- Source defects and handling: `mart.fct_data_trust`
- Metric definitions and ownership: `mart.dim_metric`
