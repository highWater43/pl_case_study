\set ON_ERROR_STOP on

CREATE TABLE intermediate.int_contacts_attributed_base AS
SELECT
    c.contact_id,
    c.customer_ref_norm,
    c.order_ref_norm,
    c.contact_ts,
    c.channel,
    c.issue_type,
    c.handling,
    c.ended_reason,
    c.crm_resolved_flag,
    c.csat_score,
    c.source_row_count,
    coalesce(direct_order.order_id, inferred_order.order_id) AS attributed_order_id,
    coalesce(direct_order.customer_id, inferred_order.customer_id, customer_map.ops_customer_id) AS attributed_customer_id,
    coalesce(direct_order.city, inferred_order.city) AS city,
    coalesce(direct_order.order_week, inferred_order.order_week) AS order_week,
    CASE
        WHEN direct_order.order_id IS NOT NULL THEN 'exact_order_reference'
        WHEN inferred_order.order_id IS NOT NULL THEN 'customer_time_proximity'
        ELSE 'unattributed'
    END AS attribution_method,
    CASE
        WHEN direct_order.order_id IS NOT NULL THEN 1.00::numeric
        WHEN inferred_order.order_id IS NOT NULL THEN 0.75::numeric
        ELSE 0.00::numeric
    END AS attribution_confidence,
    CASE
        WHEN c.channel = 'ai_chat' AND c.handling = 'AI_ONLY' THEN 0.55
        WHEN c.channel = 'ai_chat' AND c.handling = 'AI_TO_AGENT' THEN 5.75
        WHEN c.channel = 'phone' THEN 6.80
        WHEN c.channel = 'email' THEN 3.10
        ELSE 0.00
    END::numeric(10,2) AS handling_cost_usd
FROM staging.stg_contacts c
LEFT JOIN staging.stg_orders direct_order
    ON direct_order.order_id = c.order_ref_norm
LEFT JOIN staging.stg_customer_map customer_map
    ON customer_map.crm_customer_ref = c.customer_ref_norm
LEFT JOIN LATERAL (
    SELECT o.order_id, o.customer_id, o.city, o.order_week
    FROM staging.stg_orders o
    WHERE direct_order.order_id IS NULL
      AND o.customer_id = customer_map.ops_customer_id
      AND o.order_ts BETWEEN c.contact_ts - interval '2 days' AND c.contact_ts + interval '1 day'
    ORDER BY abs(extract(epoch FROM (c.contact_ts - o.order_ts)))
    LIMIT 1
) inferred_order ON true;

CREATE INDEX int_contacts_attributed_order_idx
    ON intermediate.int_contacts_attributed_base (attributed_order_id, contact_ts);

CREATE TABLE intermediate.int_contacts_enriched AS
SELECT
    current_contact.*,
    EXISTS (
        SELECT 1
        FROM intermediate.int_contacts_attributed_base followup
        WHERE followup.attributed_order_id = current_contact.attributed_order_id
          AND followup.contact_ts > current_contact.contact_ts
          AND followup.contact_ts <= current_contact.contact_ts + interval '7 days'
    ) AS has_followup_contact_7d,
    (
        current_contact.ended_reason IN ('AI_RESOLVED', 'AGENT_RESOLVED')
        AND NOT EXISTS (
            SELECT 1
            FROM intermediate.int_contacts_attributed_base followup
            WHERE followup.attributed_order_id = current_contact.attributed_order_id
              AND followup.contact_ts > current_contact.contact_ts
              AND followup.contact_ts <= current_contact.contact_ts + interval '7 days'
        )
    ) AS verified_resolution_no_repeat_7d,
    (current_contact.ended_reason = 'CUSTOMER_ABANDONED') AS abandoned_flag
FROM intermediate.int_contacts_attributed_base current_contact;

ALTER TABLE intermediate.int_contacts_enriched ADD PRIMARY KEY (contact_id);

