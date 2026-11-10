\set ON_ERROR_STOP on

DROP TABLE IF EXISTS audit.test_results;
CREATE TABLE audit.test_results (
    test_name text PRIMARY KEY,
    test_category text NOT NULL,
    passed boolean NOT NULL,
    observed_value text NOT NULL,
    expectation text NOT NULL,
    tested_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'orders_row_count', 'volume', count(*) >= 50000, count(*)::text, 'at least 50,000 orders'
FROM staging.stg_orders;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'orders_primary_key_unique', 'uniqueness', count(*) = count(DISTINCT order_id), count(DISTINCT order_id) || '/' || count(*), 'all staged order IDs unique'
FROM staging.stg_orders;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'contacts_primary_key_unique', 'uniqueness', count(*) = count(DISTINCT contact_id), count(DISTINCT contact_id) || '/' || count(*), 'all staged contact IDs unique after deduplication'
FROM staging.stg_contacts;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'city_assignment_balance', 'experiment', count(*) FILTER (WHERE treatment_group = 'treatment') = 4 AND count(*) FILTER (WHERE treatment_group = 'control') = 4,
       count(*) FILTER (WHERE treatment_group = 'treatment') || ' treatment; ' || count(*) FILTER (WHERE treatment_group = 'control') || ' control',
       'four treatment and four control cities'
FROM staging.stg_experiment_assignment;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'city_week_panel_complete', 'experiment', count(*) = 96, count(*)::text, '8 cities x 12 order weeks = 96 rows'
FROM mart.fct_city_week;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'contact_attribution_rate', 'referential_integrity', avg((attributed_order_id IS NOT NULL)::integer) >= 0.95,
       round(100.0 * avg((attributed_order_id IS NOT NULL)::integer), 2) || '%', 'at least 95% attributed'
FROM intermediate.int_contacts_enriched;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'finance_order_integrity', 'referential_integrity', count(*) FILTER (WHERE o.order_id IS NULL) = 0,
       count(*) FILTER (WHERE o.order_id IS NULL)::text, 'zero orphan finance entries'
FROM staging.stg_finance f
LEFT JOIN staging.stg_orders o USING (order_id);

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'normalized_duration_range', 'validity', count(*) FILTER (WHERE promised_duration_min NOT BETWEEN 20 AND 90 OR delivery_duration_min NOT BETWEEN 0 AND 180) = 0,
       count(*) FILTER (WHERE promised_duration_min NOT BETWEEN 20 AND 90 OR delivery_duration_min NOT BETWEEN 0 AND 180)::text,
       'zero implausible normalized durations'
FROM staging.stg_orders;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'mart_metric_completeness', 'mart', count(*) = 13 AND count(*) FILTER (WHERE did_effect IS NULL) = 0,
       count(*) || ' metrics; ' || count(*) FILTER (WHERE did_effect IS NULL) || ' null effects', '13 non-null DID estimates'
FROM mart.fct_did_estimates;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'visible_contact_deflection_encoded', 'scenario', did_effect < 0, did_effect::text, 'contact-rate DID is negative'
FROM mart.fct_did_estimates
WHERE metric_name = 'contacts_per_1000_orders';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'direct_cost_savings_encoded', 'scenario', did_effect < 0, did_effect::text, 'handling-cost DID is negative'
FROM mart.fct_did_estimates
WHERE metric_name = 'handling_cost_per_order';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'abandonment_guardrail_encoded', 'scenario', did_effect > 0, did_effect::text, 'abandonment-rate DID is positive'
FROM mart.fct_did_estimates
WHERE metric_name = 'abandonment_rate';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'chargeback_countermetric_encoded', 'scenario', did_effect > 0, did_effect::text, 'chargeback-rate DID is positive'
FROM mart.fct_did_estimates
WHERE metric_name = 'chargebacks_per_1000_orders';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'crm_resolution_optimism_visible', 'trust', bool_and(optimism_gap > 0), min(optimism_gap)::text, 'CRM rate exceeds verified rate in every segment'
FROM mart.fct_containment_reconciliation;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'loyalty_scenario_labeled', 'governance', bool_and(simulated_not_observed) AND bool_and(mandatory_label <> ''),
       bool_and(simulated_not_observed)::text, 'all modeled loyalty outputs explicitly labeled simulated'
FROM mart.fct_modeled_loyalty_scenario;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'mart_metrics_documented', 'mart', count(*) FILTER (WHERE display_name IS NULL) = 0,
       count(*) FILTER (WHERE display_name IS NULL)::text, 'zero published DID metrics without catalog definitions'
FROM mart.fct_did_estimates;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'event_study_complete', 'experiment', count(*) = 96,
       count(*)::text, '8 metrics x 12 weeks = 96 event-study rows'
FROM mart.fct_event_study;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'promotion_timing_valid', 'experiment',
       count(*) FILTER (WHERE order_week < 8 AND freedel_orders > 0) = 0
       AND count(*) FILTER (WHERE order_week >= 8 AND freedel_orders > 0) = 10,
       count(*) FILTER (WHERE order_week < 8 AND freedel_orders > 0) || ' pre rows with promo; '
       || count(*) FILTER (WHERE order_week >= 8 AND freedel_orders > 0) || ' post rows with promo',
       'zero pre-promotion rows and ten group-week rows after week 8'
FROM mart.fct_promo_exposure;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'observed_loyalty_guardrail_encoded', 'scenario', did_effect < 0,
       did_effect::text, 'mature 28-day reorder DID is negative'
FROM mart.fct_loyalty_did;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'data_quality_errors_zero', 'validity', count(*) FILTER (WHERE severity = 'error' AND affected_rows > 0) = 0,
       count(*) FILTER (WHERE severity = 'error' AND affected_rows > 0)::text, 'zero failing error-severity data-quality checks'
FROM mart.fct_data_quality;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'journey_event_coverage', 'referential_integrity', count(*) FILTER (WHERE f.contact_id IS NULL) = 0,
       count(*) FILTER (WHERE f.contact_id IS NULL)::text, 'every staged contact has one journey-funnel row'
FROM staging.stg_contacts c
LEFT JOIN intermediate.int_contact_journey_funnel f USING (contact_id);

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'order_issue_integrity', 'referential_integrity', count(*) FILTER (WHERE o.order_id IS NULL) = 0,
       count(*) FILTER (WHERE o.order_id IS NULL)::text, 'every issue maps to a known order'
FROM staging.stg_order_issues i
LEFT JOIN staging.stg_orders o USING (order_id);

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'journey_duration_validity', 'validity', count(*) FILTER (
           WHERE coalesce(ai_minutes_before_escalation, 0) < 0
              OR coalesce(queue_wait_to_accept_min, 0) < 0
              OR coalesce(escalation_to_first_response_min, 0) < 0
              OR coalesce(total_resolution_time_min, 0) < 0
       ) = 0,
       count(*) FILTER (
           WHERE coalesce(ai_minutes_before_escalation, 0) < 0
              OR coalesce(queue_wait_to_accept_min, 0) < 0
              OR coalesce(escalation_to_first_response_min, 0) < 0
              OR coalesce(total_resolution_time_min, 0) < 0
       )::text, 'zero negative elapsed times'
FROM intermediate.int_contact_journey_funnel;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'handoff_group_period_complete', 'mart', count(*) = 4 AND count(*) FILTER (WHERE treatment_group IS NULL) = 0,
       count(*) || ' rows; ' || count(*) FILTER (WHERE treatment_group IS NULL) || ' null groups', 'four treatment/control by pre/post rows'
FROM mart.fct_handoff_funnel;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'handoff_delay_harm_encoded', 'scenario', did_effect > 2,
       did_effect::text, 'P90 escalation-to-human-response DID exceeds two minutes'
FROM mart.fct_ai_handoff_did
WHERE metric_name = 'p90_escalation_to_first_response_min';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'launch_decision_contract_operational', 'mart', overall_status = 'FAIL' AND passed_metrics >= 1 AND failed_metrics >= 1,
       overall_status || '; ' || passed_metrics || ' pass; ' || failed_metrics || ' fail', 'one transparent overall status with both economic upside and guardrail failure'
FROM mart.fct_launch_decision_summary;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'number_provenance_complete', 'governance', count(*) >= 8 AND count(*) FILTER (WHERE reproduction_query = '') = 0,
       count(*)::text, 'at least eight published metrics with non-empty reproduction queries'
FROM mart.dim_number_provenance;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'team_metric_contract_complete', 'governance', count(DISTINCT team_name) >= 8 AND count(*) >= 18,
       count(DISTINCT team_name) || ' teams; ' || count(*) || ' metric mappings', 'at least eight teams and eighteen governed mappings'
FROM mart.dim_team_metric;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'assumption_registry_complete', 'governance', count(*) >= 12,
       count(*)::text, 'at least twelve explicit assumptions'
FROM audit.assumption_registry;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_scenarios_labeled', 'simulation', count(*) = 3 AND bool_and(simulated_flag) AND bool_and(mandatory_label <> ''),
       count(*) || ' scenarios; all labeled=' || bool_and(simulated_flag), 'three explicitly labeled simulation scenarios'
FROM mart.dim_simulation_scenario;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_order_coverage', 'simulation', count(*) = 3 * (SELECT count(*) FROM intermediate.int_order_outcomes),
       count(*)::text, 'one row per scenario and observed order'
FROM mart.fct_sim_order_outcomes;

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_expected_handoff_improves', 'simulation', simulated_treated_post > observed_treated_post,
       observed_treated_post || ' to ' || simulated_treated_post, 'expected scenario increases handoff completion'
FROM mart.fct_sim_metric_results
WHERE scenario_id = 'FAST_HELP_EXPECTED' AND metric_name = 'handoff_completion_rate';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_expected_abandonment_improves', 'simulation', simulated_treated_post < observed_treated_post,
       observed_treated_post || ' to ' || simulated_treated_post, 'expected scenario reduces queue abandonment'
FROM mart.fct_sim_metric_results
WHERE scenario_id = 'FAST_HELP_EXPECTED' AND metric_name = 'queue_abandonment_rate';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_expected_resolution_improves', 'simulation', simulated_treated_post > observed_treated_post,
       observed_treated_post || ' to ' || simulated_treated_post, 'expected scenario increases verified resolution'
FROM mart.fct_sim_metric_results
WHERE scenario_id = 'FAST_HELP_EXPECTED' AND metric_name = 'verified_resolution_rate';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_expected_resolution_time_improves', 'simulation', simulated_treated_post < observed_treated_post,
       observed_treated_post || ' to ' || simulated_treated_post, 'expected scenario reduces completed AI-to-human resolution time'
FROM mart.fct_sim_metric_results
WHERE scenario_id = 'FAST_HELP_EXPECTED' AND metric_name = 'completed_resolution_time_minutes';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_expected_chargebacks_improve', 'simulation', simulated_treated_post < observed_treated_post,
       observed_treated_post || ' to ' || simulated_treated_post, 'expected scenario reduces payment disputes'
FROM mart.fct_sim_metric_results
WHERE scenario_id = 'FAST_HELP_EXPECTED' AND metric_name = 'chargebacks_per_1000_orders';

INSERT INTO audit.test_results (test_name, test_category, passed, observed_value, expectation)
SELECT 'simulation_staffing_gap_disclosed', 'simulation', bool_and(assumption_value = 'not available'),
       string_agg(DISTINCT assumption_value, ', '), 'incremental staffing cost remains explicitly unavailable'
FROM mart.dim_simulation_assumption
WHERE assumption_name = 'staffing_cost';

CREATE VIEW audit.v_failed_tests AS
SELECT * FROM audit.test_results WHERE NOT passed ORDER BY test_category, test_name;
