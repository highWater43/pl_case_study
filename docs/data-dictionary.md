# Data dictionary

## Raw sources

| Relation | Grain | Important fields | Trust note |
|---|---|---|---|
| `raw.orders_ops` | Source order row | order, customer, city, timestamp, value, durations, status, promo | Durations use different units by source system. Money may include a dollar sign. |
| `raw.support_contacts` | CRM extract row | contact, references, timestamp, channel, issue, handling, end reason, CRM resolution, CSAT | Contains duplicate extract versions, missing references, label variants, and survey nonresponse. |
| `raw.finance_ledger` | Ledger entry | ledger ID, order, posting date, signed amount, entry type, reason | Posting date lags the originating order and chargeback fees are separate entries. |
| `raw.customer_map` | Identity-map candidate | CRM reference, operations customer, validity, method, confidence | Contains stale lower-confidence alternatives. |
| `raw.experiment_assignment` | City | treatment group, launch week/date, policy | Four treatment and four control cities. |
| `raw.loyalty_scenario` | Customer and scenario | modeled churn and order reduction | Assumption-only synthetic scenario. |

## Staging models

| Relation | Grain | Main responsibility |
|---|---|---|
| `staging.stg_orders` | Order | Typed values, status normalization, source-unit conversion, case-study week. |
| `staging.stg_contacts` | Deduplicated contact | Reference and label normalization, valid CSAT parsing, latest-record selection. |
| `staging.stg_finance` | Ledger entry | Signed amount and absolute cost amount, standardized types. |
| `staging.stg_customer_map` | Canonical CRM reference | Active best mapping with candidate count and confidence. |
| `staging.stg_experiment_assignment` | City | Typed treatment assignment and launch metadata. |
| `staging.stg_loyalty_scenario` | Customer and scenario | Typed modeled loyalty values with simulation flag. |

## Intermediate models

| Relation | Grain | Main responsibility |
|---|---|---|
| `intermediate.int_contacts_attributed_base` | Contact | Order and customer attribution, method, confidence, channel cost. |
| `intermediate.int_contacts_enriched` | Contact | Seven-day follow-up, verified resolution, abandonment. |
| `intermediate.int_order_contact_summary` | Order | Contact counts, channel mix, cost, repeat contact, CSAT. |
| `intermediate.int_order_finance_summary` | Order | Refund, credit, chargeback principal, fee, and posting lag. |
| `intermediate.int_order_outcomes` | Order | Conformed analytical spine across all sources. |

## Mart

| Relation | Grain | Main responsibility |
|---|---|---|
| `mart.fct_city_week` | City-week | Additive experiment components and fully loaded economics. |
| `mart.fct_customer_issue_episode` | Issue/contact order | Reorder eligibility, right-censoring, next-order behavior. |
| `mart.fct_customer_summary` | Customer | Exposure, cost, and explicitly modeled loyalty risk. |
| `mart.fct_finance_maturity` | Order week and group | Chargeback visibility by follow-up window. |
| `mart.fct_data_quality` | Quality check | Affected rows, severity, and handling note. |
| `mart.dim_week` | Week | Calendar dates, post period, promotion period. |

## Labeled simulation mart

| Relation | Grain | Main responsibility |
|---|---|---|
| `mart.dim_simulation_scenario` | Scenario | Name the conservative, expected, and strong faster-help policies and their response targets. |
| `mart.dim_simulation_assumption` | Scenario-assumption | Record the source, filter, rationale, and limitation behind every projected change. |
| `mart.fct_sim_reference_rates` | Issue type and severity | Calculate observed outcomes for similar AI-to-agent cases answered within two to five minutes. |
| `mart.fct_sim_contact_outcomes` | Scenario-contact | Project handoff, abandonment, resolution, repeat-contact, satisfaction, and payment-dispute probabilities. |
| `mart.fct_sim_order_outcomes` | Scenario-order | Recalculate handling, refunds, credits, payment disputes, fees, and value left without overwriting observed orders. |
| `mart.fct_sim_city_week` | Scenario-city-week | Aggregate projected orders into the same grain as the observed city experiment. |
| `mart.fct_sim_metric_results` | Scenario-metric | Publish the current, projected, and before-and-after city-comparison results used by the presentation. |

All simulation relations carry an explicit simulation label. The expected-value method uses no random draws, so identical inputs and scenario versions produce identical results. Incremental staffing dollars remain excluded because the sources do not contain wages or agent-capacity costs.

## Fact and dimension relations

| Relation | Grain | Question answered |
|---|---|---|
| `mart.dim_metric` | Metric | What does the metric mean, who owns it, and when is it decision-ready? |
| `mart.fct_weekly_kpis` | City-week | What moved each week in each city? |
| `mart.fct_did_estimates` | Metric | What changed in treatment cities beyond the control-city change? |
| `mart.fct_executive_scorecard` | Metric | Did the movement help or hurt the primary, guardrail, and counter metrics? |
| `mart.fct_event_study` | Metric-week | Were gaps stable before launch and how did they evolve after launch? |
| `mart.fct_containment_reconciliation` | Group-period | How much does CRM resolution overstate durable resolution? |
| `mart.fct_loyalty_guardrails` | Group-period | What is mature observed 28-day reorder behavior? |
| `mart.fct_loyalty_did` | One estimate | What is the observed reorder difference-in-differences effect? |
| `mart.fct_modeled_loyalty_scenario` | Group | What does the labeled assumption-only loyalty scenario show? |
| `mart.fct_finance_maturity_curve` | Week-group | How much of eventual chargeback activity is visible at each lag? |
| `mart.fct_metric_relationships` | Metric pair | Which costs and experience measures co-move descriptively? |
| `mart.fct_promo_exposure` | Week-group | Was `FREEDEL` exposure comparable across groups? |
| `mart.fct_negative_control` | Group-period | Did promised duration, a pre-support measure, move unexpectedly? |
| `mart.fct_data_trust` | Quality check | What can be trusted, what is qualified, and how was it handled? |
| `mart.fct_source_mapping_summary` | Source and mapping status | Which support and finance records connect to an order, and which records cannot enter order economics? |

## Cost assumptions

| Event | Cost |
|---|---:|
| AI-only contact | $0.55 |
| AI transferred to agent | $5.75 |
| Phone contact | $6.80 |
| Email contact | $3.10 |
| Chargeback processor fee | $18.00 |
| Contribution margin | 12% of order value |

Refunds, credits, chargeback principal, and chargeback fees are additive cost components. Handling cost is not added twice for transferred AI contacts.
