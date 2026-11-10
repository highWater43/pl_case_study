-- Decision-ready queries for live presentation and drill-through.

-- 1. Executive treatment effects.
SELECT
    display_name,
    treated_pre,
    treated_post,
    control_pre,
    control_post,
    did_effect,
    directional_assessment
FROM mart.fct_executive_scorecard
ORDER BY metric_type, metric_name;

-- 2. CRM-reported resolution versus verified durable resolution.
SELECT *
FROM mart.fct_containment_reconciliation
ORDER BY treatment_group, post_period;

-- 3. Weekly event-study components for the main guardrails.
SELECT *
FROM mart.fct_event_study
WHERE metric_name IN (
    'handling_cost_per_order',
    'verified_resolution_rate',
    'abandonment_rate',
    'chargebacks_per_1000_orders'
)
ORDER BY metric_name, order_week;

-- 4. Mature observed loyalty effect.
SELECT * FROM mart.fct_loyalty_guardrails ORDER BY treatment_group, post_period;
SELECT * FROM mart.fct_loyalty_did;

-- 5. Why recent finance cohorts are incomplete.
SELECT *
FROM mart.fct_finance_maturity_curve
ORDER BY order_week, treatment_group;

-- 6. Data-trust decisions.
SELECT *
FROM mart.fct_data_trust
ORDER BY severity, check_name;

-- 7. Trace a scorecard cell to city-week inputs.
SELECT *
FROM mart.fct_weekly_kpis
WHERE treatment_group = 'treatment' AND post_period
ORDER BY city, order_week;

-- 8. Trace an order to contacts and finance.
-- Replace the example ID with any order shown in intermediate.int_order_outcomes.
SELECT *
FROM intermediate.int_order_outcomes
WHERE order_id = 'ORD-HBC-07-00001';

SELECT *
FROM intermediate.int_contacts_enriched
WHERE attributed_order_id = 'ORD-HBC-07-00001'
ORDER BY contact_ts;

SELECT *
FROM staging.stg_finance
WHERE order_id = 'ORD-HBC-07-00001'
ORDER BY posted_date, ledger_id;
