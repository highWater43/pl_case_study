\set ON_ERROR_STOP on

CREATE TABLE staging.stg_orders AS
SELECT
    upper(trim(order_id)) AS order_id,
    upper(trim(customer_id)) AS customer_id,
    trim(city) AS city,
    lower(trim(src_system)) AS src_system,
    order_ts::timestamp AS order_ts,
    upper(trim(restaurant_id)) AS restaurant_id,
    replace(replace(trim(order_value), '$', ''), ',', '')::numeric(12,2) AS order_value_usd,
    CASE
        WHEN lower(trim(src_system)) = 'legacy_ops' THEN promised_duration::numeric / 60.0
        ELSE promised_duration::numeric
    END AS promised_duration_min,
    CASE
        WHEN lower(trim(src_system)) = 'legacy_ops' THEN delivery_duration::numeric / 60.0
        ELSE delivery_duration::numeric
    END AS delivery_duration_min,
    CASE upper(trim(status_code))
        WHEN 'DLV' THEN 'delivered'
        WHEN 'DELIVERED' THEN 'delivered'
        WHEN 'CXL' THEN 'cancelled'
        WHEN 'CANCELLED' THEN 'cancelled'
        ELSE 'unknown'
    END AS order_status,
    nullif(upper(trim(promo_code)), '') AS promo_code,
    extract_batch_id,
    loaded_at,
    1 + ((order_ts::date - date '2026-06-01') / 7) AS order_week,
    (delivery_duration::numeric > promised_duration::numeric AND upper(trim(status_code)) IN ('DLV', 'DELIVERED')) AS source_late_flag
FROM raw.orders_ops;

ALTER TABLE staging.stg_orders ADD PRIMARY KEY (order_id);
CREATE INDEX stg_orders_customer_ts_idx ON staging.stg_orders (customer_id, order_ts);
CREATE INDEX stg_orders_city_week_idx ON staging.stg_orders (city, order_week);

CREATE TABLE staging.stg_contacts AS
WITH ranked AS (
    SELECT
        *,
        row_number() OVER (
            PARTITION BY upper(trim(contact_id))
            ORDER BY source_updated_at::timestamp DESC, loaded_at DESC, ctid DESC
        ) AS row_rank,
        count(*) OVER (PARTITION BY upper(trim(contact_id))) AS source_row_count
    FROM raw.support_contacts
)
SELECT
    upper(trim(contact_id)) AS contact_id,
    nullif(upper(trim(customer_ref)), '') AS customer_ref_norm,
    nullif(upper(trim(order_ref)), '') AS order_ref_norm,
    contact_ts::timestamp AS contact_ts,
    CASE lower(trim(channel))
        WHEN 'ai chat' THEN 'ai_chat'
        WHEN 'ai_chat' THEN 'ai_chat'
        WHEN 'chat' THEN 'ai_chat'
        WHEN 'phone' THEN 'phone'
        WHEN 'voice' THEN 'phone'
        WHEN 'email' THEN 'email'
        WHEN 'mail' THEN 'email'
        ELSE 'unknown'
    END AS channel,
    lower(trim(issue_type)) AS issue_type,
    upper(trim(handling)) AS handling,
    upper(trim(ended_reason)) AS ended_reason,
    upper(trim(crm_resolved_flag)) IN ('Y', 'YES', 'TRUE', '1') AS crm_resolved_flag,
    CASE WHEN trim(csat_score) ~ '^[1-5](\.0)?$' THEN trim(csat_score)::numeric::integer END AS csat_score,
    extract_batch_id,
    source_updated_at::timestamp AS source_updated_at,
    source_row_count,
    loaded_at
FROM ranked
WHERE row_rank = 1;

ALTER TABLE staging.stg_contacts ADD PRIMARY KEY (contact_id);
CREATE INDEX stg_contacts_order_ref_idx ON staging.stg_contacts (order_ref_norm);
CREATE INDEX stg_contacts_customer_ts_idx ON staging.stg_contacts (customer_ref_norm, contact_ts);

CREATE TABLE staging.stg_finance AS
SELECT
    upper(trim(ledger_id)) AS ledger_id,
    upper(trim(order_id)) AS order_id,
    posted_date::date AS posted_date,
    replace(replace(trim(amount_usd), '$', ''), ',', '')::numeric(12,2) AS signed_amount_usd,
    abs(replace(replace(trim(amount_usd), '$', ''), ',', '')::numeric(12,2)) AS cost_amount_usd,
    upper(trim(entry_type)) AS entry_type,
    upper(trim(reason_code)) AS reason_code,
    extract_batch_id,
    loaded_at
FROM raw.finance_ledger;

