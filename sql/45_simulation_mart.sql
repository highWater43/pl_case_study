\set ON_ERROR_STOP on

-- These models are scenario outputs. They never replace observed facts.
CREATE TABLE mart.dim_simulation_scenario (
    scenario_id text PRIMARY KEY,
    scenario_name text NOT NULL,
    scenario_description text NOT NULL,
    rescue_share numeric(8,4) NOT NULL CHECK (rescue_share BETWEEN 0 AND 1),
    target_first_human_response_min numeric(8,2) NOT NULL,
    scenario_version text NOT NULL,
    simulated_flag boolean NOT NULL DEFAULT true,
    mandatory_label text NOT NULL
);

INSERT INTO mart.dim_simulation_scenario VALUES
('FAST_HELP_CONSERVATIVE', 'Conservative faster-help scenario', 'Half of AI handoffs that currently end without a human response receive a response within five minutes.', 0.50, 5.00, 'v1', true, 'Simulated scenario based on synthetic customer-journey data; not an observed result.'),
('FAST_HELP_EXPECTED', 'Expected faster-help scenario', 'Seven out of ten AI handoffs that currently end without a human response receive a response within four minutes.', 0.70, 4.00, 'v1', true, 'Simulated scenario based on synthetic customer-journey data; not an observed result.'),
('FAST_HELP_STRONG', 'Strong faster-help scenario', 'Eight-and-a-half out of ten AI handoffs that currently end without a human response receive a response within three minutes.', 0.85, 3.00, 'v1', true, 'Simulated scenario based on synthetic customer-journey data; not an observed result.');

CREATE TABLE mart.dim_simulation_assumption (
    scenario_id text NOT NULL REFERENCES mart.dim_simulation_scenario (scenario_id),
    assumption_name text NOT NULL,
    assumption_value text NOT NULL,
    source_model text NOT NULL,
    source_filter text NOT NULL,
    rationale text NOT NULL,
    limitation text NOT NULL,
    PRIMARY KEY (scenario_id, assumption_name)
);

INSERT INTO mart.dim_simulation_assumption
SELECT
    scenario_id,
    assumption_name,
    CASE assumption_name
        WHEN 'handoff_rescue_share' THEN rescue_share::text
        WHEN 'human_response_target_minutes' THEN target_first_human_response_min::text
        WHEN 'fast_response_reference' THEN '2 to 5 minutes'
        WHEN 'finance_mapping' THEN 'originating order'
        WHEN 'staffing_cost' THEN 'not available'
        WHEN 'simulation_method' THEN 'deterministic expected value'
    END AS assumption_value,
    CASE assumption_name
        WHEN 'handoff_rescue_share' THEN 'mart.fct_handoff_funnel'
        WHEN 'human_response_target_minutes' THEN 'mart.fct_handoff_funnel'
        WHEN 'fast_response_reference' THEN 'mart.fct_contact_journey'
        WHEN 'finance_mapping' THEN 'intermediate.int_order_outcomes'
        WHEN 'staffing_cost' THEN 'source gap'
        WHEN 'simulation_method' THEN 'mart.fct_sim_order_outcomes'
    END AS source_model,
    CASE assumption_name
        WHEN 'handoff_rescue_share' THEN 'new-design cities after week 7; AI escalations that ended without a human response'
        WHEN 'human_response_target_minutes' THEN 'comparison with completed handoffs in unchanged cities'
        WHEN 'fast_response_reference' THEN 'AI-to-agent contacts with first human response between 2 and 5 minutes'
        WHEN 'finance_mapping' THEN 'support and ledger records attributed to the same order_id'
        WHEN 'staffing_cost' THEN 'no agent roster, wage, or capacity ledger was supplied'
        WHEN 'simulation_method' THEN 'probability-weighted outcomes; no random draws'
    END AS source_filter,
    CASE assumption_name
        WHEN 'handoff_rescue_share' THEN 'Creates conservative, expected, and strong service scenarios.'
        WHEN 'human_response_target_minutes' THEN 'Turns the recommendation into a measurable operating target.'
        WHEN 'fast_response_reference' THEN 'Uses outcomes already present in the synthetic database.'
        WHEN 'finance_mapping' THEN 'Keeps every projected dollar traceable to the order-level value-left formula.'
        WHEN 'staffing_cost' THEN 'Reports required human minutes while leaving unobserved wage cost out of the financial projection.'
        WHEN 'simulation_method' THEN 'Makes every rebuild produce the same projected result.'
    END AS rationale,
    CASE assumption_name
        WHEN 'handoff_rescue_share' THEN 'A real experiment must establish whether the operational target is achievable.'
        WHEN 'human_response_target_minutes' THEN 'Response time alone does not prove that the customer problem was resolved.'
        WHEN 'fast_response_reference' THEN 'The relationship is descriptive and can still reflect issue mix or customer selection.'
        WHEN 'finance_mapping' THEN 'Recent chargebacks may be incomplete until the finance observation window matures.'
        WHEN 'staffing_cost' THEN 'The projected North Star excludes incremental workforce expense outside the supplied contact-cost assumptions.'
        WHEN 'simulation_method' THEN 'Expected values are scenario estimates, not observed customer outcomes.'
    END AS limitation
