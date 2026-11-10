\set ON_ERROR_STOP on

CREATE TABLE mart.dim_metric (
    metric_name text PRIMARY KEY,
    display_name text NOT NULL,
    metric_type text NOT NULL CHECK (metric_type IN ('primary', 'driver', 'guardrail', 'counter', 'trust')),
    direction_of_good text NOT NULL CHECK (direction_of_good IN ('up', 'down', 'neutral')),
    business_definition text NOT NULL,
    grain text NOT NULL,
    numerator text,
    denominator text,
    source_model text NOT NULL,
    caveat text
);

INSERT INTO mart.dim_metric VALUES
('support_adjusted_contribution_per_order', 'Support-adjusted contribution per order', 'primary', 'up', 'Order contribution margin less handling, refund, credit, chargeback dispute, and chargeback fee costs.', 'city-week', 'Support-adjusted contribution USD', 'All orders', 'mart.fct_city_week', 'Does not monetize unobserved lifetime-value loss.'),
('contacts_per_1000_orders', 'Contacts per 1,000 orders', 'driver', 'neutral', 'Attributed support contacts for every 1,000 orders.', 'city-week', 'Attributed contacts x 1,000', 'All orders', 'mart.fct_city_week', 'A decline can indicate either better service or suppressed access.'),
('handling_cost_per_order', 'Direct handling cost per order', 'driver', 'down', 'Channel-specific contact handling cost divided by all orders.', 'city-week', 'AI, phone, and email handling cost', 'All orders', 'mart.fct_city_week', 'Visible support cost only; not a standalone success metric.'),
('fully_loaded_failure_cost_per_order', 'Fully loaded failure cost per order', 'primary', 'down', 'Handling, refunds, credits, chargeback disputes, and processor fees divided by all orders.', 'city-week', 'All observed failure costs', 'All orders', 'mart.fct_city_week', 'Finance entries are attributed to order cohort and require maturity.'),
('verified_resolution_rate', 'Verified resolution rate', 'guardrail', 'up', 'Contacts with a resolved end state and no repeat contact for the same order within seven days.', 'city-week', 'Verified resolved contacts', 'Attributed contacts', 'mart.fct_city_week', 'Seven days is a declared analysis window, not a source-system field.'),
('crm_resolution_rate', 'CRM-reported resolution rate', 'trust', 'up', 'Contacts flagged resolved by the CRM.', 'city-week', 'CRM resolved contacts', 'Attributed contacts', 'mart.fct_city_week', 'Optimistic for AI exits; compare with verified resolution.'),
('abandonment_rate', 'Contact abandonment rate', 'guardrail', 'down', 'Contacts ending in customer abandonment.', 'city-week', 'Abandoned contacts', 'Attributed contacts', 'mart.fct_city_week', 'Does not capture customers who never initiated a contact.'),
('repeat_contact_rate', 'Repeat-contact order rate', 'guardrail', 'down', 'Contacted orders with more than one attributed contact.', 'city-week', 'Contacted orders with repeat contact', 'Contacted orders', 'mart.fct_city_week', 'Order-level proxy for first-contact resolution.'),
('chargebacks_per_1000_orders', 'Chargebacks per 1,000 orders', 'counter', 'down', 'Chargeback disputes tied to an order cohort for every 1,000 orders.', 'city-week', 'Chargebacks x 1,000', 'All orders', 'mart.fct_city_week', 'Late-posting; use maturity views before declaring recent cohorts stable.'),
('average_csat', 'Average CSAT', 'guardrail', 'up', 'Mean optional 1-5 satisfaction score among respondents.', 'city-week', 'Sum of response scores', 'Survey responses', 'mart.fct_city_week', 'Not representative without response-rate and respondent-mix checks.'),
('csat_response_rate', 'CSAT response rate', 'trust', 'neutral', 'Share of contacts with a valid CSAT response.', 'city-week', 'Valid CSAT responses', 'Attributed contacts', 'mart.fct_city_week', 'Use to diagnose nonresponse bias.'),
('observed_28d_reorder_rate', 'Observed 28-day reorder rate after an issue', 'guardrail', 'up', 'Issue episodes followed by another order within 28 days among mature, observable episodes.', 'issue episode', 'Eligible episodes with a subsequent order in 28 days', 'Issue episodes with a full 28-day observation window', 'mart.fct_customer_issue_episode', 'Late cohorts are right-censored and excluded.'),
('modeled_90d_churn_probability', 'Modeled 90-day churn probability', 'counter', 'down', 'Scenario-only loyalty risk based on synthetic assumptions.', 'customer', 'Modeled probability', 'Customers', 'mart.fct_customer_summary', 'Simulated, not observed. Never present as measured company performance.');

INSERT INTO mart.dim_metric VALUES
('cancellation_rate', 'Order cancellation rate', 'counter', 'down', 'Cancelled orders divided by all orders.', 'city-week', 'Cancelled orders', 'All orders', 'mart.fct_city_week', 'Operational context and possible promotion side effect; not a direct support outcome.'),
('late_delivery_rate', 'Late-delivery rate', 'counter', 'down', 'Orders delivered after the promised duration divided by delivered orders.', 'city-week', 'Late delivered orders', 'Delivered orders', 'mart.fct_city_week', 'Source-system duration units are standardized in staging.');

ALTER TABLE mart.dim_metric
    ADD COLUMN observation_window_days integer,
    ADD COLUMN event_date_type text,
    ADD COLUMN synthetic_status text NOT NULL DEFAULT 'synthetic_observation',
    ADD COLUMN metric_owner text,
    ADD COLUMN decision_threshold text;

UPDATE mart.dim_metric
SET event_date_type = CASE
        WHEN metric_name LIKE '%chargeback%' OR metric_name LIKE '%contribution%' OR metric_name LIKE '%failure_cost%' THEN 'order cohort with finance-posting reconciliation'
        WHEN metric_name LIKE '%contact%' OR metric_name LIKE '%resolution%' OR metric_name IN ('average_csat', 'csat_response_rate', 'abandonment_rate') THEN 'contact and originating order cohort'
        WHEN metric_name LIKE '%reorder%' OR metric_name LIKE '%churn%' THEN 'customer order cohort'
        ELSE 'order cohort'
    END,
    observation_window_days = CASE
        WHEN metric_name IN ('verified_resolution_rate', 'repeat_contact_rate') THEN 7
        WHEN metric_name = 'observed_28d_reorder_rate' THEN 28
        WHEN metric_name = 'modeled_90d_churn_probability' THEN 90
        WHEN metric_name LIKE '%chargeback%' OR metric_name LIKE '%failure_cost%' OR metric_name LIKE '%contribution%' THEN 30
    END,
    synthetic_status = CASE
        WHEN metric_name = 'modeled_90d_churn_probability' THEN 'assumption_only'
        ELSE 'synthetic_observation'
    END,
    metric_owner = CASE
        WHEN metric_type = 'primary' THEN 'Product Finance'
        WHEN metric_name LIKE '%chargeback%' THEN 'Finance Risk'
        WHEN metric_name LIKE '%reorder%' OR metric_name LIKE '%churn%' THEN 'Loyalty Analytics'
        WHEN metric_type = 'trust' THEN 'Data Platform'
        ELSE 'Customer Care Product'
    END,
    decision_threshold = CASE
        WHEN metric_name = 'verified_resolution_rate' THEN 'No more than 3 percentage point degradation versus holdout'
        WHEN metric_name = 'chargebacks_per_1000_orders' THEN 'No more than 10% relative increase versus mature holdout'
        WHEN metric_name = 'observed_28d_reorder_rate' THEN 'No more than 2 percentage point degradation versus holdout'
        WHEN metric_name = 'support_adjusted_contribution_per_order' THEN 'Positive treatment effect after finance maturity'
    END;

