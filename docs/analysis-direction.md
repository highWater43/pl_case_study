# Case-study analytical framework

This document defines the decision question, analytical design, metrics, simulation, experiment, and evidence limits for the ForkDash case study.

## The problem in plain language

ForkDash wants to know whether an AI-first support design should expand.

The design succeeds only when it lowers support cost without making it harder for customers to solve a problem. Success therefore requires measuring money and customer outcomes together.

The decision is not “Did AI handle more contacts?” The decision is:

> Did the new support design lower total cost while preserving resolution, access to help, customer satisfaction, payment outcomes, and future ordering?

## What changed

- All eight cities used the old support design during weeks 1 through 6.
- Four cities moved to the AI-first support design in week 7.
- Four cities kept the old support design.
- A national free-delivery campaign began in week 8 and reached both city groups.

The national campaign matters because it can change order volume, order value, refunds, and support demand. A valid comparison must keep the campaign exposure that affected both city groups.

## The correct 2-by-2 comparison

```text
                              BEFORE WEEK 7             AFTER WEEK 7
                              Weeks 1-6                 Weeks 7-12

Four cities where             Old support       --->    AI-first support
support changed               No campaign               Campaign from week 8

Four cities where             Old support       --->    Old support
support did not change        No campaign               Campaign from week 8

                              changed-city change
2-by-2 result             =   minus unchanged-city change
```

| City group | Before week 7: weeks 1-6 | After week 7: weeks 7-12 |
|---|---|---|
| Four cities where support changed | Old support design. No national campaign. | AI-first support from week 7. National campaign from week 8. |
| Four cities where support did not change | Old support design. No national campaign. | Old support design. National campaign from week 8. |

For every decision metric, the calculation is:

```text
change in the four cities where support changed
minus
change in the four cities where support did not change
```

This comparison helps remove changes that affected both city groups at the same time. It does not provide the certainty of a randomized experiment because the case contains only eight cities and does not say that city assignment was random.

## How the data is organized

The PostgreSQL database follows a simple dbt-style structure:

1. `raw`: preserve the supplied source fields.
2. `staging`: clean labels, types, units, duplicates, and money fields.
3. `intermediate`: connect orders, support contacts, finance entries, customer identities, and journey events.
4. `mart`: publish reusable fact and dimension models.
5. `audit`: store assumptions and validation results.

The central order model is `intermediate.int_order_outcomes`. It gives each order one row containing its order value, support activity, handling cost, refunds, credits, payment disputes, fees, and customer outcome fields.

```text
Orders -----------+
Support contacts -+--> one row per order --> city-week facts --> 2-by-2 results
Finance entries --+           |
Journey events ---+           +--> AI and handoff analysis
Customer map -----+           +--> customer guardrails
Experiment setup -+           +--> value left per order
```

Detailed cleaning decisions are in `docs/data-cleaning-and-modeling.md`.

## Success criteria

### Main money metric

Value left per order:

```text
12% of order value
minus support handling cost
minus refunds and customer credits
minus payment-dispute amount
minus payment-dispute fee
```

Exact synthetic estimates remain reproducible in the database. The decision does not depend on one financial estimate because customer guardrails can block expansion.

### Customer guardrails

- Verified resolution: the contact ended as resolved and the customer did not contact support again for the same order within seven days.
- Abandonment: the customer left before the support contact reached a successful end.
- Repeat support: the customer contacted support again about the same order.
- Satisfaction: the 1-to-5 score among customers who answered the survey, always shown with the survey limitation.
- Payment disputes: the customer asked their payment provider to reverse the charge.
- Future ordering: the customer placed another order within 28 days, using only orders old enough to have a complete follow-up window.
- Cost per verified resolution: all measured support and finance failure costs divided by successfully resolved contacts.

No single metric decides the outcome. The money result must improve while the customer guardrails remain within agreed limits.

## Relationships between the metrics

The relationship analysis uses 96 city-week observations from `mart.fct_metric_relationships`.