FROM mart.dim_simulation_scenario
CROSS JOIN (
    VALUES
        ('handoff_rescue_share'),
        ('human_response_target_minutes'),
        ('fast_response_reference'),
        ('finance_mapping'),
        ('staffing_cost'),
        ('simulation_method')
) assumptions(assumption_name);

CREATE TABLE mart.fct_sim_reference_rates AS
WITH ranked_fast_contacts AS (
    SELECT
        j.*,
        row_number() OVER (
            PARTITION BY j.order_id
            ORDER BY j.escalation_to_first_response_min, j.contact_id
        ) AS order_contact_rank
    FROM mart.fct_contact_journey j
    WHERE j.channel = 'ai_chat'
      AND j.order_id IS NOT NULL
      AND j.first_human_response_ts IS NOT NULL
      AND j.escalation_to_first_response_min BETWEEN 2 AND 5
), fast_orders AS (
    SELECT
        r.order_id,
        r.issue_type,
        r.issue_severity,
        r.verified_resolution_no_repeat_7d,
        r.has_followup_contact_7d,
        r.csat_score,
        r.human_handling_time_min,
        r.total_resolution_time_min,
        o.contact_count,
        o.handling_cost_usd,
        o.refund_credit_cost_usd,
        o.chargeback_count,
        o.order_value_usd
    FROM ranked_fast_contacts r
    JOIN intermediate.int_order_outcomes o USING (order_id)
    WHERE r.order_contact_rank = 1
)
SELECT
    coalesce(issue_type, '__all__') AS issue_type,
    coalesce(issue_severity, '__all__') AS issue_severity,
    count(*) AS reference_orders,
    avg(contact_count)::numeric(12,6) AS expected_contact_count,
    avg(verified_resolution_no_repeat_7d::integer)::numeric(12,6) AS verified_resolution_probability,
    avg(has_followup_contact_7d::integer)::numeric(12,6) AS repeat_contact_probability,
    avg(csat_score)::numeric(12,6) AS expected_csat,
    avg(human_handling_time_min)::numeric(12,6) AS expected_human_minutes,
    avg(total_resolution_time_min)::numeric(12,6) AS expected_total_resolution_time_min,
    avg(handling_cost_usd)::numeric(12,6) AS expected_handling_cost_usd,
    avg(refund_credit_cost_usd)::numeric(12,6) AS expected_refund_credit_cost_usd,
    avg((chargeback_count > 0)::integer)::numeric(12,6) AS chargeback_probability,
    avg(order_value_usd)::numeric(12,6) AS reference_order_value_usd
FROM fast_orders
GROUP BY GROUPING SETS ((issue_type, issue_severity), ());

ALTER TABLE mart.fct_sim_reference_rates ADD PRIMARY KEY (issue_type, issue_severity);

