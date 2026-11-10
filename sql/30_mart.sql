\set ON_ERROR_STOP on

CREATE TABLE mart.dim_week AS
SELECT
    week_number,
    date '2026-06-01' + ((week_number - 1) * 7) AS week_start_date,
    date '2026-06-01' + ((week_number - 1) * 7) + 6 AS week_end_date,
    (week_number >= 7) AS post_period,
    (week_number >= 8) AS freedel_promo_period
FROM generate_series(1, 15) AS week_number;

ALTER TABLE mart.dim_week ADD PRIMARY KEY (week_number);

CREATE TABLE mart.fct_city_week AS
SELECT
    o.city,
    o.city_code,
    o.treatment_group,
    o.order_week,
    min(o.order_ts)::date AS first_order_date,
    max(o.order_ts)::date AS last_order_date,
    o.post_period,
    bool_or(o.promo_code = 'FREEDEL') AS freedel_promo_observed,
    count(*) AS total_orders,
    count(*) FILTER (WHERE o.promo_code = 'FREEDEL') AS freedel_orders,
    count(*) FILTER (WHERE o.order_status = 'delivered') AS delivered_orders,
    count(*) FILTER (WHERE o.order_status = 'cancelled') AS cancelled_orders,
    count(*) FILTER (WHERE o.source_late_flag) AS late_orders,
    avg(o.promised_duration_min)::numeric(10,4) AS avg_promised_duration_min,
    sum(o.order_value_usd)::numeric(14,2) AS gross_order_value_usd,
    sum(o.contribution_margin_usd)::numeric(14,2) AS contribution_margin_usd,
    count(*) FILTER (WHERE o.contact_count > 0) AS contacted_orders,
    sum(o.contact_count) AS total_contacts,
    sum(o.ai_chat_contacts) AS ai_chat_contacts,
    sum(o.phone_contacts) AS phone_contacts,
    sum(o.email_contacts) AS email_contacts,
    sum(o.abandoned_contacts) AS abandoned_contacts,
    sum(o.crm_resolved_contacts) AS crm_resolved_contacts,
    sum(o.verified_resolved_contacts) AS verified_resolved_contacts,
    count(*) FILTER (WHERE o.repeat_contact_flag) AS repeat_contact_orders,
    sum(o.csat_response_count) AS csat_response_count,
    (
        sum(coalesce(o.avg_csat_score, 0) * o.csat_response_count)
        / nullif(sum(o.csat_response_count), 0)
    )::numeric(8,4) AS avg_csat_score,
    sum(o.handling_cost_usd)::numeric(14,2) AS handling_cost_usd,
    sum(o.refund_credit_cost_usd)::numeric(14,2) AS refund_credit_cost_usd,
    sum(o.chargeback_dispute_cost_usd)::numeric(14,2) AS chargeback_dispute_cost_usd,
    sum(o.chargeback_fee_cost_usd)::numeric(14,2) AS chargeback_fee_cost_usd,
    sum(o.chargeback_count) AS chargeback_count,
    (
        sum(o.handling_cost_usd)
        + sum(o.refund_credit_cost_usd)
        + sum(o.chargeback_dispute_cost_usd)
        + sum(o.chargeback_fee_cost_usd)
    )::numeric(14,2) AS fully_loaded_failure_cost_usd,
    (
        sum(o.contribution_margin_usd)
        - sum(o.handling_cost_usd)
        - sum(o.refund_credit_cost_usd)
        - sum(o.chargeback_dispute_cost_usd)
        - sum(o.chargeback_fee_cost_usd)
    )::numeric(14,2) AS support_adjusted_contribution_usd
FROM intermediate.int_order_outcomes o
GROUP BY o.city, o.city_code, o.treatment_group, o.order_week, o.post_period;

ALTER TABLE mart.fct_city_week ADD PRIMARY KEY (city, order_week);

