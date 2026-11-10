# Slide map to the case-study requirements

| Slide | Case-study requirement | Purpose |
|---:|---|---|
| 1 | Cover | State the decision question. |
| 2 | 1. Executive summary | Recommend redesigning the AI-to-human handoff and state the two customer outcomes that make expansion unsafe. |
| 3 | 2. Data trust | Explain the week 7 change and the two city groups. |
| 4 | 2. Data trust | Show the four-city by four-city, before-and-after comparison and keep the national campaign in both groups. |
| 5 | 2. Data trust | Report exact, inferred, and missing source connections plus finance and staffing gaps. |
| 6 | 3. Metric framework | Define the North Star and the customer guardrails. |
| 7 | 3. Metric framework | Trace one $50 order through support and finance costs so the audience understands value left. |
| 8 | 3. Metric framework | Give every team one plain-language metric while keeping value left per order as the shared North Star. |
| 9 | 4. Relationships between metrics | Show that lower handling cost moved with more abandonment and more payment disputes across 96 city-weeks. |
| 10 | 4. Relationships between metrics | Show that verified resolution moved with satisfaction, while repeat support moved with payment disputes. |
| 11 | 5. Diagnosis | Explain in plain language what most likely happened after week 7, why the comparison supports that explanation, and why a randomized test is still required. |
| 12 | 5. Diagnosis | Compare AI-only handling with verified resolution by problem type. |
| 13 | 6. Recommendations | Compare the observed and simulated results using the same 2-by-2 design and the same underlying records. |
| 14 | 6. Recommendations | Explain the source data and decision purpose for customer problem, problem severity, and order value. |
| 15 | 6. Recommendations | Explain the source data and decision purpose for refund risk, payment-dispute risk, and how often AI solved the problem before. Require both verified resolution and value left to improve. |
| 16 | 6. Recommendations | Compare continuing the current design, restoring the original design, and redesigning AI-first support. State the benefit, risk, and position for each choice. |
| 17 | 7. Operating approach | Define the three-group experiment and measurable pass criteria. |
| 18 | 7. Operating approach | Show the repeatable raw, staging, intermediate, fact, and dimension process plus plain-language checks for complete files, correct order connections, customer wait time, successful resolution, and unacceptable customer or financial results. |
| 19 | 8. AI usage log | State where AI helped, what failed, and how every output was verified. |

## Evidence boundaries

- Observed synthetic results come from the existing order, support, finance, and customer-journey facts.
- Slide 13 is explicitly labeled simulated and reads from `mart.fct_sim_metric_results`.
- Slides 14 and 15 describe a proposed next simulation. They do not present completed or observed results.
- The simulated result holds all before-period and unchanged-city records fixed, changes only eligible after-period records in the four changed cities, and reruns the same 2-by-2 calculation.
- Every simulated order remains linked to its observed `order_id` in `mart.fct_sim_order_outcomes`.
- Incremental staffing dollars are not projected because the case sources do not contain agent wage or capacity costs.
- Customers who leave the support page before creating a contact require new instrumentation and remain a reported gap.

## Narrative rule

The main presentation explains the decision approach instead of defending an exact synthetic financial estimate. The detailed financial calculation remains reproducible in the database and documentation for interview questions.