| Metric pair | Relationship score | Plain-language interpretation |
|---|---:|---|
| Handling cost per order and abandonment | -0.65 | Lower-cost weeks tended to have more customers leave before resolution. |
| Handling cost per order and payment disputes | -0.48 | Lower-cost weeks also tended to have more payment disputes. |
| Verified resolution and satisfaction | +0.62 | Weeks with more durable resolutions tended to have higher satisfaction among survey respondents. |
| Repeat support and payment disputes | +0.41 | Weeks with more repeat support also tended to have more payment disputes. |

The score runs from -1 to +1. A negative score means the metrics moved in opposite directions. A positive score means they moved in the same direction.

These relationships describe patterns. They do not prove that one metric caused the other. Issue severity, city differences, survey selection, and delayed finance posting can influence both metrics.

## AI support analysis

Two ideas that are often treated as equivalent must remain separate:

- Technical containment: the AI conversation ended without an agent.
- Verified containment: the AI conversation ended as resolved and the customer did not return for support on the same order within seven days.

The close-look analysis answers:

- Which customer problems does AI resolve reliably?
- Which problems end in AI but return later?
- Which problems have high abandonment or payment-dispute risk?
- When a customer asks for a person, does the handoff complete?
- How long does a completed AI-to-human case take to reach a durable resolution?

The existing data does not prove why AI failed. It identifies where to investigate and what the next experiment must measure.

## Simulation question

The simulation does not compare a fictional proposed AI product with the current AI-first experience.

The simulation asks:

> Using the same observed orders and contacts, what would the 2-by-2 result look like if support turnaround improved for the four changed cities after week 7?

The unchanged-city records, all before-period records, order mix, campaign timing, and source identifiers remain unchanged.

## How the same-data simulation works

1. Copy the observed treatment-period contacts and orders. Never overwrite the observed facts.
2. Find comparable AI-to-human cases in the same database where a person responded within two to five minutes.
3. Use their observed resolution, repeat-support, satisfaction, handling, refund, payment-dispute, and total-resolution-time outcomes as reference rates.
4. Under the expected scenario, allow 70 out of 100 failed handoffs to receive the faster reference outcome.
5. Recalculate the contact, order, city-week, and metric results.
6. Apply the same 2-by-2 comparison used for the observed analysis.

The simulation is deterministic. The same source data and assumptions always produce the same result.

## Simulation models

| Model | Purpose |
|---|---|
| `mart.dim_simulation_scenario` | Defines the conservative, expected, and strong scenarios. |
| `mart.dim_simulation_assumption` | Records the value, source, filter, reason, and limitation for every assumption. |
| `mart.fct_sim_reference_rates` | Measures outcomes from comparable faster cases in the same synthetic database. |
| `mart.fct_sim_contact_outcomes` | Stores observed and projected outcomes for each eligible contact. |
| `mart.fct_sim_order_outcomes` | Recalculates support and finance outcomes for the same `order_id`. |
| `mart.fct_sim_city_week` | Aggregates the copied orders back to city and week. |
| `mart.fct_sim_metric_results` | Publishes the observed and simulated 2-by-2 results used in the presentation. |

## Expected same-data simulation result

The table below shows the observed 2-by-2 gap and the simulated gap for the expected scenario.

| Metric | Observed result | Simulated result | Meaning |
|---|---:|---:|---|
| Completed AI-to-human resolution time | 6.6 minutes longer | 5.0 minutes longer | Turnaround improves, but the changed cities remain slower than the comparison trend. |
| Verified resolution | 16 fewer out of 100 | 11 fewer out of 100 | More problems stay solved, but the guardrail still fails. |
| Abandonment | 14 more out of 100 | 8 more out of 100 | Fewer customers leave, but the gap remains material. |
| Repeat support | 11 more out of 100 | 8 more out of 100 | Repeat demand improves but remains worse. |
| Payment disputes | 6.7 more per 1,000 orders | 6.2 more per 1,000 orders | The downstream finance risk changes only slightly. |
| Cost per verified resolution | $5.83 more | $4.40 more | The cost of producing a durable resolution improves but remains higher than the comparison trend. |

The scenario also requires about 16 additional human hours across the six-week after period. Staffing dollars remain unavailable because the source data does not contain wages or agent-capacity cost.

The simulation therefore supports a cautious conclusion: faster support turnaround helps, but this single operational change does not repair the full program.

