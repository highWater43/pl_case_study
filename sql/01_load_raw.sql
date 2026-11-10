\set ON_ERROR_STOP on

COPY raw.orders_ops (order_id, customer_id, city, src_system, order_ts, restaurant_id, order_value, promised_duration, delivery_duration, status_code, promo_code, extract_batch_id) FROM :'orders_csv' WITH (FORMAT csv, HEADER true);
COPY raw.support_contacts (contact_id, customer_ref, order_ref, contact_ts, channel, issue_type, handling, ended_reason, crm_resolved_flag, csat_score, extract_batch_id, source_updated_at) FROM :'contacts_csv' WITH (FORMAT csv, HEADER true);
COPY raw.finance_ledger (ledger_id, order_id, posted_date, amount_usd, entry_type, reason_code, extract_batch_id) FROM :'finance_csv' WITH (FORMAT csv, HEADER true);
COPY raw.customer_map (crm_customer_ref, ops_customer_id, effective_from, effective_to, match_method, confidence_score, extract_batch_id) FROM :'map_csv' WITH (FORMAT csv, HEADER true);
COPY raw.experiment_assignment (city, city_code, treatment_group, launch_week, launch_date, policy_description) FROM :'assignment_csv' WITH (FORMAT csv, HEADER true);
COPY raw.loyalty_scenario (customer_id, scenario_as_of_date, scenario_version, modeled_90d_churn_probability, modeled_90d_order_reduction, simulated_flag) FROM :'loyalty_csv' WITH (FORMAT csv, HEADER true);
COPY raw.order_issues (issue_id, order_id, customer_id, issue_detected_ts, issue_type, issue_severity, detection_source, contact_eligible_flag, extract_batch_id) FROM :'issues_csv' WITH (FORMAT csv, HEADER true);
COPY raw.support_journey_events (event_id, conversation_id, contact_id, order_id, event_ts, event_type, actor_type, queue_name, agent_id, event_detail, model_version, policy_version, extract_batch_id) FROM :'journey_csv' WITH (FORMAT csv, HEADER true);

ANALYZE raw.orders_ops;
ANALYZE raw.support_contacts;
ANALYZE raw.finance_ledger;
ANALYZE raw.customer_map;
ANALYZE raw.order_issues;
ANALYZE raw.support_journey_events;