CREATE TABLE mart.fct_sim_contact_outcomes AS
WITH eligible_contacts AS (
    SELECT
        j.*,
        row_number() OVER (
            PARTITION BY j.order_id
            ORDER BY j.contact_id
        ) AS eligible_order_rank
    FROM mart.fct_contact_journey j
    WHERE j.treatment_group = 'treatment'
      AND j.post_period
      AND j.channel = 'ai_chat'
      AND j.escalation_created_ts IS NOT NULL
), reference_joined AS (
    SELECT
        e.*,
        CASE WHEN exact.reference_orders >= 30 THEN exact.reference_orders ELSE overall.reference_orders END AS reference_orders,
        CASE WHEN exact.reference_orders >= 30 THEN exact.verified_resolution_probability ELSE overall.verified_resolution_probability END AS ref_verified_resolution_probability,
        CASE WHEN exact.reference_orders >= 30 THEN exact.repeat_contact_probability ELSE overall.repeat_contact_probability END AS ref_repeat_contact_probability,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_csat ELSE overall.expected_csat END AS ref_expected_csat,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_human_minutes ELSE overall.expected_human_minutes END AS ref_expected_human_minutes,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_total_resolution_time_min ELSE overall.expected_total_resolution_time_min END AS ref_expected_total_resolution_time_min,
        CASE WHEN exact.reference_orders >= 30 THEN exact.chargeback_probability ELSE overall.chargeback_probability END AS ref_chargeback_probability
    FROM eligible_contacts e
    LEFT JOIN mart.fct_sim_reference_rates exact
      ON exact.issue_type = e.issue_type
     AND exact.issue_severity = e.issue_severity
    CROSS JOIN mart.fct_sim_reference_rates overall
    WHERE overall.issue_type = '__all__'
      AND overall.issue_severity = '__all__'
)
SELECT
    s.scenario_id,
    r.contact_id,
    r.order_id,
    r.city,
    r.order_week,
    r.issue_type,
    r.issue_severity,
    r.eligible_order_rank,
    r.queue_abandonment_flag AS eligible_for_rescue,
    CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END AS rescue_probability,
    r.escalation_to_first_response_min AS observed_first_human_response_min,
    CASE WHEN r.queue_abandonment_flag THEN s.target_first_human_response_min ELSE r.escalation_to_first_response_min END AS simulated_first_human_response_min_if_completed,
    r.total_resolution_time_min AS observed_total_resolution_time_min,
    CASE
        WHEN r.queue_abandonment_flag THEN r.ref_expected_total_resolution_time_min
        ELSE r.total_resolution_time_min
    END::numeric(12,6) AS simulated_total_resolution_time_min_if_completed,
    r.handoff_completed_flag::integer AS observed_handoff_completed,
    (
        r.handoff_completed_flag::integer
        + CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END
    )::numeric(12,6) AS simulated_handoff_completion_probability,
    r.queue_abandonment_flag::integer AS observed_queue_abandonment,
    (
        r.queue_abandonment_flag::integer
        * (1 - CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END)
    )::numeric(12,6) AS simulated_queue_abandonment_probability,
    r.verified_resolution_no_repeat_7d::integer AS observed_verified_resolution,
    (
        r.verified_resolution_no_repeat_7d::integer * (1 - CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END)
        + r.ref_verified_resolution_probability * CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END
    )::numeric(12,6) AS simulated_verified_resolution_probability,
    r.has_followup_contact_7d::integer AS observed_repeat_contact,
    (
        r.has_followup_contact_7d::integer * (1 - CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END)
        + r.ref_repeat_contact_probability * CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END
    )::numeric(12,6) AS simulated_repeat_contact_probability,
    r.csat_score AS observed_csat,
    (
        coalesce(r.csat_score::numeric, r.ref_expected_csat) * (1 - CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END)
        + r.ref_expected_csat * CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END
    )::numeric(12,6) AS simulated_expected_csat,
    (r.order_chargeback_count > 0)::integer AS observed_chargeback,
    (
        (r.order_chargeback_count > 0)::integer * (1 - CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END)
        + r.ref_chargeback_probability * CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END
    )::numeric(12,6) AS simulated_chargeback_probability,
    (
        r.ref_expected_human_minutes * CASE WHEN r.queue_abandonment_flag THEN s.rescue_share ELSE 0::numeric END
    )::numeric(12,6) AS expected_added_human_minutes,
    r.reference_orders,
    true AS simulated_flag,
    s.mandatory_label
FROM reference_joined r
CROSS JOIN mart.dim_simulation_scenario s;

ALTER TABLE mart.fct_sim_contact_outcomes ADD PRIMARY KEY (scenario_id, contact_id);