ALTER TABLE staging.stg_finance ADD PRIMARY KEY (ledger_id);
CREATE INDEX stg_finance_order_idx ON staging.stg_finance (order_id);
CREATE INDEX stg_finance_posted_idx ON staging.stg_finance (posted_date);

CREATE TABLE staging.stg_customer_map AS
WITH ranked AS (
    SELECT
        upper(trim(crm_customer_ref)) AS crm_customer_ref,
        upper(trim(ops_customer_id)) AS ops_customer_id,
        effective_from::date AS effective_from,
        nullif(effective_to, '')::date AS effective_to,
        match_method,
        confidence_score::numeric(5,4) AS confidence_score,
        extract_batch_id,
        row_number() OVER (
            PARTITION BY upper(trim(crm_customer_ref))
            ORDER BY (nullif(effective_to, '') IS NULL) DESC, confidence_score::numeric DESC, effective_from::date DESC
        ) AS row_rank,
        count(*) OVER (PARTITION BY upper(trim(crm_customer_ref))) AS candidate_count
    FROM raw.customer_map
)
SELECT *
FROM ranked
WHERE row_rank = 1;

ALTER TABLE staging.stg_customer_map ADD PRIMARY KEY (crm_customer_ref);
CREATE INDEX stg_customer_map_ops_idx ON staging.stg_customer_map (ops_customer_id);

CREATE TABLE staging.stg_experiment_assignment AS
SELECT
    trim(city) AS city,
    upper(trim(city_code)) AS city_code,
    lower(trim(treatment_group)) AS treatment_group,
    nullif(launch_week, '')::integer AS launch_week,
    nullif(launch_date, '')::date AS launch_date,
    policy_description
FROM raw.experiment_assignment;

ALTER TABLE staging.stg_experiment_assignment ADD PRIMARY KEY (city);

CREATE TABLE staging.stg_loyalty_scenario AS
SELECT
    upper(trim(customer_id)) AS customer_id,
    scenario_as_of_date::date AS scenario_as_of_date,
    scenario_version,
    modeled_90d_churn_probability::numeric(8,6) AS modeled_90d_churn_probability,
    modeled_90d_order_reduction::numeric(8,6) AS modeled_90d_order_reduction,
    simulated_flag::boolean AS simulated_flag
FROM raw.loyalty_scenario;

ALTER TABLE staging.stg_loyalty_scenario ADD PRIMARY KEY (customer_id, scenario_version);

CREATE TABLE staging.stg_order_issues AS
SELECT
    upper(trim(issue_id)) AS issue_id,
    upper(trim(order_id)) AS order_id,
    upper(trim(customer_id)) AS customer_id,
    issue_detected_ts::timestamp AS issue_detected_ts,
    lower(trim(issue_type)) AS issue_type,
    lower(trim(issue_severity)) AS issue_severity,
    lower(trim(detection_source)) AS detection_source,
    contact_eligible_flag::boolean AS contact_eligible_flag,
    extract_batch_id,
    loaded_at
FROM raw.order_issues;

ALTER TABLE staging.stg_order_issues ADD PRIMARY KEY (issue_id);
CREATE INDEX stg_order_issues_order_idx ON staging.stg_order_issues (order_id);
CREATE INDEX stg_order_issues_customer_idx ON staging.stg_order_issues (customer_id, issue_detected_ts);

CREATE TABLE staging.stg_support_journey_events AS
SELECT
    upper(trim(event_id)) AS event_id,
    upper(trim(conversation_id)) AS conversation_id,
    upper(trim(contact_id)) AS contact_id,
    upper(trim(order_id)) AS order_id,
    event_ts::timestamp AS event_ts,
    lower(trim(event_type)) AS event_type,
    lower(trim(actor_type)) AS actor_type,
    nullif(lower(trim(queue_name)), '') AS queue_name,
    nullif(upper(trim(agent_id)), '') AS agent_id,
    nullif(trim(event_detail), '') AS event_detail,
    nullif(lower(trim(model_version)), '') AS model_version,
    nullif(lower(trim(policy_version)), '') AS policy_version,
    extract_batch_id,
    loaded_at
FROM raw.support_journey_events;

ALTER TABLE staging.stg_support_journey_events ADD PRIMARY KEY (event_id);
CREATE INDEX stg_journey_contact_ts_idx ON staging.stg_support_journey_events (contact_id, event_ts);
CREATE INDEX stg_journey_conversation_ts_idx ON staging.stg_support_journey_events (conversation_id, event_ts);
CREATE INDEX stg_journey_order_idx ON staging.stg_support_journey_events (order_id);

ANALYZE staging.stg_orders;
ANALYZE staging.stg_contacts;
ANALYZE staging.stg_finance;
ANALYZE staging.stg_order_issues;
ANALYZE staging.stg_support_journey_events;
