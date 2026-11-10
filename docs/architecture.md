# Fact and dimension mart layer architecture

## Design goal

The warehouse separates source truth, cleaning decisions, analytical attribution, decision metrics, and presentation logic. Every executive metric can be traced to order, contact, and ledger identifiers without rewriting business logic in a slide or notebook.

```text
+--------------------+
| Synthetic CSV files |
+----------+---------+
           |
           v
+----------+---------+     preserve source values
| raw                |
+----------+---------+
           |
           v
+----------+---------+     type, deduplicate, standardize
| staging            |
+----------+---------+
           |
           v
+----------+---------+     connect identities, contacts, and costs
| intermediate       |
+----------+---------+
           |
           v
+----------+---------+     publish reusable fct_ and dim_ models
| mart                |
+----------+---------+
           |
           v
+----------+---------+
| CSV exports,       |
| analysis, and deck |
+--------------------+

 audit.test_results checks raw, staging, intermediate, and mart
 after every complete build.
```

## Layers

### Raw

Raw tables mirror the fictional extracts and store source fields as text. This preserves defects that the case asks the analyst to confront: duplicate CRM records, missing references, inconsistent casing, optional CSAT, mixed money formatting, different duration units, and delayed finance posting.

No cleaning decision is hidden in this layer.

### Staging

Staging creates one typed, normalized representation of each source:

- Order statuses and channel labels are standardized.
- Legacy duration values are converted from seconds to minutes.
- Money strings are parsed while both signed and cost-oriented finance amounts are retained.
- CRM extracts are deduplicated by source update time.
- Customer references are canonicalized and active high-confidence mappings are selected.
- The separate loyalty scenario retains an explicit `simulated_flag`.

### Intermediate

The intermediate layer resolves cross-system meaning:

- Contacts first use exact order references.
- Missing order references may use a trusted customer map plus time proximity.
- Each attribution receives a method and confidence score.
- Verified resolution requires a resolved end state and no same-order follow-up contact within seven days.
- Handling costs use the supplied channel assumptions.
- Finance entries are aggregated to the originating order without losing posting dates.
- A single order-level analytical spine joins operations, support, finance, treatment, and customer outcome components.

### Mart

- `fct_city_week`: the 8-city by 12-week experimental panel with additive metric components and unit economics.
- `fct_customer_issue_episode`: mature 28-day reorder outcomes with explicit right-censoring.
- `fct_customer_summary`: customer exposure and clearly labeled modeled loyalty risk.
- `fct_finance_maturity`: visibility of chargebacks after 7, 14, 21, and 28 days.
- `fct_data_quality`: disclosed data defects, affected rows, severity, and treatment.
- `dim_week`: case-study and finance follow-up calendar.
- `dim_metric`: governed metric definitions, owners, windows, event anchors, caveats, direction, and thresholds.
- Labeled simulation models in the `mart` schema preserve the observed contact and order facts, attach a scenario ID, and project customer and financial outcomes through the same order-level formula.

The business-facing `mart` schema also contains:

- A governed metric catalog with definition, grain, numerator, denominator, owner, window, event anchor, caveat, direction, and decision threshold.
- Weekly KPIs at city-week grain.
- Difference-in-differences estimates for 13 decision metrics.
- Week-level event-study gaps normalized to week 6.
- CRM-reported versus verified resolution reconciliation.
- Mature observed loyalty and separately labeled modeled loyalty views.
- Promotion exposure, negative-control, metric-relationship, and finance-maturity views.
- Recommendation options and automated monitoring thresholds.
- Model lineage.
- Deterministic conservative, expected, and strong faster-help scenarios with contact, order, city-week, and presentation-ready metric facts.

## Causal contract

The primary comparison is the change from weeks 1-6 to weeks 7-12 in the four treatment cities, net of the contemporaneous change in the four control cities. City-week estimates are equal-city weighted in the transparent fact model.

The week 8 `FREEDEL` promotion is treated as a national calendar shock. The fact and dimension mart layer exposes promotion penetration rather than silently conditioning the headline estimate on a post-launch field.

The design supports directional causal interpretation, not randomized-trial certainty. Treatment was assigned at the city level, only eight cities exist, and assignment was not stated to be random.

## Trust boundaries

- Raw contact count is trusted as source volume after deduplication.
- CRM resolution is published but not accepted as durable resolution.
- Optional CSAT is respondent-only and always paired with response coverage.
- Low-confidence time-based attribution is visible and separable.
- Recent chargeback and reorder cohorts are not treated as mature.
- Modeled 90-day loyalty is assumption-only and never blended into observed results.
- Faster-help projections are labeled simulation outputs, never replacements for observed facts. They omit incremental staffing dollars because the source files do not contain workforce cost.