CREATE TABLE mart.fct_sim_order_outcomes AS
WITH selected_rescue_contact AS (
    SELECT *
    FROM mart.fct_sim_contact_outcomes
    WHERE eligible_for_rescue
      AND eligible_order_rank = 1
), reference_joined AS (
    SELECT
        selected.*,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_contact_count ELSE overall.expected_contact_count END AS ref_expected_contact_count,
        CASE WHEN exact.reference_orders >= 30 THEN exact.verified_resolution_probability ELSE overall.verified_resolution_probability END AS ref_verified_resolution_probability,
        CASE WHEN exact.reference_orders >= 30 THEN exact.repeat_contact_probability ELSE overall.repeat_contact_probability END AS ref_repeat_contact_probability,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_csat ELSE overall.expected_csat END AS ref_expected_csat,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_human_minutes ELSE overall.expected_human_minutes END AS ref_expected_human_minutes,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_handling_cost_usd ELSE overall.expected_handling_cost_usd END AS ref_expected_handling_cost_usd,
        CASE WHEN exact.reference_orders >= 30 THEN exact.expected_refund_credit_cost_usd ELSE overall.expected_refund_credit_cost_usd END AS ref_expected_refund_credit_cost_usd,
        CASE WHEN exact.reference_orders >= 30 THEN exact.chargeback_probability ELSE overall.chargeback_probability END AS ref_chargeback_probability
    FROM selected_rescue_contact selected
    LEFT JOIN mart.fct_sim_reference_rates exact
      ON exact.issue_type = selected.issue_type
     AND exact.issue_severity = selected.issue_severity
    CROSS JOIN mart.fct_sim_reference_rates overall
    WHERE overall.issue_type = '__all__'
      AND overall.issue_severity = '__all__'
), order_scenario AS (
    SELECT
        s.scenario_id,
        s.mandatory_label,
        o.*,
        coalesce(r.rescue_probability, 0::numeric) AS rescue_probability,
        r.ref_expected_contact_count,
        r.ref_verified_resolution_probability,
        r.ref_repeat_contact_probability,
        r.ref_expected_csat,
        r.ref_expected_human_minutes,
        r.ref_expected_handling_cost_usd,
        r.ref_expected_refund_credit_cost_usd,
        r.ref_chargeback_probability
    FROM intermediate.int_order_outcomes o
    CROSS JOIN mart.dim_simulation_scenario s
    LEFT JOIN reference_joined r
      ON r.scenario_id = s.scenario_id
     AND r.order_id = o.order_id
)
SELECT
    scenario_id,
    order_id,
    customer_id,
    city,
    city_code,
    treatment_group,
    order_week,
    post_period,
    treated_post,
    observed_issue_type,
    issue_severity,
    order_value_usd,
    contribution_margin_usd,
    (rescue_probability > 0) AS eligible_for_rescue,
    rescue_probability,
    contact_count::numeric(12,6) AS observed_contact_count,
    (
        contact_count * (1 - rescue_probability)
        + coalesce(ref_expected_contact_count, contact_count) * rescue_probability
    )::numeric(12,6) AS simulated_expected_contact_count,
    abandoned_contacts::numeric(12,6) AS observed_abandoned_contacts,
    (abandoned_contacts * (1 - rescue_probability))::numeric(12,6) AS simulated_expected_abandoned_contacts,
    (verified_resolved_contacts > 0)::integer AS observed_verified_resolution,
    (
        (verified_resolved_contacts > 0)::integer * (1 - rescue_probability)
        + coalesce(ref_verified_resolution_probability, (verified_resolved_contacts > 0)::integer) * rescue_probability
    )::numeric(12,6) AS simulated_verified_resolution_probability,
    repeat_contact_flag::integer AS observed_repeat_contact,
    (
        repeat_contact_flag::integer * (1 - rescue_probability)
        + coalesce(ref_repeat_contact_probability, repeat_contact_flag::integer) * rescue_probability
    )::numeric(12,6) AS simulated_repeat_contact_probability,
    avg_csat_score AS observed_csat,
    (
        coalesce(avg_csat_score, ref_expected_csat) * (1 - rescue_probability)
        + coalesce(ref_expected_csat, avg_csat_score) * rescue_probability
    )::numeric(12,6) AS simulated_expected_csat,
    handling_cost_usd AS observed_handling_cost_usd,
    (
        handling_cost_usd * (1 - rescue_probability)
        + coalesce(ref_expected_handling_cost_usd, handling_cost_usd) * rescue_probability
    )::numeric(12,6) AS simulated_handling_cost_usd,
    refund_credit_cost_usd AS observed_refund_credit_cost_usd,
    (
        refund_credit_cost_usd * (1 - rescue_probability)
        + coalesce(ref_expected_refund_credit_cost_usd, refund_credit_cost_usd) * rescue_probability
    )::numeric(12,6) AS simulated_refund_credit_cost_usd,
    chargeback_dispute_cost_usd AS observed_chargeback_dispute_cost_usd,
    (
        chargeback_dispute_cost_usd * (1 - rescue_probability)
        + coalesce(ref_chargeback_probability * order_value_usd, chargeback_dispute_cost_usd) * rescue_probability
    )::numeric(12,6) AS simulated_chargeback_dispute_cost_usd,
    chargeback_fee_cost_usd AS observed_chargeback_fee_cost_usd,
    (
        chargeback_fee_cost_usd * (1 - rescue_probability)
        + coalesce(ref_chargeback_probability * 18.00, chargeback_fee_cost_usd) * rescue_probability
    )::numeric(12,6) AS simulated_chargeback_fee_cost_usd,
    chargeback_count::numeric(12,6) AS observed_chargeback_count,
    (
        chargeback_count * (1 - rescue_probability)
        + coalesce(ref_chargeback_probability, chargeback_count::numeric) * rescue_probability
    )::numeric(12,6) AS simulated_chargeback_probability,
    (
        contribution_margin_usd
        - handling_cost_usd
        - refund_credit_cost_usd
        - chargeback_dispute_cost_usd
        - chargeback_fee_cost_usd
    )::numeric(12,6) AS observed_value_left_usd,
    (
        contribution_margin_usd
        - (
            handling_cost_usd * (1 - rescue_probability)
            + coalesce(ref_expected_handling_cost_usd, handling_cost_usd) * rescue_probability
        )
        - (
            refund_credit_cost_usd * (1 - rescue_probability)
            + coalesce(ref_expected_refund_credit_cost_usd, refund_credit_cost_usd) * rescue_probability
        )
        - (
            chargeback_dispute_cost_usd * (1 - rescue_probability)
            + coalesce(ref_chargeback_probability * order_value_usd, chargeback_dispute_cost_usd) * rescue_probability
        )
        - (
            chargeback_fee_cost_usd * (1 - rescue_probability)
            + coalesce(ref_chargeback_probability * 18.00, chargeback_fee_cost_usd) * rescue_probability
        )
    )::numeric(12,6) AS simulated_value_left_usd,
    (coalesce(ref_expected_human_minutes, 0) * rescue_probability)::numeric(12,6) AS expected_added_human_minutes,
    0::numeric(12,2) AS unobserved_incremental_staffing_cost_usd,
    true AS simulated_flag,
    mandatory_label