CREATE TABLE intermediate.int_contact_journey_funnel AS
WITH event_pivot AS (
    SELECT
        contact_id,
        min(conversation_id) AS conversation_id,
        min(order_id) AS journey_order_id,
        min(event_ts) FILTER (WHERE event_type = 'contact_started') AS contact_started_ts,
        min(event_ts) FILTER (WHERE event_type = 'ai_started') AS ai_started_ts,
        min(event_ts) FILTER (WHERE event_type = 'intent_detected') AS intent_detected_ts,
        min(event_ts) FILTER (WHERE event_type = 'ai_resolution_attempted') AS ai_attempted_ts,
        min(event_ts) FILTER (WHERE event_type = 'ai_failed') AS ai_failed_ts,
        min(event_ts) FILTER (WHERE event_type = 'human_requested') AS human_requested_ts,
        min(event_ts) FILTER (WHERE event_type = 'escalation_created') AS escalation_created_ts,
        min(event_ts) FILTER (WHERE event_type = 'escalation_failed') AS escalation_failed_ts,
        min(event_ts) FILTER (WHERE event_type = 'queue_entered') AS queue_entered_ts,
        min(event_ts) FILTER (WHERE event_type = 'agent_accepted') AS agent_accepted_ts,
        min(event_ts) FILTER (WHERE event_type = 'agent_first_response') AS first_human_response_ts,
        min(event_ts) FILTER (WHERE event_type = 'customer_abandoned') AS abandoned_ts,
        min(event_ts) FILTER (WHERE event_type = 'resolved') AS resolved_ts,
        min(event_ts) FILTER (WHERE event_type = 'contact_ended_unresolved') AS unresolved_end_ts,
        min(queue_name) FILTER (WHERE queue_name IS NOT NULL) AS queue_name,
        min(agent_id) FILTER (WHERE agent_id IS NOT NULL) AS agent_id,
        min(model_version) FILTER (WHERE model_version IS NOT NULL) AS model_version,
        min(policy_version) FILTER (WHERE policy_version IS NOT NULL) AS policy_version
    FROM staging.stg_support_journey_events
    GROUP BY contact_id
)
SELECT
    c.*,
    p.conversation_id,
    p.contact_started_ts,
    p.ai_started_ts,
    p.intent_detected_ts,
    p.ai_attempted_ts,
    p.ai_failed_ts,
    p.human_requested_ts,
    p.escalation_created_ts,
    p.escalation_failed_ts,
    p.queue_entered_ts,
    p.agent_accepted_ts,
    p.first_human_response_ts,
    p.abandoned_ts,
    p.resolved_ts,
    p.unresolved_end_ts,
    p.queue_name,
    p.agent_id,
    p.model_version,
    p.policy_version,
    CASE WHEN p.escalation_created_ts IS NOT NULL AND p.ai_started_ts IS NOT NULL
        THEN extract(epoch FROM (p.escalation_created_ts - p.ai_started_ts)) / 60.0 END::numeric(12,4) AS ai_minutes_before_escalation,
    CASE WHEN p.agent_accepted_ts IS NOT NULL AND p.queue_entered_ts IS NOT NULL
        THEN extract(epoch FROM (p.agent_accepted_ts - p.queue_entered_ts)) / 60.0 END::numeric(12,4) AS queue_wait_to_accept_min,
    CASE WHEN p.first_human_response_ts IS NOT NULL AND p.escalation_created_ts IS NOT NULL
        THEN extract(epoch FROM (p.first_human_response_ts - p.escalation_created_ts)) / 60.0 END::numeric(12,4) AS escalation_to_first_response_min,
    CASE WHEN p.first_human_response_ts IS NOT NULL
        THEN extract(epoch FROM (p.first_human_response_ts - c.contact_ts)) / 60.0 END::numeric(12,4) AS contact_to_first_human_response_min,
    CASE WHEN p.resolved_ts IS NOT NULL
        THEN extract(epoch FROM (p.resolved_ts - c.contact_ts)) / 60.0 END::numeric(12,4) AS total_resolution_time_min,
    CASE WHEN p.resolved_ts IS NOT NULL AND p.first_human_response_ts IS NOT NULL
        THEN extract(epoch FROM (p.resolved_ts - p.first_human_response_ts)) / 60.0 END::numeric(12,4) AS human_handling_time_min,
    (p.escalation_created_ts IS NOT NULL AND p.first_human_response_ts IS NOT NULL) AS handoff_completed_flag,
    (p.human_requested_ts IS NOT NULL AND p.first_human_response_ts IS NOT NULL) AS human_request_honored_flag,
    (
        p.queue_entered_ts IS NOT NULL
        AND p.abandoned_ts IS NOT NULL
        AND (p.first_human_response_ts IS NULL OR p.abandoned_ts < p.first_human_response_ts)
    ) AS queue_abandonment_flag,
    (c.channel = 'ai_chat' AND c.handling = 'AI_ONLY') AS technical_ai_containment_flag,
    (
        c.channel = 'ai_chat'
        AND c.handling = 'AI_ONLY'
        AND c.verified_resolution_no_repeat_7d
    ) AS verified_ai_containment_flag