CREATE TABLE mart.fct_customer_issue_episode AS
WITH sequenced AS (
    SELECT
        o.*,
        lead(o.order_ts) OVER (PARTITION BY o.customer_id ORDER BY o.order_ts) AS next_order_ts,
        max(o.order_ts) OVER () AS dataset_max_order_ts
    FROM intermediate.int_order_outcomes o
)
SELECT
    order_id,
    customer_id,
    city,
    treatment_group,
    order_week,
    order_ts,
    post_period,
    treated_post,
    observed_issue_type,
    contact_count,
    repeat_contact_flag,
    abandoned_contacts,
    handling_cost_usd,
    refund_credit_cost_usd,
    chargeback_dispute_cost_usd,
    chargeback_fee_cost_usd,
    next_order_ts,
    (order_ts <= dataset_max_order_ts - interval '28 days') AS eligible_28d_reorder,
    (
        order_ts <= dataset_max_order_ts - interval '28 days'
        AND next_order_ts IS NOT NULL
        AND next_order_ts <= order_ts + interval '28 days'
    ) AS reordered_within_28d,
    CASE
        WHEN order_ts <= dataset_max_order_ts - interval '28 days' AND next_order_ts IS NOT NULL
        THEN extract(day FROM (next_order_ts - order_ts))
    END AS days_to_next_order
FROM sequenced
WHERE observed_issue_type <> 'none' OR contact_count > 0;

ALTER TABLE mart.fct_customer_issue_episode ADD PRIMARY KEY (order_id);

CREATE TABLE mart.fct_customer_summary AS
SELECT
    o.customer_id,
    min(o.city) AS city,
    min(o.treatment_group) AS treatment_group,
    count(*) AS lifetime_orders_in_window,
    count(*) FILTER (WHERE o.post_period) AS post_orders,
    count(*) FILTER (WHERE o.observed_issue_type <> 'none') AS issue_orders,
    count(*) FILTER (WHERE o.contact_count > 0) AS contacted_orders,
    count(*) FILTER (WHERE o.repeat_contact_flag) AS repeat_contact_orders,
    sum(o.handling_cost_usd)::numeric(12,2) AS handling_cost_usd,
    sum(o.refund_credit_cost_usd + o.chargeback_dispute_cost_usd + o.chargeback_fee_cost_usd)::numeric(12,2) AS recovery_and_dispute_cost_usd,
    avg(s.modeled_90d_churn_probability)::numeric(8,6) AS modeled_90d_churn_probability,
    true AS modeled_loyalty_fields_are_simulated
FROM intermediate.int_order_outcomes o
LEFT JOIN staging.stg_loyalty_scenario s USING (customer_id)
GROUP BY o.customer_id;

ALTER TABLE mart.fct_customer_summary ADD PRIMARY KEY (customer_id);

CREATE TABLE mart.fct_finance_maturity AS
SELECT
    o.order_week,
    o.treatment_group,
    count(*) FILTER (WHERE f.entry_type = 'CHARGEBACK') AS chargebacks_total,
    count(*) FILTER (
        WHERE f.entry_type = 'CHARGEBACK'
          AND f.posted_date <= o.order_ts::date + 7
    ) AS chargebacks_posted_7d,
    count(*) FILTER (
        WHERE f.entry_type = 'CHARGEBACK'
          AND f.posted_date <= o.order_ts::date + 14
    ) AS chargebacks_posted_14d,
    count(*) FILTER (
        WHERE f.entry_type = 'CHARGEBACK'
          AND f.posted_date <= o.order_ts::date + 21
    ) AS chargebacks_posted_21d,
    count(*) FILTER (
        WHERE f.entry_type = 'CHARGEBACK'
          AND f.posted_date <= o.order_ts::date + 28
    ) AS chargebacks_posted_28d,
    (avg(f.posted_date - o.order_ts::date) FILTER (WHERE f.entry_type = 'CHARGEBACK'))::numeric(8,2) AS avg_chargeback_lag_days