FROM order_scenario;

ALTER TABLE mart.fct_sim_order_outcomes ADD PRIMARY KEY (scenario_id, order_id);
CREATE INDEX fct_sim_order_outcomes_city_week_idx ON mart.fct_sim_order_outcomes (scenario_id, city, order_week);

CREATE TABLE mart.fct_sim_city_week AS
SELECT
    scenario_id,
    city,
    city_code,
    treatment_group,
    order_week,
    post_period,
    count(*) AS total_orders,
    count(*) FILTER (WHERE observed_contact_count > 0) AS contacted_orders,
    sum(simulated_expected_contact_count)::numeric(14,6) AS simulated_contacts,
    sum(simulated_expected_abandoned_contacts)::numeric(14,6) AS simulated_abandoned_contacts,
    sum(simulated_verified_resolution_probability)::numeric(14,6) AS simulated_verified_resolutions,
    sum(simulated_repeat_contact_probability) FILTER (WHERE observed_contact_count > 0)::numeric(14,6) AS simulated_repeat_contact_orders,
    avg(simulated_expected_csat) FILTER (WHERE simulated_expected_csat IS NOT NULL)::numeric(12,6) AS simulated_average_csat,
    sum(simulated_handling_cost_usd)::numeric(14,6) AS simulated_handling_cost_usd,
    sum(simulated_refund_credit_cost_usd)::numeric(14,6) AS simulated_refund_credit_cost_usd,
    sum(simulated_chargeback_dispute_cost_usd)::numeric(14,6) AS simulated_chargeback_dispute_cost_usd,
    sum(simulated_chargeback_fee_cost_usd)::numeric(14,6) AS simulated_chargeback_fee_cost_usd,
    sum(simulated_chargeback_probability)::numeric(14,6) AS simulated_chargebacks,
    sum(simulated_value_left_usd)::numeric(14,6) AS simulated_value_left_usd,
    count(*) FILTER (WHERE eligible_for_rescue) AS eligible_orders,
    sum(rescue_probability) FILTER (WHERE eligible_for_rescue)::numeric(14,6) AS expected_rescued_orders,
    sum(expected_added_human_minutes)::numeric(14,6) AS expected_added_human_minutes,
    true AS simulated_flag
FROM mart.fct_sim_order_outcomes
GROUP BY scenario_id, city, city_code, treatment_group, order_week, post_period;