FROM intermediate.int_contacts_enriched c
LEFT JOIN event_pivot p USING (contact_id);

ALTER TABLE intermediate.int_contact_journey_funnel ADD PRIMARY KEY (contact_id);
CREATE INDEX int_contact_journey_order_idx ON intermediate.int_contact_journey_funnel (attributed_order_id, contact_ts);

CREATE TABLE intermediate.int_order_contact_summary AS
SELECT
    attributed_order_id AS order_id,
    count(*) AS contact_count,
    min(contact_ts) AS first_contact_ts,
    max(contact_ts) AS last_contact_ts,
    count(*) FILTER (WHERE channel = 'ai_chat') AS ai_chat_contacts,
    count(*) FILTER (WHERE channel = 'phone') AS phone_contacts,
    count(*) FILTER (WHERE channel = 'email') AS email_contacts,
    count(*) FILTER (WHERE abandoned_flag) AS abandoned_contacts,
    count(*) FILTER (WHERE crm_resolved_flag) AS crm_resolved_contacts,
    count(*) FILTER (WHERE verified_resolution_no_repeat_7d) AS verified_resolved_contacts,
    count(csat_score) AS csat_response_count,
    avg(csat_score)::numeric(8,4) AS avg_csat_score,
    sum(handling_cost_usd)::numeric(12,2) AS handling_cost_usd,
    (count(*) > 1) AS repeat_contact_flag,
    min(issue_type) FILTER (WHERE issue_type <> 'none') AS primary_issue_type
FROM intermediate.int_contacts_enriched
WHERE attributed_order_id IS NOT NULL
GROUP BY attributed_order_id;

ALTER TABLE intermediate.int_order_contact_summary ADD PRIMARY KEY (order_id);

CREATE TABLE intermediate.int_order_finance_summary AS
SELECT
    order_id,
    sum(cost_amount_usd) FILTER (WHERE entry_type IN ('REFUND', 'CUSTOMER_CREDIT'))::numeric(12,2) AS refund_credit_cost_usd,
    sum(cost_amount_usd) FILTER (WHERE entry_type = 'CHARGEBACK')::numeric(12,2) AS chargeback_dispute_cost_usd,
    sum(cost_amount_usd) FILTER (WHERE entry_type = 'CHARGEBACK_FEE')::numeric(12,2) AS chargeback_fee_cost_usd,
    min(posted_date) FILTER (WHERE entry_type = 'CHARGEBACK') AS first_chargeback_posted_date,
    max(posted_date) AS latest_finance_posted_date,
    count(*) FILTER (WHERE entry_type = 'CHARGEBACK') AS chargeback_count
FROM staging.stg_finance
GROUP BY order_id;

