# Faster-help simulation method

## Question

Using the same observed orders and contacts, what would the original four-city by four-city, before-and-after result look like if support turnaround improved in the four changed cities after week 7?

The simulation projects an answer from the synthetic database. It does not claim that faster response caused the projected outcomes. A randomized live experiment must test that claim.

## Separation from observed data

- Observed source, staging, intermediate, and fact models remain unchanged.
- Every simulation row includes a `scenario_id`, `simulated_flag`, and mandatory disclosure label.
- Every simulated order retains the observed `order_id`.
- The same value-left formula is used for observed and projected orders.
- Staffing hours are estimated, but incremental staffing dollars remain zero because the source files do not contain wages or agent-capacity costs.

```text
Observed contact and order
            |
            v
Is it a failed AI-to-human handoff in a changed city after week 7?
            |
        +---+---+
        |       |
       no      yes
        |       |
        |       v
        |   Find reference outcomes from similar fast handoffs
        |   with the same problem type and severity
        |       |
        |       v
        |   Apply the selected rescue share and response target
        |       |
        +-------+
            |
            v
Recalculate the same order's support and finance outcomes
            |
            v
Aggregate to city and week
            |
            v
Rerun the original 2-by-2 comparison
            |
            v
Label the result as simulated and retain the original order ID
```

## Scenarios

| Scenario | Failed handoffs receiving a person | Human response target |
|---|---:|---:|
| `FAST_HELP_CONSERVATIVE` | 50 out of 100 | 5 minutes |
| `FAST_HELP_EXPECTED` | 70 out of 100 | 4 minutes |
| `FAST_HELP_STRONG` | 85 out of 100 | 3 minutes |

These are testable operating targets, not fitted forecasts.

## How the projection is built

1. Find observed AI-to-human contacts where a person responded within two to five minutes.
2. Calculate their resolution, repeat-support, satisfaction, handling, refund, payment-dispute, and human-time outcomes by issue type and severity.
3. Identify AI handoffs in the changed cities after week 7 that ended before a human responded.
4. Apply each scenario's rescue share. Project rescued contacts toward the observed fast-response reference rates and leave the remaining contacts at their observed outcomes.
5. Recalculate each affected order's support and finance components, then aggregate to city-week and presentation metrics.
6. Keep every before-period record and every unchanged-city record observed.
7. Rerun the same 2-by-2 calculation: the before-to-after change in the four changed cities minus the before-to-after change in the four unchanged cities.

The calculation uses probability-weighted expected values and no random draws. The same source data and scenario version always return the same result.

## Simulation mart tables

| Model | Grain | What it contains |
|---|---|---|
| `mart.dim_simulation_scenario` | Scenario | Rescue share, response target, version, and required simulation label. |
| `mart.dim_simulation_assumption` | Scenario and assumption | Value, source model, filter, rationale, and limitation for every assumption. |
| `mart.fct_sim_reference_rates` | Issue type and severity | Observed outcomes for similar completed handoffs answered within two to five minutes. |
| `mart.fct_sim_contact_outcomes` | Scenario and contact | Observed and projected handoff, abandonment, resolution, repeat-support, satisfaction, payment-dispute, and human-time outcomes. |
| `mart.fct_sim_order_outcomes` | Scenario and order | Observed and projected support costs, finance costs, and value left with the original `order_id`. |
| `mart.fct_sim_city_week` | Scenario, city, and week | Projected totals at the same grain as the observed experiment. |
| `mart.fct_sim_metric_results` | Scenario and metric | Current result, projected result, change, observed 2-by-2 comparison, simulated 2-by-2 comparison, unit, and presentation label. This includes completed AI-to-human resolution time. |

## Metric links

The simulation connects the customer journey to the North Star in this order:

```text
faster human response
to completed handoff and lower queue abandonment
to verified resolution and repeat support
to refunds, credits, payment disputes, fees, and handling
to value left per order
```

Each link remains visible as a separate field. The method does not force every downstream metric to improve.

The presentation reports the 2-by-2 gaps, not a direct comparison between a proposed AI product and the current AI-first experience. This matters because the national campaign begins in week 8 and affects both city groups.

## Reproduction queries

List scenarios and assumptions:

```sql
SELECT *
FROM mart.dim_simulation_scenario
ORDER BY scenario_id;

SELECT *
FROM mart.dim_simulation_assumption
ORDER BY scenario_id, assumption_name;
```

Inspect the expected scenario results:

```sql
SELECT
    metric_name,
    observed_treated_post,
    simulated_treated_post,
    simulated_change_vs_observed,
    observed_did_effect,
    simulated_did_effect,
    unit
FROM mart.fct_sim_metric_results
WHERE scenario_id = 'FAST_HELP_EXPECTED'
ORDER BY metric_name;
```

Trace one projected order:

```sql
SELECT *
FROM mart.fct_sim_order_outcomes
WHERE scenario_id = 'FAST_HELP_EXPECTED'
  AND order_id = '<order_id>';
```

## What a live experiment must prove

The next test should randomly assign eligible sessions within the same cities to the original support design, current AI-first design, or redesigned AI-first experience with easy human escalation. The redesigned experience passes only if it:

- Meets the human-response target.
- Restores verified resolution without increasing abandonment or repeat support.
- Does not raise mature payment disputes.
- Improves value left after measured support and finance costs.
- Remains favorable after the real staffing cost is included.

## Limits

- Fast-response reference cases may differ from abandoned cases in ways the data does not measure.
- Response time alone does not guarantee that the customer problem is solved.
- Recent payment disputes require 28 to 30 days to mature.
- Customers who leave the support page before starting a contact are missing from the source data.
- The projection excludes incremental staffing dollars.
- Simulation narrows the experiment design. It does not replace the experiment.