ALTER TABLE mart.fct_sim_city_week ADD PRIMARY KEY (scenario_id, city, order_week);

CREATE TABLE mart.fct_sim_metric_results AS
WITH sim_weekly AS (
    SELECT
        scenario_id,
        city,
        treatment_group,
        order_week,
        post_period,
        (simulated_handling_cost_usd / nullif(total_orders, 0))::numeric AS handling_cost_per_order,
        (
            (simulated_handling_cost_usd + simulated_refund_credit_cost_usd + simulated_chargeback_dispute_cost_usd + simulated_chargeback_fee_cost_usd)
            / nullif(total_orders, 0)
        )::numeric AS fully_loaded_failure_cost_per_order,
        (simulated_value_left_usd / nullif(total_orders, 0))::numeric AS support_adjusted_contribution_per_order,
        (simulated_verified_resolutions / nullif(simulated_contacts, 0))::numeric AS verified_resolution_rate,
        (simulated_abandoned_contacts / nullif(simulated_contacts, 0))::numeric AS abandonment_rate,
        (simulated_repeat_contact_orders / nullif(contacted_orders, 0))::numeric AS repeat_contact_rate,
        simulated_average_csat AS average_csat,
        (1000.0 * simulated_chargebacks / nullif(total_orders, 0))::numeric AS chargebacks_per_1000_orders,
        (
            (simulated_handling_cost_usd + simulated_refund_credit_cost_usd + simulated_chargeback_dispute_cost_usd + simulated_chargeback_fee_cost_usd)
            / nullif(simulated_verified_resolutions, 0)
        )::numeric AS total_cost_per_verified_resolution
    FROM mart.fct_sim_city_week
), sim_long AS (
    SELECT scenario_id, city, treatment_group, post_period, 'handling_cost_per_order'::text AS metric_name, handling_cost_per_order AS metric_value FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'fully_loaded_failure_cost_per_order', fully_loaded_failure_cost_per_order FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'support_adjusted_contribution_per_order', support_adjusted_contribution_per_order FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'verified_resolution_rate', verified_resolution_rate FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'abandonment_rate', abandonment_rate FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'repeat_contact_rate', repeat_contact_rate FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'average_csat', average_csat FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'chargebacks_per_1000_orders', chargebacks_per_1000_orders FROM sim_weekly
    UNION ALL SELECT scenario_id, city, treatment_group, post_period, 'total_cost_per_verified_resolution', total_cost_per_verified_resolution FROM sim_weekly
), period_means AS (
    SELECT
        scenario_id,
        metric_name,
        avg(metric_value) FILTER (WHERE treatment_group = 'treatment' AND NOT post_period) AS treated_pre,
        avg(metric_value) FILTER (WHERE treatment_group = 'treatment' AND post_period) AS simulated_treated_post,
        avg(metric_value) FILTER (WHERE treatment_group = 'control' AND NOT post_period) AS control_pre,
        avg(metric_value) FILTER (WHERE treatment_group = 'control' AND post_period) AS control_post
    FROM sim_long
    GROUP BY scenario_id, metric_name
), observed_post AS (
    SELECT metric_name, treated_post AS observed_treated_post, did_effect AS observed_did_effect
    FROM mart.fct_did_estimates
    UNION ALL
    SELECT
        'total_cost_per_verified_resolution',
        avg(fully_loaded_failure_cost_usd / nullif(verified_resolved_contacts, 0))
            FILTER (WHERE treatment_group = 'treatment' AND post_period),
        (
            avg(fully_loaded_failure_cost_usd / nullif(verified_resolved_contacts, 0))
                FILTER (WHERE treatment_group = 'treatment' AND post_period)
            - avg(fully_loaded_failure_cost_usd / nullif(verified_resolved_contacts, 0))
                FILTER (WHERE treatment_group = 'treatment' AND NOT post_period)
            - avg(fully_loaded_failure_cost_usd / nullif(verified_resolved_contacts, 0))
                FILTER (WHERE treatment_group = 'control' AND post_period)
            + avg(fully_loaded_failure_cost_usd / nullif(verified_resolved_contacts, 0))
                FILTER (WHERE treatment_group = 'control' AND NOT post_period)
        )::numeric
    FROM mart.fct_city_week
), main_metrics AS (
    SELECT
        p.scenario_id,
        p.metric_name,
        o.observed_treated_post::numeric(14,6),
        p.simulated_treated_post::numeric(14,6),
        (p.simulated_treated_post - o.observed_treated_post)::numeric(14,6) AS simulated_change_vs_observed,
        o.observed_did_effect::numeric(14,6),
        ((p.simulated_treated_post - p.treated_pre) - (p.control_post - p.control_pre))::numeric(14,6) AS simulated_did_effect
    FROM period_means p
    JOIN observed_post o USING (metric_name)
), handoff_metrics AS (
    SELECT
        c.scenario_id,
        'handoff_completion_rate'::text AS metric_name,
        avg(c.observed_handoff_completed)::numeric(14,6) AS observed_treated_post,
        avg(c.simulated_handoff_completion_probability)::numeric(14,6) AS simulated_treated_post,
        (avg(c.simulated_handoff_completion_probability) - avg(c.observed_handoff_completed))::numeric(14,6) AS simulated_change_vs_observed,
        d.did_effect::numeric(14,6) AS observed_did_effect,
        ((avg(c.simulated_handoff_completion_probability) - d.treated_pre) - (d.control_post - d.control_pre))::numeric(14,6) AS simulated_did_effect
    FROM mart.fct_sim_contact_outcomes c
    CROSS JOIN mart.fct_ai_handoff_did d
    WHERE d.metric_name = 'handoff_completion_rate'
    GROUP BY c.scenario_id, d.did_effect, d.treated_pre, d.control_post, d.control_pre
    UNION ALL
    SELECT
        c.scenario_id,
        'queue_abandonment_rate',
        avg(c.observed_queue_abandonment)::numeric(14,6),
        avg(c.simulated_queue_abandonment_probability)::numeric(14,6),
        (avg(c.simulated_queue_abandonment_probability) - avg(c.observed_queue_abandonment))::numeric(14,6),
        d.did_effect::numeric(14,6),
        ((avg(c.simulated_queue_abandonment_probability) - d.treated_pre) - (d.control_post - d.control_pre))::numeric(14,6)
    FROM mart.fct_sim_contact_outcomes c
    CROSS JOIN mart.fct_ai_handoff_did d
    WHERE d.metric_name = 'queue_abandonment_rate'
    GROUP BY c.scenario_id, d.did_effect, d.treated_pre, d.control_post, d.control_pre
), response_target AS (
    SELECT
        s.scenario_id,
        'human_response_target_minutes'::text AS metric_name,
        h.p50_escalation_to_first_response_min::numeric(14,6) AS observed_treated_post,
        s.target_first_human_response_min::numeric(14,6) AS simulated_treated_post,
        (s.target_first_human_response_min - h.p50_escalation_to_first_response_min)::numeric(14,6) AS simulated_change_vs_observed,
        d.did_effect::numeric(14,6) AS observed_did_effect,
        NULL::numeric(14,6) AS simulated_did_effect
    FROM mart.dim_simulation_scenario s
    CROSS JOIN mart.fct_handoff_funnel h
    CROSS JOIN mart.fct_ai_handoff_did d
    WHERE h.treatment_group = 'treatment'
      AND h.post_period
      AND d.metric_name = 'p50_escalation_to_first_response_min'
), observed_resolution_periods AS (
    SELECT
        treatment_group,
        post_period,
        avg(total_resolution_time_min) FILTER (
            WHERE total_resolution_time_min IS NOT NULL
        )::numeric AS completed_resolution_time_min
    FROM mart.fct_contact_journey
    WHERE channel = 'ai_chat'
      AND escalation_created_ts IS NOT NULL
    GROUP BY treatment_group, post_period
), observed_resolution_comparison AS (
    SELECT
        max(completed_resolution_time_min) FILTER (WHERE treatment_group = 'treatment' AND NOT post_period) AS treated_pre,
        max(completed_resolution_time_min) FILTER (WHERE treatment_group = 'treatment' AND post_period) AS treated_post,
        max(completed_resolution_time_min) FILTER (WHERE treatment_group = 'control' AND NOT post_period) AS control_pre,
        max(completed_resolution_time_min) FILTER (WHERE treatment_group = 'control' AND post_period) AS control_post
    FROM observed_resolution_periods
), simulated_resolution AS (
    SELECT
        scenario_id,
        (
            sum(
                CASE
                    WHEN observed_handoff_completed = 1 AND observed_total_resolution_time_min IS NOT NULL
                        THEN observed_total_resolution_time_min
                    WHEN eligible_for_rescue
                        THEN rescue_probability * simulated_total_resolution_time_min_if_completed
                    ELSE 0
                END
            )
            / nullif(
                sum(
                    CASE
                        WHEN observed_handoff_completed = 1 AND observed_total_resolution_time_min IS NOT NULL THEN 1
                        WHEN eligible_for_rescue THEN rescue_probability
                        ELSE 0
                    END
                ),
                0
            )
        )::numeric AS completed_resolution_time_min
    FROM mart.fct_sim_contact_outcomes
    GROUP BY scenario_id
), resolution_time_metric AS (
    SELECT
        s.scenario_id,
        'completed_resolution_time_minutes'::text AS metric_name,
        o.treated_post::numeric(14,6) AS observed_treated_post,
        s.completed_resolution_time_min::numeric(14,6) AS simulated_treated_post,
        (s.completed_resolution_time_min - o.treated_post)::numeric(14,6) AS simulated_change_vs_observed,
        ((o.treated_post - o.treated_pre) - (o.control_post - o.control_pre))::numeric(14,6) AS observed_did_effect,
        ((s.completed_resolution_time_min - o.treated_pre) - (o.control_post - o.control_pre))::numeric(14,6) AS simulated_did_effect
    FROM simulated_resolution s
    CROSS JOIN observed_resolution_comparison o
), capacity AS (
    SELECT
        scenario_id,
        'additional_human_hours'::text AS metric_name,
        0::numeric(14,6) AS observed_treated_post,
        (sum(expected_added_human_minutes) / 60.0)::numeric(14,6) AS simulated_treated_post,
        (sum(expected_added_human_minutes) / 60.0)::numeric(14,6) AS simulated_change_vs_observed,
        NULL::numeric(14,6) AS observed_did_effect,
        NULL::numeric(14,6) AS simulated_did_effect
    FROM mart.fct_sim_city_week
    WHERE treatment_group = 'treatment' AND post_period
    GROUP BY scenario_id
), all_metrics AS (
    SELECT * FROM main_metrics
    UNION ALL SELECT * FROM handoff_metrics
    UNION ALL SELECT * FROM response_target
    UNION ALL SELECT * FROM resolution_time_metric
    UNION ALL SELECT * FROM capacity
)
SELECT
    a.*,
    CASE a.metric_name
        WHEN 'human_response_target_minutes' THEN 'minutes'
        WHEN 'completed_resolution_time_minutes' THEN 'minutes among completed AI-to-human handoffs'
        WHEN 'additional_human_hours' THEN 'hours across the six-week post period'
        WHEN 'chargebacks_per_1000_orders' THEN 'payment disputes per 1,000 orders'
        WHEN 'handling_cost_per_order' THEN 'USD per order'
        WHEN 'fully_loaded_failure_cost_per_order' THEN 'USD per order'
        WHEN 'support_adjusted_contribution_per_order' THEN 'USD per order'
        WHEN 'total_cost_per_verified_resolution' THEN 'USD per verified resolution'
        WHEN 'average_csat' THEN '1 to 5 score among respondents'
        ELSE 'share'
    END AS unit,
    true AS simulated_flag,
    s.mandatory_label
