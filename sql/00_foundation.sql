\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS mart CASCADE;
DROP SCHEMA IF EXISTS intermediate CASCADE;
DROP SCHEMA IF EXISTS staging CASCADE;
DROP SCHEMA IF EXISTS raw CASCADE;
DROP SCHEMA IF EXISTS audit CASCADE;

CREATE SCHEMA raw;
CREATE SCHEMA staging;
CREATE SCHEMA intermediate;
CREATE SCHEMA mart;
CREATE SCHEMA audit;

CREATE TABLE raw.orders_ops (
    order_id text,
    customer_id text,
    city text,
    src_system text,
    order_ts text,
    restaurant_id text,
    order_value text,
    promised_duration text,
    delivery_duration text,
    status_code text,
    promo_code text,
    extract_batch_id text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE raw.support_contacts (
    contact_id text,
    customer_ref text,
    order_ref text,
    contact_ts text,
    channel text,
    issue_type text,
    handling text,
    ended_reason text,
    crm_resolved_flag text,
    csat_score text,
    extract_batch_id text,
    source_updated_at text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE raw.finance_ledger (
    ledger_id text,
    order_id text,
    posted_date text,
    amount_usd text,
    entry_type text,
    reason_code text,
    extract_batch_id text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE raw.customer_map (
    crm_customer_ref text,
    ops_customer_id text,
    effective_from text,
    effective_to text,
    match_method text,
    confidence_score text,
    extract_batch_id text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE raw.experiment_assignment (
    city text,
    city_code text,
    treatment_group text,
    launch_week text,
    launch_date text,
    policy_description text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE raw.loyalty_scenario (
    customer_id text,
    scenario_as_of_date text,
    scenario_version text,
    modeled_90d_churn_probability text,
    modeled_90d_order_reduction text,
    simulated_flag text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE raw.order_issues (
    issue_id text,
    order_id text,
    customer_id text,
    issue_detected_ts text,
    issue_type text,
    issue_severity text,
    detection_source text,
    contact_eligible_flag text,
    extract_batch_id text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE raw.support_journey_events (
    event_id text,
    conversation_id text,
    contact_id text,
    order_id text,
    event_ts text,
    event_type text,
    actor_type text,
    queue_name text,
    agent_id text,
    event_detail text,
    model_version text,
    policy_version text,
    extract_batch_id text,
    loaded_at timestamptz NOT NULL DEFAULT now()
);