CREATE VIEW mart.fct_weekly_kpis AS
SELECT
    city,
    city_code,
    treatment_group,
    order_week,
    post_period,
    freedel_promo_observed,
    total_orders,
    freedel_orders,
    (freedel_orders::numeric / nullif(total_orders, 0))::numeric(12,4) AS freedel_order_share,
    total_contacts,
    (1000.0 * total_contacts / nullif(total_orders, 0))::numeric(12,4) AS contacts_per_1000_orders,
    (handling_cost_usd / nullif(total_orders, 0))::numeric(12,4) AS handling_cost_per_order,
    (fully_loaded_failure_cost_usd / nullif(total_orders, 0))::numeric(12,4) AS fully_loaded_failure_cost_per_order,
    (support_adjusted_contribution_usd / nullif(total_orders, 0))::numeric(12,4) AS support_adjusted_contribution_per_order,
    (ai_chat_contacts::numeric / nullif(total_contacts, 0))::numeric(12,4) AS ai_contact_share,
    (phone_contacts::numeric / nullif(total_contacts, 0))::numeric(12,4) AS phone_contact_share,
    (abandoned_contacts::numeric / nullif(total_contacts, 0))::numeric(12,4) AS abandonment_rate,
    (crm_resolved_contacts::numeric / nullif(total_contacts, 0))::numeric(12,4) AS crm_resolution_rate,
    (verified_resolved_contacts::numeric / nullif(total_contacts, 0))::numeric(12,4) AS verified_resolution_rate,
    (repeat_contact_orders::numeric / nullif(contacted_orders, 0))::numeric(12,4) AS repeat_contact_rate,
    avg_csat_score AS average_csat,
    (csat_response_count::numeric / nullif(total_contacts, 0))::numeric(12,4) AS csat_response_rate,
    (1000.0 * chargeback_count / nullif(total_orders, 0))::numeric(12,4) AS chargebacks_per_1000_orders,
    (cancelled_orders::numeric / nullif(total_orders, 0))::numeric(12,4) AS cancellation_rate,
    (late_orders::numeric / nullif(delivered_orders, 0))::numeric(12,4) AS late_delivery_rate,
    avg_promised_duration_min,
    handling_cost_usd,
    fully_loaded_failure_cost_usd,
    support_adjusted_contribution_usd
FROM mart.fct_city_week;

CREATE VIEW mart.fct_did_estimates AS
WITH metric_values AS (
    SELECT city, treatment_group, post_period, 'contacts_per_1000_orders' AS metric_name, contacts_per_1000_orders::numeric AS metric_value FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'handling_cost_per_order', handling_cost_per_order FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'fully_loaded_failure_cost_per_order', fully_loaded_failure_cost_per_order FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'support_adjusted_contribution_per_order', support_adjusted_contribution_per_order FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'verified_resolution_rate', verified_resolution_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'crm_resolution_rate', crm_resolution_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'abandonment_rate', abandonment_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'repeat_contact_rate', repeat_contact_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'chargebacks_per_1000_orders', chargebacks_per_1000_orders FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'average_csat', average_csat FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'csat_response_rate', csat_response_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'cancellation_rate', cancellation_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT city, treatment_group, post_period, 'late_delivery_rate', late_delivery_rate FROM mart.fct_weekly_kpis
), period_means AS (
    SELECT
        metric_name,
        avg(metric_value) FILTER (WHERE treatment_group = 'treatment' AND NOT post_period) AS treated_pre,
        avg(metric_value) FILTER (WHERE treatment_group = 'treatment' AND post_period) AS treated_post,
        avg(metric_value) FILTER (WHERE treatment_group = 'control' AND NOT post_period) AS control_pre,
        avg(metric_value) FILTER (WHERE treatment_group = 'control' AND post_period) AS control_post
    FROM metric_values
    GROUP BY metric_name
)
SELECT
    p.metric_name,
    c.display_name,
    c.metric_type,
    c.direction_of_good,
    p.treated_pre::numeric(14,6),
    p.treated_post::numeric(14,6),
    p.control_pre::numeric(14,6),
    p.control_post::numeric(14,6),
    ((p.treated_post - p.treated_pre) - (p.control_post - p.control_pre))::numeric(14,6) AS did_effect,
    (
        ((p.treated_post - p.treated_pre) - (p.control_post - p.control_pre))
        / nullif(abs(p.treated_pre), 0)
    )::numeric(14,6) AS did_effect_relative_to_treated_pre
FROM period_means p
LEFT JOIN mart.dim_metric c USING (metric_name);

CREATE VIEW mart.fct_executive_scorecard AS
SELECT
    metric_name,
    display_name,
    metric_type,
    direction_of_good,
    treated_pre,
    treated_post,
    control_pre,
    control_post,
    did_effect,
    did_effect_relative_to_treated_pre,
    CASE
        WHEN direction_of_good = 'up' AND did_effect > 0 THEN 'improved'
        WHEN direction_of_good = 'up' AND did_effect < 0 THEN 'worsened'
        WHEN direction_of_good = 'down' AND did_effect < 0 THEN 'improved'
        WHEN direction_of_good = 'down' AND did_effect > 0 THEN 'worsened'
        ELSE 'diagnostic_only'
    END AS directional_assessment
FROM mart.fct_did_estimates;