FROM intermediate.int_order_outcomes o
LEFT JOIN staging.stg_finance f USING (order_id)
GROUP BY o.order_week, o.treatment_group;

ALTER TABLE mart.fct_finance_maturity ADD PRIMARY KEY (order_week, treatment_group);

CREATE TABLE mart.fct_data_quality AS
SELECT * FROM (
    VALUES
        ('raw_contact_duplicate_rows', (SELECT count(*) - count(DISTINCT contact_id) FROM raw.support_contacts), 'warning', 'Duplicate extract rows are deduplicated by latest source_updated_at.'),
        ('contacts_missing_order_reference', (SELECT count(*) FROM staging.stg_contacts WHERE order_ref_norm IS NULL), 'warning', 'Customer/time attribution is attempted when a trusted customer map exists.'),
        ('contacts_missing_customer_reference', (SELECT count(*) FROM staging.stg_contacts WHERE customer_ref_norm IS NULL), 'warning', 'Exact order references remain usable.'),
        ('unattributed_contacts', (SELECT count(*) FROM intermediate.int_contacts_enriched WHERE attributed_order_id IS NULL), 'warning', 'Excluded from order-level causal metrics; retained in volume trust reporting.'),
        ('low_confidence_contact_attributions', (SELECT count(*) FROM intermediate.int_contacts_enriched WHERE attribution_method = 'customer_time_proximity'), 'warning', 'Included in primary results and separable for sensitivity analysis.'),
        ('csat_nonresponses', (SELECT count(*) FROM staging.stg_contacts WHERE csat_score IS NULL), 'warning', 'CSAT is always paired with response rate.'),
        ('crm_resolution_disagreements', (SELECT count(*) FROM intermediate.int_contacts_enriched WHERE crm_resolved_flag <> verified_resolution_no_repeat_7d), 'warning', 'Verified resolution requires a resolved end state and no seven-day follow-up.'),
        ('invalid_order_values', (SELECT count(*) FROM staging.stg_orders WHERE order_value_usd <= 0), 'error', 'Must be zero.'),
        ('invalid_duration_values', (SELECT count(*) FROM staging.stg_orders WHERE promised_duration_min <= 0 OR delivery_duration_min < 0), 'error', 'Must be zero.'),
        ('issue_order_orphans', (SELECT count(*) FROM staging.stg_order_issues i LEFT JOIN staging.stg_orders o USING (order_id) WHERE o.order_id IS NULL), 'error', 'Every synthetic order issue must map to one order.'),
        ('contacts_missing_journey_stream', (SELECT count(*) FROM staging.stg_contacts c LEFT JOIN (SELECT DISTINCT contact_id FROM staging.stg_support_journey_events) e USING (contact_id) WHERE e.contact_id IS NULL), 'error', 'Every deduplicated contact must have an event stream.'),
        ('negative_journey_durations', (SELECT count(*) FROM intermediate.int_contact_journey_funnel WHERE coalesce(ai_minutes_before_escalation, 0) < 0 OR coalesce(queue_wait_to_accept_min, 0) < 0 OR coalesce(escalation_to_first_response_min, 0) < 0 OR coalesce(total_resolution_time_min, 0) < 0), 'error', 'All derived elapsed times must be non-negative.')
) AS quality_check(check_name, affected_rows, severity, handling_note);

ALTER TABLE mart.fct_data_quality ADD PRIMARY KEY (check_name);

