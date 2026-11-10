# ForkDash Contact Simplification Case Study

This repository builds a reproducible, local PostgreSQL analytics environment for the ForkDash Senior Product Analyst case study. It creates deterministic synthetic source data, preserves realistic source-system defects, and transforms the data through raw, staging, intermediate, and fact and dimension mart layers.

```text
synthetic source files
          |
          v
clean and standardize each source
          |
          v
connect support and finance records to orders
          |
          v
publish fact and dimension models
          |
          +--------------------+
          |                    |
          v                    v
observed 2-by-2 results   labeled simulations
          |                    |
          +--------------------+
                    |
                    v
       recommendation and experiment design
```

## Quick start

Create the local report environment once:

```bash
python3 -m venv .venv-pdf
.venv-pdf/bin/pip install -r requirements-pdf.txt
```

Then rebuild the synthetic data, PostgreSQL models, validation exports, and 19-slide PDF with one command:

```bash
./scripts/build.sh
```

The PostgreSQL instance uses a project-local data directory, a Unix socket under `.postgres/socket`, and port `55432`. The build creates a database named `forkdash_case` owned by `case_study_admin`.

Connect directly:

```bash
psql -h "$PWD/.postgres/socket" -p 55432 -U case_study_admin -d forkdash_case
```

## Project structure

- `scripts/`: data generation, PostgreSQL lifecycle, build, test, and export scripts
- `sql/`: ordered warehouse and fact-and-dimension-mart SQL
- `data/raw/`: deterministic synthetic source extracts
- `data/exports/`: exported fact models and validation results
- `docs/`: architecture, metric definitions, lineage, and operating guidance
- `reports/`: analytical findings and external research
- `output/pdf/`: locally generated report output, excluded from version control

Start with [the analytical framework](docs/analysis-direction.md), [the data cleaning and modeling approach](docs/data-cleaning-and-modeling.md), [the simulation method](docs/simulation-method.md), [the architecture](docs/architecture.md), and [the slide map](docs/slide-map.md).

The final presentation and original candidate brief are distributed separately and are not stored in this repository.

## Analytical story encoded in the data

The week 7 intervention lowers visible contact volume and direct handling cost in four treatment cities. It also increases abandonment, repeat contact, unresolved demand, chargebacks, and downstream customer risk. The week 8 `FREEDEL` promotion affects all cities and is handled as a common time shock in treatment-versus-control comparisons.

The data is synthetic. Loyalty-related views are explicitly labeled as observed proxies or modeled scenarios so that simulated evidence cannot be mistaken for measured company data.

## Reproducibility

The generator uses a fixed random seed and emits a manifest with record counts and SHA-256 hashes. The build recreates the database from source files and then runs warehouse assertions. Every executive metric can be traced to a fact model, a mart, and ultimately a raw row.

## Build only the PDF report

The report builder uses Python 3.9 or newer and writes the final artifact to `output/pdf/`.

```bash
python3 -m venv .venv-pdf
.venv-pdf/bin/pip install -r requirements-pdf.txt
.venv-pdf/bin/python scripts/build_report_pdf.py
```

The report uses only case-brief fields as primary evidence. Additional AI handoff timestamps are treated as a future instrumentation proposal, not as observed evidence.