CREATE VIEW mart.fct_event_study AS
WITH metric_values AS (
    SELECT order_week, treatment_group, 'contacts_per_1000_orders'::text AS metric_name, contacts_per_1000_orders::numeric AS metric_value FROM mart.fct_weekly_kpis
    UNION ALL SELECT order_week, treatment_group, 'handling_cost_per_order', handling_cost_per_order FROM mart.fct_weekly_kpis
    UNION ALL SELECT order_week, treatment_group, 'fully_loaded_failure_cost_per_order', fully_loaded_failure_cost_per_order FROM mart.fct_weekly_kpis
    UNION ALL SELECT order_week, treatment_group, 'verified_resolution_rate', verified_resolution_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT order_week, treatment_group, 'abandonment_rate', abandonment_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT order_week, treatment_group, 'repeat_contact_rate', repeat_contact_rate FROM mart.fct_weekly_kpis
    UNION ALL SELECT order_week, treatment_group, 'chargebacks_per_1000_orders', chargebacks_per_1000_orders FROM mart.fct_weekly_kpis
    UNION ALL SELECT order_week, treatment_group, 'average_csat', average_csat FROM mart.fct_weekly_kpis
), weekly_group_means AS (
    SELECT
        metric_name,
        order_week,
        avg(metric_value) FILTER (WHERE treatment_group = 'treatment') AS treated_mean,
        avg(metric_value) FILTER (WHERE treatment_group = 'control') AS control_mean
    FROM metric_values
    GROUP BY metric_name, order_week
), gaps AS (
    SELECT *, treated_mean - control_mean AS treated_control_gap
    FROM weekly_group_means
), reference AS (
    SELECT metric_name, treated_control_gap AS week_6_gap
    FROM gaps
    WHERE order_week = 6
)
SELECT
    g.metric_name,
    g.order_week,
    g.treated_mean::numeric(14,6),
    g.control_mean::numeric(14,6),
    g.treated_control_gap::numeric(14,6),
    (g.treated_control_gap - r.week_6_gap)::numeric(14,6) AS gap_net_of_week_6
FROM gaps g
JOIN reference r USING (metric_name);

CREATE VIEW mart.fct_promo_exposure AS
SELECT
    treatment_group,
    order_week,
    sum(total_orders) AS total_orders,
    sum(freedel_orders) AS freedel_orders,
    (sum(freedel_orders)::numeric / nullif(sum(total_orders), 0))::numeric(12,4) AS freedel_order_share,
    'Descriptive balance check; the promotion is a post-launch national shock.'::text AS interpretation
FROM mart.fct_city_week
GROUP BY treatment_group, order_week;

CREATE VIEW mart.fct_negative_control AS
SELECT
    treatment_group,
    post_period,
    avg(avg_promised_duration_min)::numeric(12,4) AS avg_promised_duration_min,
    'Promised duration is set before support contact and should not respond to the contact-policy change.'::text AS rationale
FROM mart.fct_city_week
GROUP BY treatment_group, post_period;

CREATE VIEW mart.fct_containment_reconciliation AS
SELECT
    treatment_group,
    post_period,
    sum(total_contacts) AS contacts,
    (sum(crm_resolved_contacts)::numeric / nullif(sum(total_contacts), 0))::numeric(12,4) AS crm_reported_resolution_rate,
    (sum(verified_resolved_contacts)::numeric / nullif(sum(total_contacts), 0))::numeric(12,4) AS verified_no_repeat_resolution_rate,
    (
        sum(crm_resolved_contacts)::numeric / nullif(sum(total_contacts), 0)
        - sum(verified_resolved_contacts)::numeric / nullif(sum(total_contacts), 0)
    )::numeric(12,4) AS optimism_gap
FROM mart.fct_city_week
GROUP BY treatment_group, post_period;

CREATE VIEW mart.fct_loyalty_guardrails AS
SELECT
    treatment_group,
    post_period,
    count(*) FILTER (WHERE eligible_28d_reorder) AS mature_issue_episodes,
    count(*) FILTER (WHERE eligible_28d_reorder AND reordered_within_28d) AS reordered_28d_episodes,
    (
        count(*) FILTER (WHERE eligible_28d_reorder AND reordered_within_28d)::numeric
        / nullif(count(*) FILTER (WHERE eligible_28d_reorder), 0)
    )::numeric(12,4) AS observed_28d_reorder_rate,
    avg(days_to_next_order) FILTER (WHERE eligible_28d_reorder AND reordered_within_28d)::numeric(12,2) AS avg_days_to_next_order,
    count(*) FILTER (WHERE NOT eligible_28d_reorder) AS right_censored_episodes
FROM mart.fct_customer_issue_episode
GROUP BY treatment_group, post_period;

CREATE VIEW mart.fct_loyalty_did AS
WITH period_rates AS (
    SELECT
        treatment_group,
        post_period,
        observed_28d_reorder_rate
    FROM mart.fct_loyalty_guardrails
)
SELECT
    max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'treatment' AND NOT post_period) AS treated_pre,
    max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'treatment' AND post_period) AS treated_post,
    max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'control' AND NOT post_period) AS control_pre,
    max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'control' AND post_period) AS control_post,
    (
        max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'treatment' AND post_period)
        - max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'treatment' AND NOT post_period)
        - max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'control' AND post_period)
        + max(observed_28d_reorder_rate) FILTER (WHERE treatment_group = 'control' AND NOT post_period)
    )::numeric(12,4) AS did_effect,
    'Only mature issue episodes are included; post-period evidence is limited to early cohorts.'::text AS caveat
FROM period_rates;

CREATE VIEW mart.fct_modeled_loyalty_scenario AS
SELECT
    treatment_group,
    avg(modeled_90d_churn_probability)::numeric(12,6) AS modeled_90d_churn_probability,
    true AS simulated_not_observed,
    'Scenario evidence only; do not treat as a measured outcome.'::text AS mandatory_label
FROM mart.fct_customer_summary
GROUP BY treatment_group;

CREATE VIEW mart.fct_metric_relationships AS
SELECT
    'handling_cost_per_order vs abandonment_rate'::text AS relationship,
    corr(handling_cost_per_order, abandonment_rate)::numeric(12,6) AS pearson_correlation,
    count(*) AS city_weeks,
    'Descriptive association, not causal proof.'::text AS interpretation_limit
FROM mart.fct_weekly_kpis
UNION ALL
SELECT
    'handling_cost_per_order vs chargebacks_per_1000_orders',
    corr(handling_cost_per_order, chargebacks_per_1000_orders)::numeric(12,6),
    count(*),
    'Descriptive association, not causal proof.'
FROM mart.fct_weekly_kpis
UNION ALL
SELECT
    'verified_resolution_rate vs average_csat',
    corr(verified_resolution_rate, average_csat)::numeric(12,6),
    count(*),
    'CSAT is respondent-only and may be selected.'
FROM mart.fct_weekly_kpis
UNION ALL
SELECT
    'repeat_contact_rate vs chargebacks_per_1000_orders',
    corr(repeat_contact_rate, chargebacks_per_1000_orders)::numeric(12,6),
    count(*),
    'Finance lag and common issue severity can affect both metrics.'