ALTER TABLE intermediate.int_order_finance_summary ADD PRIMARY KEY (order_id);

CREATE TABLE intermediate.int_order_issue_summary AS
SELECT
    order_id,
    min(issue_id) AS issue_id,
    min(issue_detected_ts) AS issue_detected_ts,
    min(issue_type) AS issue_type,
    max(issue_severity) AS issue_severity,
    min(detection_source) AS detection_source,
    bool_or(contact_eligible_flag) AS contact_eligible_flag
FROM staging.stg_order_issues
GROUP BY order_id;

ALTER TABLE intermediate.int_order_issue_summary ADD PRIMARY KEY (order_id);

CREATE TABLE intermediate.int_order_outcomes AS
SELECT
    o.order_id,
    o.customer_id,
    o.city,
    a.city_code,
    a.treatment_group,
    o.order_week,
    o.order_ts,
    o.order_status,
    o.order_value_usd,
    o.promised_duration_min,
    o.delivery_duration_min,
    o.source_late_flag,
    o.promo_code,
    (o.order_week >= 7) AS post_period,
    (a.treatment_group = 'treatment' AND o.order_week >= 7) AS treated_post,
    coalesce(i.issue_type, c.primary_issue_type,
        CASE
            WHEN o.order_status = 'cancelled' THEN 'cancelled'
            WHEN o.source_late_flag THEN 'late_order'
            ELSE 'none'
        END
    ) AS observed_issue_type,
    coalesce(i.issue_severity, 'none') AS issue_severity,
    i.issue_id,
    i.issue_detected_ts,
    i.detection_source AS issue_detection_source,
    coalesce(c.contact_count, 0) AS contact_count,
    coalesce(c.ai_chat_contacts, 0) AS ai_chat_contacts,
    coalesce(c.phone_contacts, 0) AS phone_contacts,
    coalesce(c.email_contacts, 0) AS email_contacts,
    coalesce(c.abandoned_contacts, 0) AS abandoned_contacts,
    coalesce(c.crm_resolved_contacts, 0) AS crm_resolved_contacts,
    coalesce(c.verified_resolved_contacts, 0) AS verified_resolved_contacts,
    coalesce(c.csat_response_count, 0) AS csat_response_count,
    c.avg_csat_score,
    coalesce(c.handling_cost_usd, 0)::numeric(12,2) AS handling_cost_usd,
    coalesce(c.repeat_contact_flag, false) AS repeat_contact_flag,
    coalesce(f.refund_credit_cost_usd, 0)::numeric(12,2) AS refund_credit_cost_usd,
    coalesce(f.chargeback_dispute_cost_usd, 0)::numeric(12,2) AS chargeback_dispute_cost_usd,
    coalesce(f.chargeback_fee_cost_usd, 0)::numeric(12,2) AS chargeback_fee_cost_usd,
    coalesce(f.chargeback_count, 0) AS chargeback_count,
    f.first_chargeback_posted_date,
    f.latest_finance_posted_date,
    (o.order_value_usd * 0.12)::numeric(12,2) AS contribution_margin_usd
FROM staging.stg_orders o
JOIN staging.stg_experiment_assignment a USING (city)
LEFT JOIN intermediate.int_order_contact_summary c USING (order_id)
LEFT JOIN intermediate.int_order_finance_summary f USING (order_id)
LEFT JOIN intermediate.int_order_issue_summary i USING (order_id);

ALTER TABLE intermediate.int_order_outcomes ADD PRIMARY KEY (order_id);
CREATE INDEX int_order_outcomes_city_week_idx ON intermediate.int_order_outcomes (city, order_week);
CREATE INDEX int_order_outcomes_customer_ts_idx ON intermediate.int_order_outcomes (customer_id, order_ts);

ANALYZE intermediate.int_contacts_enriched;
ANALYZE intermediate.int_contact_journey_funnel;
ANALYZE intermediate.int_order_outcomes;
