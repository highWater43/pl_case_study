# Data cleaning and fact/dimension modeling approach

## Purpose

This pipeline turns the synthetic operations, support, finance, identity, experiment, issue, and customer-journey files into traceable fact and dimension models. The database schema for presentation-ready models is `mart`, singular.

The design keeps four concerns separate:

1. Preserve the source files exactly as received.
2. Clean and standardize each source once.
3. Connect sources and calculate order-level outcomes once.
4. Publish reusable facts and dimensions for metrics, analysis, simulation, and slides.

```text
orders.csv --------------------> stg_orders ----------------------+
support_contacts.csv ----------> stg_contacts --> order matching -+
finance_ledger.csv ------------> stg_finance ---------------------+
customer_map.csv --------------> stg_customer_map ----------------+
experiment_assignment.csv -----> stg_experiment_assignment -------+
order_issues.csv --------------> stg_order_issues ----------------+
support_journey_events.csv ----> stg_support_journey_events ------+
                                                                  |
                                                                  v
                                                    int_order_outcomes
                                                    one row per order
                                                                  |
                                      +---------------------------+------------------+
                                      |                           |                  |
                                      v                           v                  v
                               observed facts              AI journey facts   simulation facts
                                      |                           |                  |
                                      +---------------------------+------------------+
                                                                  |
                                                                  v
                                                     governed decision metrics
```

## Build scripts in execution order

| Script | What it does | Main output |
|---|---|---|
| `scripts/generate_synthetic_data.py` | Creates deterministic source extracts with a fixed seed and documented source defects. | `data/raw/*.csv` and `data/raw/manifest.json` |
| `sql/00_foundation.sql` | Recreates the raw, staging, intermediate, `mart`, and audit schemas. | Empty database structure |
| `sql/01_load_raw.sql` | Loads source files without changing their text fields. | `raw.*` |
| `sql/10_staging.sql` | Types values, standardizes labels and units, and removes duplicate extract versions. | `staging.stg_*` |
| `sql/20_intermediate.sql` | Links contacts and finance entries to orders and builds the order-level analytical spine. | `intermediate.int_*` |
| `sql/30_mart.sql` | Creates the core observed facts and dimensions. | `mart.fct_*` and `mart.dim_*` |
| `sql/40_business_mart.sql` | Creates decision metrics, experiment comparisons, lineage, monitoring, and team metric definitions. | Business-facing `mart.fct_*` and `mart.dim_*` |
| `sql/45_simulation_mart.sql` | Creates separately labeled faster-help scenarios without changing observed facts. | Simulation `mart.fct_sim_*` and `mart.dim_simulation_*` |
| `sql/50_tests.sql` | Runs referential, uniqueness, validity, experiment, governance, and simulation checks. | `audit.test_results` |
| `sql/60_example_queries.sql` | Provides reproducible queries for the main case-study questions. | Analyst query examples |
| `scripts/export_artifacts.sh` | Exports presentation-ready facts, dimensions, assumptions, lineage, and tests. | `data/exports/*.csv` |

`scripts/build.sh` runs the full sequence against the project-local PostgreSQL database.

## Cleaning decisions

| Source problem | Standardization rule | Model that owns the rule |
|---|---|---|
| Duplicate support extract rows | Keep the latest source version for each contact. | `staging.stg_contacts` |
| Mixed capitalization and label variants | Convert order status, channel, issue, handling, and end-reason values to governed labels. | `staging.stg_orders`, `staging.stg_contacts` |
| Durations recorded in seconds by one source and minutes by another | Convert every promised and actual duration to minutes. | `staging.stg_orders` |
| Money stored as text with signs or currency symbols | Parse a numeric signed amount and a positive cost amount. | `staging.stg_orders`, `staging.stg_finance` |
| Optional or invalid satisfaction scores | Keep only valid 1-to-5 responses and publish response coverage with the average. | `staging.stg_contacts`, `mart.fct_weekly_kpis` |
| Missing support order ID | First use an exact order reference. Otherwise use a trusted customer map and time proximity. Keep the attribution method and confidence. | `intermediate.int_contacts_attributed_base` |
| Support contacts that cannot reach an order | Retain them in contact-quality reporting but exclude them from order economics. | `intermediate.int_contacts_attributed_base`, `mart.fct_source_mapping_summary` |
| Refunds, credits, payment disputes, and fees posted after the order | Attribute them to the originating order and retain posting lag for maturity checks. | `intermediate.int_order_finance_summary`, `mart.fct_finance_maturity` |
| CRM marks a contact resolved even when the customer returns | Define verified resolution as a resolved end state with no same-order contact in the next seven days. | `intermediate.int_contacts_enriched` |
| Late order cohorts lack a full future-order window | Include only issue orders with 28 complete days of follow-up. | `mart.fct_customer_issue_episode` |

## The order-level spine

`intermediate.int_order_outcomes` is the central reusable model. One row represents one order and contains:

- Order value and the assumed 12% starting value.
- Experiment city, week, and before-or-after status.
- Support contacts, channels, handling cost, abandonment, resolution, repeat support, and satisfaction.
- Refunds, customer credits, payment disputes, dispute fees, and posting lag.
- Issue type, issue severity, and observed future-order eligibility.

The value-left calculation is applied once at this grain:

```text
value left
= 12% of order value
- support handling cost
- refunds and customer credits
- payment-dispute amount
- payment-dispute fee
```

Slides and exports read this governed calculation rather than rebuilding it independently.

## Main observed fact and dimension models

| Model | Grain | Use |
|---|---|---|
| `mart.fct_city_week` | City and week | Additive experiment panel and order economics. |
| `mart.fct_weekly_kpis` | City and week | Rates and per-order metrics used in analysis. |
| `mart.fct_did_estimates` | Metric | Before-and-after change in changed cities compared with unchanged cities. |
| `mart.fct_executive_scorecard` | Metric | Money result, guardrails, direction, and decision status. |
| `mart.fct_contact_journey` | Contact | AI and human handoff events and outcomes. |
| `mart.fct_ai_issue_scorecard` | Group, period, issue type, severity | AI handling and verified resolution by customer problem. |
| `mart.fct_handoff_funnel` | Group and period | Escalation, human response, abandonment, and wait-time results. |
| `mart.fct_customer_issue_episode` | Issue order | Mature 28-day future-order outcome. |
| `mart.fct_finance_maturity_curve` | Order week and group | Payment-dispute completion by follow-up age. |
| `mart.fct_source_mapping_summary` | Source and mapping status | Exact, inferred, and missing order connections. |
| `mart.dim_metric` | Metric | Definition, numerator, denominator, owner, window, caveat, and threshold. |
| `mart.dim_team_metric` | Team and metric | Which team uses each decision, guardrail, or diagnostic metric. |
| `mart.dim_number_provenance` | Presented metric | Source model, source fields, join path, and reproduction query. |

The complete model dictionary is in `docs/data-dictionary.md`.

## Validation contract

The build fails when a required check fails. The checks cover:

- Primary-key uniqueness and foreign-key coverage.
- Contact-to-order and finance-to-order mapping.
- Valid durations and journey timestamps.
- Complete city-week experiment panels and promotion timing.
- Non-null published metrics and complete metric definitions.
- Explicit simulation labels and observed-order coverage.
- Direction checks for the synthetic scenario encoded in the case.

Run `./scripts/run_tests.sh` to reproduce the checks. The results are also exported to `data/exports/test_results.csv`.