FROM mart.fct_weekly_kpis;

CREATE VIEW mart.fct_finance_maturity_curve AS
SELECT
    order_week,
    treatment_group,
    chargebacks_total,
    chargebacks_posted_7d,
    chargebacks_posted_14d,
    chargebacks_posted_21d,
    chargebacks_posted_28d,
    (chargebacks_posted_7d::numeric / nullif(chargebacks_total, 0))::numeric(12,4) AS pct_visible_by_7d,
    (chargebacks_posted_14d::numeric / nullif(chargebacks_total, 0))::numeric(12,4) AS pct_visible_by_14d,
    (chargebacks_posted_21d::numeric / nullif(chargebacks_total, 0))::numeric(12,4) AS pct_visible_by_21d,
    (chargebacks_posted_28d::numeric / nullif(chargebacks_total, 0))::numeric(12,4) AS pct_visible_by_28d,
    avg_chargeback_lag_days
FROM mart.fct_finance_maturity;

CREATE VIEW mart.fct_data_trust AS
SELECT
    check_name,
    affected_rows,
    severity,
    handling_note,
    CASE WHEN severity = 'error' AND affected_rows > 0 THEN 'fail' ELSE 'disclosed_and_handled' END AS trust_status
FROM mart.fct_data_quality;

CREATE VIEW mart.fct_source_mapping_summary AS
SELECT
    'support contacts'::text AS source_name,
    'exact order match'::text AS mapping_status,
    count(*) FILTER (WHERE attribution_method = 'exact_order_reference') AS record_count,
    true AS included_in_order_economics,
    'Contact supplied a valid order reference.'::text AS explanation
FROM intermediate.int_contacts_enriched
UNION ALL
SELECT
    'support contacts',
    'customer and time match',
    count(*) FILTER (WHERE attribution_method = 'customer_time_proximity'),
    true,
    'Contact lacked a usable order reference and was linked through a trusted customer map plus time proximity.'
FROM intermediate.int_contacts_enriched
UNION ALL
SELECT
    'support contacts',
    'not linked to an order',
    count(*) FILTER (WHERE attributed_order_id IS NULL),
    false,
    'Contact remains in volume reporting but its handling cost cannot be joined to order or finance outcomes.'
FROM intermediate.int_contacts_enriched
UNION ALL
SELECT
    'finance ledger',
    'exact order match',
    count(*) FILTER (WHERE o.order_id IS NOT NULL),
    true,
    'Refund, credit, payment-dispute, and fee rows supplied a valid order ID.'
FROM staging.stg_finance f
LEFT JOIN staging.stg_orders o USING (order_id)
UNION ALL
SELECT
    'finance ledger',
    'not linked to an order',
    count(*) FILTER (WHERE o.order_id IS NULL),
    false,
    'Unmatched finance rows would be excluded from order-level economics.'
FROM staging.stg_finance f
LEFT JOIN staging.stg_orders o USING (order_id);

CREATE TABLE mart.dim_recommendation_option (
    option_id integer PRIMARY KEY,
    option_name text NOT NULL,
    action text NOT NULL,
    expected_benefit text NOT NULL,
    risk text NOT NULL,
    measurement_plan text NOT NULL,
    recommended boolean NOT NULL
);

INSERT INTO mart.dim_recommendation_option VALUES
(1, 'Continue unchanged', 'Keep phone hidden and AI as the default in all treatment cities.', 'Maximizes visible contact deflection and direct handling savings.', 'Locks in abandonment, repeat-contact, chargeback, and loyalty risk.', 'Monitor the complete scorecard for four more mature weeks.', false),
(2, 'Guardrailed AI-first', 'Keep AI as the front door for eligible intents, restore obvious human escalation for high-severity or failed journeys, and preserve context at handoff.', 'Retains low-cost automation while reducing suppressed demand and downstream failure cost.', 'Some direct cost savings will be given back; routing logic must be maintained.', 'Randomized city or customer holdout with non-inferiority guardrails for verified resolution, chargebacks, CSAT, and 28-day reorder.', true),
(3, 'Full rollback', 'Restore the original channel experience in treatment cities.', 'Rapidly reduces access friction and operational risk.', 'Forfeits valid AI containment and prevents learning which intents are safe to automate.', 'Use as a temporary safety action only if guardrail thresholds breach materially.', false);

CREATE TABLE mart.dim_monitoring_rule (
    signal_name text PRIMARY KEY,
    cadence text NOT NULL,
    threshold text NOT NULL,
    automated_action text NOT NULL,
    owner text NOT NULL
);

INSERT INTO mart.dim_monitoring_rule VALUES
('source freshness and row-count anomalies', 'daily', 'Missing batch or >20% deviation from trailing four-week weekday baseline', 'Page data owner and freeze executive scorecard refresh', 'Data platform'),
('contact attribution rate', 'daily', '<95% exact or trusted temporal attribution', 'Quarantine affected batch and open source-mapping incident', 'Customer care analytics'),
('verified resolution', 'daily with weekly decisioning', '>3 percentage point degradation versus concurrent holdout', 'Disable affected AI intent and restore human path', 'Care product'),
('chargebacks per 1,000 orders', 'weekly after 28-day maturity', '>10% relative increase versus holdout', 'Pause expansion and review failed issue journeys', 'Finance risk'),
('support-adjusted contribution per order', 'weekly after finance maturity', 'Negative treatment effect for two mature cohorts', 'Escalate to operating review', 'Product finance'),
('28-day reorder after issue', 'weekly after maturity', '>2 percentage point non-inferiority breach', 'Stop rollout and inspect loyalty segments', 'Loyalty analytics'),
('CSAT response and mix', 'weekly', '>20% response-rate shift or major channel-mix change', 'Mark CSAT trend as non-comparable', 'CX insights');

CREATE TABLE mart.dim_model_lineage (
    model_name text PRIMARY KEY,
    model_layer text NOT NULL,
    grain text NOT NULL,
    upstream_models text NOT NULL,
    purpose text NOT NULL
);

