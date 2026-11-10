# Causal Design for ForkDash Contact Simplification

## Executive recommendation

Treat the week-7 policy change as a quasi-experiment, not as a before/after dashboard comparison. The primary design should compare the change in the four launch cities with the contemporaneous change in the four unchanged cities, while preserving city and calendar-week effects. Report effect sizes and uncertainty for customer, operational, and financial outcomes together. Do not call lower contact volume a causal benefit unless downstream guardrails remain acceptable.

The evidence should be presented as **directionally causal but not equivalent to a randomized trial**. There are only eight cities, treatment assignment was not stated to be random, and the post-period is six weeks. Serial correlation can make ordinary difference-in-differences standard errors too small, as shown by Bertrand, Duflo, and Mullainathan ([NBER working paper](https://www.nber.org/papers/w8841)). With only four treated groups, conventional clustered inference is also fragile; Ferman and Pinto show that few-treated-group methods can misbehave under group-size heteroskedasticity ([Review of Economics and Statistics paper](https://doi.org/10.1162/rest_a_00759)).

## 1. Estimand and analysis contract

Define the decision question before generating data:

> Among orders and customers in the four launch cities, what was the effect of Contact Us Simplification over weeks 7-12 relative to the counterfactual change that would have occurred without the policy?

Use three estimands rather than one blended score:

1. **Operational effect:** contacts, human-assisted contacts, and handling cost per eligible order.
2. **Customer-harm effect:** unresolved and repeat contacts, CSAT response and score, refunds/credits, chargebacks, and disputed dollars per eligible order.
3. **Business effect:** fully loaded service-recovery cost and contribution margin per order, plus mature repeat-purchase outcomes.

The primary population is all placed orders, including cancellations when the source definition says they are present. Publish a second view for completed orders, but never switch denominators after seeing results. For support metrics, prefer per-order or per-1,000-order rates over per-contact rates because the policy directly changes whether a contact is created. A per-contact denominator conditions on a post-treatment event and can make the remaining contacts appear artificially healthier or worse.

Before generation, lock these assumptions in metadata:

- Treatment cities: Harbor City, Northgate, Riverton, Eastfield.
- Comparison cities: Westbrook, Lakeside, Summit, Ridgemont.
- Launch timestamp: set an exact timestamp, ideally Monday 2026-07-13 00:00 local time, rather than the ambiguous phrase "in week 7."
- Primary pre-period: weeks 1-6. Primary post-period: weeks 7-12.
- Sensitivity period: exclude week 7 as a transition week.
- Analysis cutoff: fixed timestamp after week 12, with outcome-specific maturity rules.
- Synthetic seed and scenario version: immutable and stored alongside every build.

## 2. Core difference-in-differences design

At city-week grain, estimate:

```text
y_city_week = city fixed effects
            + week fixed effects
            + beta * treated_city * post_week7
            + error
```

Weighting is a business choice, not a technical default:

- Use **order-weighted** estimates for the total company/customer impact.
- Also show **equal-city-weighted** estimates so one high-volume city cannot determine the story.
- If they disagree, report the heterogeneity rather than selecting the preferred answer.

For count outcomes, show transparent rate-based DiD in the presentation and use Poisson or negative-binomial models with an order-volume offset as a robustness check. For binary order/customer outcomes, linear probability models keep percentage-point effects interpretable; logistic models can be secondary checks. For dollar outcomes, show both mean dollars per order and winsorized/bootstrap sensitivity because chargebacks can be heavy-tailed.

Because all launch cities adopt in the same week, a standard two-group, multi-period DiD is sufficient. If ForkDash later rolls out at different times, replace the two-way-fixed-effects shortcut with cohort/time-specific effects. Callaway and Sant'Anna formalize group-time average treatment effects for multiple periods and varying treatment timing ([Journal of Econometrics](https://doi.org/10.1016/j.jeconom.2020.12.001)); Roth and coauthors provide a practical synthesis of when modern DiD methods are needed ([Journal of Econometrics](https://doi.org/10.1016/j.jeconom.2023.03.008)).

## 3. Event-study and parallel-trend diagnostics

Plot treated-minus-control differences by week, normalized to week 6. The plot should show weeks 1-6 and every post week separately for these outcomes:

- contacts per 1,000 orders;
- human-assisted contacts per 1,000 orders;
- fully loaded recovery cost per order;
- repeat contacts within seven days per 1,000 orders;
- chargebacks and disputed dollars per 1,000 mature orders;
- 28-day repeat purchase for mature customer cohorts.

Do not interpret "pre-trend coefficients are not significant" as proof of parallel trends. Such tests may have low power, and conditioning the analysis on passing a pre-test can distort inference, as Roth demonstrates ([American Economic Review: Insights](https://doi.org/10.1257/aeri.20210236)). Instead:

- show the magnitude and slope of pre-period differences with confidence intervals;
- compare baseline level and trend balance by city;
- run leave-one-city-out estimates;
- re-estimate using city-specific linear trends only as a sensitivity check, not the preferred model;
- report how large a differential trend would be required to erase the result.

For a formal robustness appendix, apply Rambachan-Roth sensitivity analysis: state how much larger the post-period deviation from parallel trends would need to be than the worst pre-period deviation before the conclusion changes ([Review of Economic Studies](https://doi.org/10.1093/restud/rdad018)).

## 4. Handling the week-8 FREEDEL promotion

The national promotion starts one week after launch. Calendar-week fixed effects absorb its company-wide level shock, but not differential exposure if promo adoption or promo response differs between treatment and comparison cities.

Recommended treatment:

1. Keep the primary estimand as intent-to-treat and do **not** automatically condition on `promo_code`. For repeat ordering and loyalty, promo use occurs after treatment and could be part of the policy's downstream path; controlling for it can introduce post-treatment bias.
2. Show promo penetration and promo-driven order lift by treatment group and week.
3. Run a sensitivity analysis on non-FREEDEL orders and a model with `treated × post × FREEDEL`, clearly labeling both as conditional/descriptive.
4. Construct a synthetic scenario in which the promotion produces a common volume shock plus modest city-level variation. Do not design perfectly balanced data merely to make the model easy.
5. If promo response diverges sharply before launch or by baseline customer mix, lower causal confidence and emphasize matched-city or reweighted estimates.

The fact and dimension mart layer should expose `is_freedel`, `promo_start_week`, and precomputed numerator/denominator components, but it should not silently bake promo adjustment into the headline metrics.

## 5. Lagged finance and loyalty outcomes

Use outcome windows tied to the order timestamp, not finance posting week:

- contact within 24 hours and within 7 days of order;
- repeat contact for the same order within 7 days of first contact;
- refunds/credits within 14 days of order;
- chargeback and fee outcomes within 30 or 45 days of order;
- next order and active-again outcomes within 28 days.

Every row needs `analysis_cutoff_ts`, `outcome_window_end_ts`, and `is_mature`. Only mature orders/cohorts enter a finalized rate. Show an immature pipeline count separately. Finance `posted_date` is essential for reconciliation, but the causal cohort belongs to the originating order/event date. Otherwise, posting lag can create a false late spike.

For loyalty:

- Compute a behavioral proxy from order history: 28-day repeat-purchase rate, days to next order, and orders per active customer.
- Restrict the 28-day metric to index orders/customers with a complete 28-day observation window.
- Use Kaplan-Meier or discrete-time hazard estimates as a secondary analysis when follow-up varies.
- Treat any separately simulated loyalty score as an illustrative scenario, not observed evidence. Keep it in a clearly named synthetic-only table or appendix.
- Do not present 56- or 90-day retention as measured from a 12-week source window.

Short experiments may not recover long-term effects, and short-run treatment effects need not equal long-run effects; a review of online controlled experiments highlights this challenge ([The American Statistician](https://doi.org/10.1080/00031305.2023.2257237)). This is a reason to recommend a longer holdout, not to invent certainty.

## 6. Inference with eight cities

The effective treatment assignment occurs at city level, so millions of order rows do not create millions of independent treatment units. With eight clusters:

- cluster at city and label conventional cluster-robust intervals as approximate;
- show wild-cluster-bootstrap intervals as a sensitivity check, with the small-cluster limitation disclosed;
- report leave-one-treated-city-out and leave-one-control-city-out ranges;
- show all 70 possible four-of-eight treatment-placebo assignments as a diagnostic distribution;
- call the permutation result an exact randomization test only if the synthetic design explicitly states that assignment was random/exchangeable;
- emphasize effect size, business materiality, and cross-city consistency over a binary p-value.

Pre-register practical decision thresholds, for example: proceed only if fully loaded cost falls while chargeback rate, repeat-contact rate, and mature repeat purchase remain within stated non-inferiority bounds. The experiment-design literature recommends defining primary success and guardrail metrics before analysis rather than selecting them after results are known ([Harvard Data Science Review](https://hdsr.mitpress.mit.edu/pub/aj31wj81/release/1)).

## 7. Fact-and-dimension-mart design that preserves causal meaning

### Conformed dimensions

- `dim_date`: date, ISO week, case-study week, pre/post/transition labels.
- `dim_city`: city, treatment assignment, launch timestamp, rollout cohort.
- `dim_customer`: canonical operations customer ID and source survivorship fields.
- `bridge_customer_identity`: CRM reference to operations ID with match method, confidence, valid-from/to, and ambiguity flag.
- `dim_metric`: owner, grain, numerator, denominator, window, exclusions, maturity rule, direction, and guardrail threshold.

### Atomic facts

- `fct_orders`: one row per source order, with status and operational timestamps.
- `fct_contacts`: one row per CRM contact, preserving unmatched and ambiguous references.
- `fct_finance_entries`: one row per ledger entry; never overwrite or net entries before audit.

### Intermediate models

- `int_order_contact_outcomes`: one row per order with first contact, channel sequence, 24-hour/7-day contact flags, human-assist flag, repeat-contact count, and traceable contact IDs.
- `int_order_finance_outcomes`: one row per order with additive refund, credit, chargeback principal, chargeback fee, and maturity components.
- `int_customer_order_sequence`: one row per customer-order with previous/next order timestamps and observation-window eligibility.
- `int_city_week_metric_components`: additive numerators and denominators only.

### Marts and fact models

- `fct_city_week_experiment`: treated/control, pre/post, order counts, metric numerators, denominators, and data-quality coverage.
- `fct_order_economics`: order value, 12% contribution margin, handling cost, recovery cost, and net contribution.
- `fct_customer_cohort`: acquisition/index cohort, mature 28-day outcomes, and censoring flags.
- `fct_data_quality`: join coverage, duplicate rates, missing references, survey response rate, posting-lag distribution, and reconciliation deltas.
- `fct_experiment_scorecard`: governed ratios calculated from summed components, never averages of averages.

Every published metric should drill through to atomic order, contact, and ledger identifiers. Persist `model_version`, `synthetic_seed`, `generated_at`, and `analysis_cutoff` on build audit tables. Keep raw recorded resolution and an independently derived resolution concept as separate fields; do not silently replace the CRM definition.

## 8. Required falsification and robustness checks

1. **Placebo launch weeks:** repeat the DiD using pre-period pseudo-launches, recognizing that only six pre weeks limit power.
2. **Negative controls:** metrics the policy should not directly affect, such as promised delivery duration at order creation. A treatment "effect" here signals imbalance or pipeline error.
3. **Source reconciliation:** ledger sums to finance totals; every matched contact maps to exactly one canonical order/customer; unmatched contacts remain counted in coverage diagnostics.
4. **City influence:** leave-one-city-out estimates and city-specific effects.
5. **Weighting:** equal-city versus order-weighted results.
6. **Transition timing:** include versus exclude week 7.
7. **Outcome maturity:** mature-only versus naive posted-week trends to demonstrate posting-lag bias.
8. **Missingness:** CSAT response propensity and join-match coverage by treatment/week; never assume missing-at-random without evidence.
9. **Spillovers:** check whether customers order across cities or support staffing is pooled. Either can contaminate the control group.
10. **Synthetic truth recovery:** store the data-generating treatment effects and verify that the pipeline recovers them within simulation uncertainty. Do not expose hidden truth in the executive mart used for the presentation.

## 9. Recommended future test

The next rollout should be a prospective cluster-randomized or stepped-wedge test with more units than eight cities, fixed assignment rules, a predeclared metric contract, and a persistent holdout long enough to mature chargeback and repeat-purchase outcomes. If city-level randomization is infeasible, randomize eligible customer sessions within cities while guarding against cross-session contamination. Pre-period covariates can improve precision in randomized experiments; Microsoft's CUPED paper demonstrates variance reduction using pre-experiment data ([WSDM 2013 paper](https://doi.org/10.1145/2433396.2433413)).

The decision rule should be multi-objective: scale only when the policy achieves meaningful fully loaded savings and meets customer-harm and loyalty non-inferiority thresholds. A lower visible contact count alone is not evidence that customer need disappeared.