## The more useful next simulation

The next simulation should not assume that every rescued AI-to-human handoff has the same value. It should group the same observed orders and contacts by:

- customer problem;
- problem severity;
- order value;
- refund risk;
- payment-dispute risk; and
- how often AI has solved that problem without repeat support.

Each group must pass two tests before the recommendation sends it to a person sooner:

1. More problems remain resolved after faster human help.
2. Value left increases after handling, refunds, customer credits, payment disputes, dispute fees, and real staffing cost.

The output is a routing rule. Higher-risk cases receive faster human help. Routine cases remain in AI only where the historical data shows that AI resolves them reliably. This is a proposed next simulation, not an observed result. It requires staffing cost and support-page exit data that the current sources do not contain.

## Decision options

The recommendation section compares three choices in plain language:

1. Continue the current AI-first design. This preserves the largest visible handling savings, but the current resolution and abandonment gaps continue. Do not choose this option.
2. Restore the original support design. This quickly restores familiar access to a person, but gives up AI that works for routine problems. Keep this as the safety fallback.
3. Keep AI for problems it resolves reliably and restore easy human help. This retains useful automation while addressing the access failure, but requires more human capacity and may still miss the guardrails. Recommend this option for a controlled test.

All three choices enter the same randomized test so promotions and city conditions affect them at the same time.

## What the simulation does not prove

- It does not prove that faster response caused the reference outcomes.
- It does not represent results from a completed experiment.
- It does not estimate a new AI model's quality.
- It does not include customers who left the support page before creating a contact.
- It does not include incremental staffing dollars.
- It does not replace the need for a live controlled test.

## The next real experiment

The live test should randomly assign eligible support sessions within the same cities so every group experiences the same campaign and city conditions.

The groups are:

1. Original support design.
2. Current AI-first support design.
3. Redesigned AI-first support with clear human access and a service target.

The redesigned group passes only when:

- Verified resolution stays within the agreed limit of the original design.
- Abandonment and repeat support remain within their agreed limits.
- Mature payment disputes do not increase.
- Value left improves after real staffing cost is included.

## Automated monitoring

Every data load should automatically check:

- whether each source file arrived and row counts remain within an expected range;
- whether support and finance records still connect to orders;
- whether AI problem mix, human response, or total resolution time changed;
- whether verified resolution, abandonment, repeat support, payment disputes, or the money result crossed an agreed limit.

The weekly operating decision is to continue, investigate, or pause the redesigned experience. AI may summarize unusual issue types and sample chats for review. People retain control of metric definitions, thresholds, and the expansion decision.

## Data gaps

- Some support contacts do not contain an order ID and require customer-and-time matching.
- A small number of contacts cannot connect to an order and cannot enter order economics.
- Payment disputes require 28 to 30 days to mature.
- Satisfaction represents survey respondents only.
- The source does not include agent wages, staffing schedules, or queue capacity.
- The source does not count customers who leave the support page before creating a contact.
- The case does not say the original city assignment was random.

## Presentation structure

The presentation should explain the approach in this order:

1. Decision and recommendation.
2. What changed in week 7.
3. The 2-by-2 comparison and national campaign.
4. Data connections and gaps.
5. Metric framework and value-left example.
6. Relationships between the governed metrics.
7. Likely customer journey and AI close look.
8. Same-data simulation with the original 2-by-2 comparison.
9. Targeted next simulation using both customer and financial tests.
10. Recommendation and live experiment.
11. Repeatable data process and AI usage log.

Every slide must work on its own. It should define its population, period, comparison, unit, and limitation when those details affect the conclusion.

## Detailed supporting documents

- `docs/slide-map.md`: maps every presentation slide to the case-study requirement it answers.
- `docs/data-cleaning-and-modeling.md`: records the source cleaning, joins, and fact and dimension models.
- `docs/data-dictionary.md`: defines the published fields and tables.
- `docs/simulation-method.md`: gives the exact same-data simulation steps and reproduction queries.
- `docs/architecture.md`: shows the database structure and lineage.
- `reports/ai-usage-log.md`: records where AI helped, what failed, and how the work was checked.