INSERT INTO mart.dim_model_lineage VALUES
('staging.stg_orders', 'staging', 'order', 'raw.orders_ops', 'Type, normalize, and reconcile source-system duration units and status codes.'),
('staging.stg_contacts', 'staging', 'contact', 'raw.support_contacts', 'Deduplicate extracts and standardize references, channels, and survey scores.'),
('staging.stg_finance', 'staging', 'ledger entry', 'raw.finance_ledger', 'Normalize money and preserve signed and cost-oriented representations.'),
('intermediate.int_contacts_enriched', 'intermediate', 'contact', 'staging.stg_contacts; staging.stg_orders; staging.stg_customer_map', 'Attribute contacts and calculate verified resolution and handling cost.'),
('intermediate.int_order_outcomes', 'intermediate', 'order', 'staging.stg_orders; contact summary; finance summary', 'Create the traceable order-level analytical spine.'),
('mart.fct_city_week', 'mart', 'city-week', 'intermediate.int_order_outcomes', 'Provide the experimental panel and executive economics.'),
('mart.fct_customer_issue_episode', 'mart', 'issue order', 'intermediate.int_order_outcomes', 'Measure mature reorder behavior and censor late episodes.'),
('mart.fct_did_estimates', 'mart', 'metric', 'mart.fct_weekly_kpis', 'Estimate treatment effect net of common pre/post movement.'),
('mart.fct_executive_scorecard', 'mart', 'metric', 'mart.fct_did_estimates; mart.dim_metric', 'Connect causal estimates to decision direction and guardrail role.');

CREATE TABLE mart.dim_experiment_contract (
    contract_key text PRIMARY KEY,
    contract_value text NOT NULL,
    rationale text NOT NULL
);

INSERT INTO mart.dim_experiment_contract VALUES
('synthetic_seed', '20261106', 'Makes every source extract reproducible.'),
('pre_period', 'weeks 1-6', 'Six full weeks before the intervention.'),
('post_period', 'weeks 7-12', 'Launch week through the end of supplied order data.'),
('launch_timestamp', '2026-07-13 00:00 local', 'Monday start of case-study week 7.'),
('treatment_unit', 'city', 'Policy assignment occurs at city level.'),
('primary_estimand', 'equal-city-weighted difference-in-differences', 'Transparent treatment versus control change; order-weighted sensitivity remains a presentation appendix option.'),
('finance_maturity', '28 days minimum; 30-day decision window', 'Chargebacks post after the originating order.'),
('loyalty_maturity', '28 days', 'Later issue cohorts are right-censored.'),
('causal_claim', 'directional quasi-experimental evidence', 'Eight non-randomized city clusters do not support randomized-trial certainty.');

CREATE TABLE audit.build_metadata AS
SELECT
    'forkdash_marts_v1'::text AS model_version,
    20261106::integer AS synthetic_seed,
    current_timestamp AS built_at,
    date '2026-09-20' AS finance_data_as_of,
    date '2026-08-23' AS approximate_order_data_end,
    'data/raw/manifest.json'::text AS source_manifest,
    current_database() AS database_name,
    version() AS postgres_version;

CREATE VIEW mart.fct_ai_issue_scorecard AS
SELECT
    treatment_group,
    post_period,
    issue_type,
    issue_severity,
    count(*) AS ai_starts,
    (count(*) FILTER (WHERE technical_ai_containment_flag)::numeric / nullif(count(*), 0))::numeric(12,4) AS technical_containment_rate,
    (count(*) FILTER (WHERE verified_ai_containment_flag)::numeric / nullif(count(*), 0))::numeric(12,4) AS verified_containment_rate,
    (count(*) FILTER (WHERE escalation_created_ts IS NOT NULL)::numeric / nullif(count(*), 0))::numeric(12,4) AS escalation_rate,
    (count(*) FILTER (WHERE queue_abandonment_flag)::numeric / nullif(count(*) FILTER (WHERE queue_entered_ts IS NOT NULL), 0))::numeric(12,4) AS queue_abandonment_rate,
    (count(*) FILTER (WHERE handoff_completed_flag)::numeric / nullif(count(*) FILTER (WHERE escalation_created_ts IS NOT NULL), 0))::numeric(12,4) AS handoff_completion_rate,
    (count(*) FILTER (WHERE human_request_honored_flag)::numeric / nullif(count(*) FILTER (WHERE human_requested_ts IS NOT NULL), 0))::numeric(12,4) AS human_request_honor_rate,
    (count(*) FILTER (WHERE has_followup_contact_7d)::numeric / nullif(count(*), 0))::numeric(12,4) AS repeat_contact_rate_7d,
    avg(csat_score)::numeric(10,4) AS avg_respondent_csat,
    (count(csat_score)::numeric / nullif(count(*), 0))::numeric(12,4) AS csat_response_rate,
    (count(DISTINCT order_id) FILTER (WHERE order_chargeback_count > 0)::numeric / nullif(count(DISTINCT order_id), 0))::numeric(12,4) AS order_chargeback_rate,
    (sum(handling_cost_usd) / nullif(count(*) FILTER (WHERE verified_ai_containment_flag), 0))::numeric(12,4) AS handling_cost_per_verified_ai_resolution,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY ai_minutes_before_escalation)
        FILTER (WHERE ai_minutes_before_escalation IS NOT NULL)::numeric(12,4) AS p50_ai_minutes_before_escalation,
    percentile_cont(0.9) WITHIN GROUP (ORDER BY ai_minutes_before_escalation)
        FILTER (WHERE ai_minutes_before_escalation IS NOT NULL)::numeric(12,4) AS p90_ai_minutes_before_escalation,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY escalation_to_first_response_min)
        FILTER (WHERE escalation_to_first_response_min IS NOT NULL)::numeric(12,4) AS p50_escalation_to_first_response_min,
    percentile_cont(0.9) WITHIN GROUP (ORDER BY escalation_to_first_response_min)
        FILTER (WHERE escalation_to_first_response_min IS NOT NULL)::numeric(12,4) AS p90_escalation_to_first_response_min,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY total_resolution_time_min)
        FILTER (WHERE total_resolution_time_min IS NOT NULL)::numeric(12,4) AS p50_total_resolution_time_min,
    percentile_cont(0.9) WITHIN GROUP (ORDER BY total_resolution_time_min)
        FILTER (WHERE total_resolution_time_min IS NOT NULL)::numeric(12,4) AS p90_total_resolution_time_min
FROM mart.fct_contact_journey
WHERE channel = 'ai_chat'
  AND order_id IS NOT NULL
GROUP BY treatment_group, post_period, issue_type, issue_severity;