CREATE TABLE mart.fct_contact_journey AS
SELECT
    j.contact_id,
    j.conversation_id,
    j.attributed_order_id AS order_id,
    j.attributed_customer_id AS customer_id,
    j.city,
    j.order_week,
    o.treatment_group,
    o.post_period,
    o.treated_post,
    coalesce(o.observed_issue_type, j.issue_type) AS issue_type,
    coalesce(o.issue_severity, 'unknown') AS issue_severity,
    j.channel,
    j.handling,
    j.ended_reason,
    j.crm_resolved_flag,
    j.verified_resolution_no_repeat_7d,
    j.has_followup_contact_7d,
    j.abandoned_flag,
    j.csat_score,
    j.handling_cost_usd,
    j.attribution_method,
    j.attribution_confidence,
    j.ai_started_ts,
    j.ai_failed_ts,
    j.human_requested_ts,
    j.escalation_created_ts,
    j.escalation_failed_ts,
    j.queue_entered_ts,
    j.agent_accepted_ts,
    j.first_human_response_ts,
    j.abandoned_ts,
    j.resolved_ts,
    j.queue_name,
    j.model_version,
    j.policy_version,
    j.ai_minutes_before_escalation,
    j.queue_wait_to_accept_min,
    j.escalation_to_first_response_min,
    j.contact_to_first_human_response_min,
    j.total_resolution_time_min,
    j.human_handling_time_min,
    j.handoff_completed_flag,
    j.human_request_honored_flag,
    j.queue_abandonment_flag,
    j.technical_ai_containment_flag,
    j.verified_ai_containment_flag,
    coalesce(o.refund_credit_cost_usd, 0)::numeric(12,2) AS order_refund_credit_cost_usd,
    coalesce(o.chargeback_dispute_cost_usd, 0)::numeric(12,2) AS order_chargeback_dispute_cost_usd,
    coalesce(o.chargeback_fee_cost_usd, 0)::numeric(12,2) AS order_chargeback_fee_cost_usd,
    coalesce(o.chargeback_count, 0) AS order_chargeback_count
FROM intermediate.int_contact_journey_funnel j
LEFT JOIN intermediate.int_order_outcomes o
    ON o.order_id = j.attributed_order_id;

ALTER TABLE mart.fct_contact_journey ADD PRIMARY KEY (contact_id);
CREATE INDEX mart_contact_journey_ai_idx ON mart.fct_contact_journey (channel, treatment_group, post_period, issue_type);

CREATE TABLE mart.fct_ai_issue_week AS
SELECT
    city,
    treatment_group,
    order_week,
    post_period,
    issue_type,
    issue_severity,
    count(*) AS ai_starts,
    count(*) FILTER (WHERE technical_ai_containment_flag) AS technical_containments,
    count(*) FILTER (WHERE verified_ai_containment_flag) AS verified_ai_containments,
    count(*) FILTER (WHERE human_requested_ts IS NOT NULL) AS human_requests,
    count(*) FILTER (WHERE escalation_created_ts IS NOT NULL) AS escalations_created,
    count(*) FILTER (WHERE escalation_failed_ts IS NOT NULL) AS escalation_failures,
    count(*) FILTER (WHERE first_human_response_ts IS NOT NULL) AS contacts_with_human_response,
    count(*) FILTER (WHERE handoff_completed_flag) AS completed_handoffs,
    count(*) FILTER (WHERE queue_abandonment_flag) AS queue_abandonments,
    count(*) FILTER (WHERE abandoned_flag) AS total_abandonments,
    count(*) FILTER (WHERE has_followup_contact_7d) AS contacts_with_followup_7d,
    count(*) FILTER (WHERE verified_resolution_no_repeat_7d) AS verified_resolutions,
    count(csat_score) AS csat_responses,
    avg(csat_score)::numeric(10,4) AS avg_csat,
    sum(handling_cost_usd)::numeric(14,2) AS handling_cost_usd,
    count(DISTINCT order_id) FILTER (WHERE order_chargeback_count > 0) AS orders_with_chargeback,
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
GROUP BY city, treatment_group, order_week, post_period, issue_type, issue_severity;

CREATE INDEX mart_ai_issue_week_idx ON mart.fct_ai_issue_week (treatment_group, post_period, issue_type, order_week);

ANALYZE mart.fct_city_week;
ANALYZE mart.fct_customer_issue_episode;
ANALYZE mart.fct_contact_journey;
ANALYZE mart.fct_ai_issue_week;