FROM all_metrics a
JOIN mart.dim_simulation_scenario s USING (scenario_id);

ALTER TABLE mart.fct_sim_metric_results ADD PRIMARY KEY (scenario_id, metric_name);

INSERT INTO mart.dim_model_lineage VALUES
('mart.fct_sim_reference_rates', 'mart', 'issue type and severity', 'mart.fct_contact_journey; intermediate.int_order_outcomes', 'Estimate descriptive outcomes for completed AI-to-agent handoffs answered within two to five minutes.'),
('mart.fct_sim_contact_outcomes', 'mart', 'scenario-contact', 'mart.fct_contact_journey; mart.fct_sim_reference_rates; mart.dim_simulation_scenario', 'Project handoff, abandonment, resolution, repeat-contact, satisfaction, and chargeback outcomes.'),
('mart.fct_sim_order_outcomes', 'mart', 'scenario-order', 'intermediate.int_order_outcomes; mart.fct_sim_contact_outcomes; mart.fct_sim_reference_rates', 'Recalculate support and finance costs through the order-level value-left formula.'),
('mart.fct_sim_city_week', 'mart', 'scenario-city-week', 'mart.fct_sim_order_outcomes', 'Aggregate projected order outcomes into the same city-week grain as the observed experiment.'),
('mart.fct_sim_metric_results', 'mart', 'scenario-metric', 'mart.fct_sim_city_week; mart.fct_sim_contact_outcomes; observed comparison facts', 'Publish current, projected, and four-city comparison results for the presentation.');