CREATE VIEW mart.fct_handoff_funnel AS
SELECT
    treatment_group,
    post_period,
    count(*) AS ai_starts,
    count(*) FILTER (WHERE ai_failed_ts IS NOT NULL) AS ai_failures,
    count(*) FILTER (WHERE human_requested_ts IS NOT NULL) AS human_requests,
    count(*) FILTER (WHERE escalation_created_ts IS NOT NULL) AS escalations_created,
    count(*) FILTER (WHERE queue_entered_ts IS NOT NULL) AS queue_entries,
    count(*) FILTER (WHERE agent_accepted_ts IS NOT NULL) AS agent_acceptances,
    count(*) FILTER (WHERE first_human_response_ts IS NOT NULL) AS first_human_responses,
    count(*) FILTER (WHERE resolved_ts IS NOT NULL AND first_human_response_ts IS NOT NULL) AS human_resolutions,
    count(*) FILTER (WHERE queue_abandonment_flag) AS queue_abandonments,
    count(*) FILTER (WHERE has_followup_contact_7d) AS contacts_with_repeat_7d,
    (count(*) FILTER (WHERE escalation_created_ts IS NOT NULL)::numeric / nullif(count(*) FILTER (WHERE ai_failed_ts IS NOT NULL), 0))::numeric(12,4) AS failure_to_escalation_rate,
    (count(*) FILTER (WHERE first_human_response_ts IS NOT NULL)::numeric / nullif(count(*) FILTER (WHERE escalation_created_ts IS NOT NULL), 0))::numeric(12,4) AS handoff_completion_rate,
    (count(*) FILTER (WHERE queue_abandonment_flag)::numeric / nullif(count(*) FILTER (WHERE queue_entered_ts IS NOT NULL), 0))::numeric(12,4) AS queue_abandonment_rate,
    (count(*) FILTER (WHERE human_request_honored_flag)::numeric / nullif(count(*) FILTER (WHERE human_requested_ts IS NOT NULL), 0))::numeric(12,4) AS human_request_honor_rate,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY escalation_to_first_response_min)
        FILTER (WHERE escalation_to_first_response_min IS NOT NULL)::numeric(12,4) AS p50_escalation_to_first_response_min,
    percentile_cont(0.9) WITHIN GROUP (ORDER BY escalation_to_first_response_min)
        FILTER (WHERE escalation_to_first_response_min IS NOT NULL)::numeric(12,4) AS p90_escalation_to_first_response_min
FROM mart.fct_contact_journey
WHERE channel = 'ai_chat'
  AND treatment_group IS NOT NULL
GROUP BY treatment_group, post_period;

CREATE VIEW mart.fct_ai_handoff_did AS
WITH metric_values AS (
    SELECT treatment_group, post_period, 'handoff_completion_rate'::text AS metric_name, handoff_completion_rate::numeric AS metric_value FROM mart.fct_handoff_funnel
    UNION ALL SELECT treatment_group, post_period, 'queue_abandonment_rate', queue_abandonment_rate FROM mart.fct_handoff_funnel
    UNION ALL SELECT treatment_group, post_period, 'human_request_honor_rate', human_request_honor_rate FROM mart.fct_handoff_funnel
    UNION ALL SELECT treatment_group, post_period, 'p50_escalation_to_first_response_min', p50_escalation_to_first_response_min FROM mart.fct_handoff_funnel
    UNION ALL SELECT treatment_group, post_period, 'p90_escalation_to_first_response_min', p90_escalation_to_first_response_min FROM mart.fct_handoff_funnel
), pivoted AS (
    SELECT
        metric_name,
        max(metric_value) FILTER (WHERE treatment_group = 'treatment' AND NOT post_period) AS treated_pre,
        max(metric_value) FILTER (WHERE treatment_group = 'treatment' AND post_period) AS treated_post,
        max(metric_value) FILTER (WHERE treatment_group = 'control' AND NOT post_period) AS control_pre,
        max(metric_value) FILTER (WHERE treatment_group = 'control' AND post_period) AS control_post
    FROM metric_values
    GROUP BY metric_name
)
SELECT
    metric_name,
    treated_pre::numeric(14,6),
    treated_post::numeric(14,6),
    control_pre::numeric(14,6),
    control_post::numeric(14,6),
    ((treated_post - treated_pre) - (control_post - control_pre))::numeric(14,6) AS did_effect
FROM pivoted;

CREATE VIEW mart.fct_wait_time_outcomes AS
WITH banded AS (
    SELECT
        *,
        CASE
            WHEN first_human_response_ts IS NULL THEN 'no_human_response'
            WHEN escalation_to_first_response_min <= 2 THEN '00_0_to_2_min'
            WHEN escalation_to_first_response_min <= 5 THEN '01_2_to_5_min'
            WHEN escalation_to_first_response_min <= 10 THEN '02_5_to_10_min'
            ELSE '03_over_10_min'
        END AS wait_time_band
    FROM mart.fct_contact_journey
    WHERE channel = 'ai_chat'
      AND escalation_created_ts IS NOT NULL
)
SELECT
    treatment_group,
    post_period,
    wait_time_band,
    count(*) AS escalated_contacts,
    (count(*) FILTER (WHERE queue_abandonment_flag)::numeric / nullif(count(*), 0))::numeric(12,4) AS queue_abandonment_rate,
    (count(*) FILTER (WHERE has_followup_contact_7d)::numeric / nullif(count(*), 0))::numeric(12,4) AS repeat_contact_rate_7d,
    avg(csat_score)::numeric(10,4) AS avg_respondent_csat,
    (count(csat_score)::numeric / nullif(count(*), 0))::numeric(12,4) AS csat_response_rate,
    (count(DISTINCT order_id) FILTER (WHERE order_chargeback_count > 0)::numeric / nullif(count(DISTINCT order_id), 0))::numeric(12,4) AS order_chargeback_rate
FROM banded
GROUP BY treatment_group, post_period, wait_time_band;

CREATE TABLE mart.dim_team_metric (
    team_name text NOT NULL,
    metric_name text NOT NULL,
    metric_role text NOT NULL,
    business_question text NOT NULL,
    governed_source text NOT NULL,
    decision_use text NOT NULL,
    PRIMARY KEY (team_name, metric_name)
);

INSERT INTO mart.dim_team_metric VALUES
('Executive', 'support_adjusted_contribution_per_order', 'north_star', 'Did the policy create more economic value per order after all observed failure costs?', 'mart.fct_executive_scorecard', 'Scale only when positive and every hard guardrail passes.'),
('COO', 'handling_cost_per_order', 'driver', 'Did direct support become cheaper?', 'mart.fct_executive_scorecard', 'Operational efficiency, never standalone success.'),
('COO', 'contacts_per_1000_orders', 'diagnostic', 'Did observable support demand change after normalizing for order volume?', 'mart.fct_executive_scorecard', 'Interpret with abandonment and downstream outcomes.'),
('Customer Care', 'verified_resolution_rate', 'hard_guardrail', 'Did the customer stay resolved for seven days?', 'mart.fct_executive_scorecard', 'Stop or redesign if the non-inferiority bound is breached.'),
('Customer Care', 'repeat_contact_rate', 'hard_guardrail', 'Did customers need to return for help?', 'mart.fct_executive_scorecard', 'Diagnose false resolution and long-tail workload.'),
('Customer Care', 'abandonment_rate', 'hard_guardrail', 'Did customers give up before resolution?', 'mart.fct_executive_scorecard', 'Detect suppressed demand.'),
('CX Insights', 'average_csat', 'guardrail', 'How satisfied were survey respondents?', 'mart.fct_executive_scorecard', 'Always pair with response rate and channel mix.'),
('Finance', 'fully_loaded_failure_cost_per_order', 'primary_finance', 'What did handling, recovery, disputes, and fees cost per order?', 'mart.fct_executive_scorecard', 'Compare only mature cohorts.'),
('Finance', 'chargebacks_per_1000_orders', 'hard_guardrail', 'Did customers bypass support and dispute more orders?', 'mart.fct_executive_scorecard', 'Stop rollout when mature relative increase exceeds tolerance.'),
('Loyalty', 'observed_28d_reorder_rate', 'hard_guardrail', 'Did customers with an issue order again within 28 days?', 'mart.fct_loyalty_did', 'Use mature cohorts only.'),
('AI Product', 'verified_containment_rate', 'primary_ai', 'Which issues did AI durably resolve without human help?', 'mart.fct_ai_issue_scorecard', 'Determine intent eligibility.'),
('AI Product', 'technical_containment_rate', 'diagnostic', 'Which AI contacts avoided a human transfer?', 'mart.fct_ai_issue_scorecard', 'Never equate with resolution.'),
('AI Product', 'human_request_honor_rate', 'hard_guardrail', 'Did customers asking for a human actually receive one?', 'mart.fct_ai_issue_scorecard', 'Restore visible escalation when breached.'),
('Care Operations', 'handoff_completion_rate', 'hard_guardrail', 'Did an AI escalation lead to a human response?', 'mart.fct_handoff_funnel', 'Separate transfer creation from successful service.'),
('Care Operations', 'queue_abandonment_rate', 'hard_guardrail', 'Did customers abandon while waiting for an agent?', 'mart.fct_handoff_funnel', 'Diagnose staffing and routing failures.'),
('Care Operations', 'p90_escalation_to_first_response_min', 'service_level', 'How long did the slowest common handoffs wait for a human?', 'mart.fct_handoff_funnel', 'Use percentiles, not only averages.'),
('Data', 'contact_attribution_rate', 'trust_gate', 'Can contacts be traced to orders and customers?', 'audit.test_results', 'Freeze causal scorecard if coverage falls below 95%.'),
('Data', 'finance_maturity', 'trust_gate', 'Have delayed disputes had enough time to arrive?', 'mart.fct_finance_maturity_curve', 'Recent cohorts remain provisional.');

CREATE VIEW mart.fct_launch_decision AS
SELECT
    'Executive'::text AS owner,
    'support_adjusted_contribution_per_order'::text AS metric_name,
    did_effect AS observed_effect,
    0.05::numeric AS threshold,
    'effect >= threshold'::text AS rule,
    CASE WHEN did_effect >= 0.05 THEN 'PASS' ELSE 'FAIL' END AS status,
    'mart.fct_did_estimates'::text AS evidence_source
FROM mart.fct_did_estimates WHERE metric_name = 'support_adjusted_contribution_per_order'
UNION ALL
SELECT 'Customer Care', 'verified_resolution_rate', did_effect, -0.03, 'effect >= threshold', CASE WHEN did_effect >= -0.03 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_did_estimates'
FROM mart.fct_did_estimates WHERE metric_name = 'verified_resolution_rate'
UNION ALL
SELECT 'Customer Care', 'repeat_contact_rate', did_effect, 0.02, 'effect <= threshold', CASE WHEN did_effect <= 0.02 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_did_estimates'
FROM mart.fct_did_estimates WHERE metric_name = 'repeat_contact_rate'
UNION ALL
SELECT 'Customer Care', 'abandonment_rate', did_effect, 0.02, 'effect <= threshold', CASE WHEN did_effect <= 0.02 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_did_estimates'
FROM mart.fct_did_estimates WHERE metric_name = 'abandonment_rate'
UNION ALL
SELECT 'CX Insights', 'average_csat', did_effect, -0.20, 'effect >= threshold', CASE WHEN did_effect >= -0.20 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_did_estimates'
FROM mart.fct_did_estimates WHERE metric_name = 'average_csat'
UNION ALL
SELECT 'Finance', 'chargebacks_relative_change', did_effect_relative_to_treated_pre, 0.10, 'relative effect <= threshold', CASE WHEN did_effect_relative_to_treated_pre <= 0.10 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_did_estimates'
FROM mart.fct_did_estimates WHERE metric_name = 'chargebacks_per_1000_orders'
UNION ALL
SELECT 'Loyalty', 'observed_28d_reorder_rate', did_effect, -0.02, 'effect >= threshold', CASE WHEN did_effect >= -0.02 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_loyalty_did'
FROM mart.fct_loyalty_did
UNION ALL
SELECT 'Care Operations', 'handoff_completion_rate', did_effect, -0.03, 'effect >= threshold', CASE WHEN did_effect >= -0.03 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_ai_handoff_did'
FROM mart.fct_ai_handoff_did WHERE metric_name = 'handoff_completion_rate'
UNION ALL
SELECT 'Care Operations', 'queue_abandonment_rate', did_effect, 0.02, 'effect <= threshold', CASE WHEN did_effect <= 0.02 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_ai_handoff_did'
FROM mart.fct_ai_handoff_did WHERE metric_name = 'queue_abandonment_rate'
UNION ALL
SELECT 'Care Operations', 'p90_escalation_to_first_response_min', did_effect, 2.00, 'effect <= threshold minutes', CASE WHEN did_effect <= 2.00 THEN 'PASS' ELSE 'FAIL' END, 'mart.fct_ai_handoff_did'
FROM mart.fct_ai_handoff_did WHERE metric_name = 'p90_escalation_to_first_response_min';

CREATE VIEW mart.fct_launch_decision_summary AS
SELECT
    CASE
        WHEN count(*) FILTER (WHERE status = 'FAIL') > 0 THEN 'FAIL'
        WHEN count(*) FILTER (WHERE status = 'WAIT') > 0 THEN 'WAIT'
        ELSE 'PASS'
    END AS overall_status,
    count(*) FILTER (WHERE status = 'PASS') AS passed_metrics,
    count(*) FILTER (WHERE status = 'FAIL') AS failed_metrics,
    count(*) FILTER (WHERE status = 'WAIT') AS waiting_metrics,
    string_agg(metric_name, ', ' ORDER BY metric_name) FILTER (WHERE status = 'FAIL') AS failed_metric_names,
    'The north star must pass and no hard guardrail may fail.'::text AS decision_contract
FROM mart.fct_launch_decision;

CREATE TABLE mart.dim_number_provenance (
    metric_name text PRIMARY KEY,
    published_relation text NOT NULL,
    published_field text NOT NULL,
    grain text NOT NULL,
    upstream_models text NOT NULL,
    raw_sources text NOT NULL,
    drillthrough_key text NOT NULL,
    reproduction_query text NOT NULL
);

INSERT INTO mart.dim_number_provenance VALUES
('support_adjusted_contribution_per_order', 'mart.fct_did_estimates', 'did_effect', 'metric', 'mart.fct_weekly_kpis; mart.fct_city_week; intermediate.int_order_outcomes', 'raw.orders_ops; raw.support_contacts; raw.finance_ledger', 'city + order_week -> order_id -> contact_id / ledger_id', 'SELECT * FROM mart.fct_did_estimates WHERE metric_name = ''support_adjusted_contribution_per_order'';'),
('handling_cost_per_order', 'mart.fct_did_estimates', 'did_effect', 'metric', 'mart.fct_weekly_kpis; mart.fct_city_week', 'raw.orders_ops; raw.support_contacts', 'city + order_week -> order_id -> contact_id', 'SELECT * FROM mart.fct_did_estimates WHERE metric_name = ''handling_cost_per_order'';'),
('verified_resolution_rate', 'mart.fct_did_estimates', 'did_effect', 'metric', 'intermediate.int_contacts_enriched; mart.fct_city_week', 'raw.support_contacts; raw.customer_map; raw.orders_ops', 'contact_id -> attributed_order_id', 'SELECT * FROM mart.fct_did_estimates WHERE metric_name = ''verified_resolution_rate'';'),
('chargebacks_per_1000_orders', 'mart.fct_did_estimates', 'did_effect', 'metric', 'staging.stg_finance; intermediate.int_order_finance_summary; mart.fct_city_week', 'raw.finance_ledger; raw.orders_ops', 'ledger_id -> order_id', 'SELECT * FROM mart.fct_did_estimates WHERE metric_name = ''chargebacks_per_1000_orders'';'),
('observed_28d_reorder_rate', 'mart.fct_loyalty_did', 'did_effect', 'metric', 'mart.fct_customer_issue_episode', 'raw.orders_ops; raw.order_issues', 'customer_id + order_id', 'SELECT * FROM mart.fct_loyalty_did;'),
('verified_containment_rate', 'mart.fct_ai_issue_scorecard', 'verified_containment_rate', 'group-period-issue', 'mart.fct_contact_journey; intermediate.int_contact_journey_funnel', 'raw.support_contacts; raw.support_journey_events; raw.order_issues', 'contact_id + conversation_id + order_id', 'SELECT * FROM mart.fct_ai_issue_scorecard ORDER BY treatment_group, post_period, issue_type;'),
('handoff_completion_rate', 'mart.fct_handoff_funnel', 'handoff_completion_rate', 'group-period', 'mart.fct_contact_journey', 'raw.support_journey_events; raw.support_contacts', 'contact_id + conversation_id', 'SELECT * FROM mart.fct_handoff_funnel ORDER BY treatment_group, post_period;'),
('p90_escalation_to_first_response_min', 'mart.fct_handoff_funnel', 'p90_escalation_to_first_response_min', 'group-period', 'intermediate.int_contact_journey_funnel', 'raw.support_journey_events', 'conversation_id + contact_id', 'SELECT * FROM mart.fct_handoff_funnel ORDER BY treatment_group, post_period;');

CREATE TABLE audit.assumption_registry (
    assumption_id text PRIMARY KEY,
    category text NOT NULL,
    assumption_text text NOT NULL,
    encoded_value text NOT NULL,
    sensitivity_or_limit text NOT NULL
);

INSERT INTO audit.assumption_registry VALUES
('A01', 'experiment', 'Treatment starts at the beginning of week 7 in four named cities.', '2026-07-13; four treatment cities', 'Assignment is not claimed to be randomized.'),
('A02', 'economics', 'Contribution margin equals 12% of order value.', '0.12', 'Provided case assumption.'),
('A03', 'economics', 'Handling costs follow the case brief.', 'AI-only 0.55; AI-agent 5.75; phone 6.80; email 3.10', 'Transferred AI cost is not double counted.'),
('A04', 'economics', 'Each chargeback has an 18 dollar fee in addition to disputed principal.', '18.00', 'Provided case assumption.'),
('A05', 'resolution', 'Durable resolution requires a resolved end state and no same-order follow-up within seven days.', '7 days', 'Sensitivity should test 72-hour and 14-day windows.'),
('A06', 'identity', 'Missing order references may use mapped customer identity plus temporal proximity.', 'order within -2 to +1 day of contact', 'Tagged 0.75 confidence and separable from exact matches.'),
('A07', 'loyalty', 'Observed loyalty proxy is another order within 28 days of an issue episode.', '28 days', 'Late cohorts are excluded as right-censored.'),
('A08', 'finance', 'Chargebacks are assigned to originating order cohorts.', 'order week', 'Posting date retained for reconciliation and maturity.'),
('A09', 'AI', 'Technical containment means no human transfer; verified containment also requires durable resolution.', 'two separate metrics', 'Abandonment is never counted as verified containment.'),
('A10', 'handoff', 'Successful handoff requires an escalation and a first human response.', 'first_human_response_ts is not null', 'Agent acceptance alone is insufficient.'),
('A11', 'threshold', 'Illustrative decision thresholds are predeclared for the synthetic exercise.', 'mart.fct_launch_decision', 'Real leaders must approve tolerances before a live test.'),
('A12', 'privacy', 'All records are synthetic and remain local to this project.', 'seed 20261106', 'No case data is shared externally.');

INSERT INTO mart.dim_model_lineage VALUES
('staging.stg_order_issues', 'staging', 'issue', 'raw.order_issues', 'Separate actual order defects from whether a contact was successfully created.'),
('staging.stg_support_journey_events', 'staging', 'journey event', 'raw.support_journey_events', 'Type the AI, escalation, queue, agent, abandonment, and resolution event stream.'),
('intermediate.int_contact_journey_funnel', 'intermediate', 'contact', 'staging.stg_support_journey_events; intermediate.int_contacts_enriched', 'Create one traceable contact funnel with stage timestamps and elapsed times.'),
('mart.fct_contact_journey', 'mart', 'contact', 'intermediate.int_contact_journey_funnel; intermediate.int_order_outcomes', 'Join journey stages to downstream customer and finance outcomes.'),
('mart.fct_ai_issue_week', 'mart', 'city-week-issue-severity', 'mart.fct_contact_journey', 'Measure AI eligibility and handoff performance by issue mix.'),
('mart.fct_launch_decision', 'mart', 'decision metric', 'fact scorecards and predeclared thresholds', 'Return a transparent pass or fail for the north star and every hard guardrail.');
