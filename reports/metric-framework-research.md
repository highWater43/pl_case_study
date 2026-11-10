# Metric Framework Research for ForkDash Contact Simplification

## Executive recommendation

Do not manage Contact Us Simplification to contact count, phone share, or platform-reported deflection alone. Use a three-level scorecard:

1. **Business outcome:** support-adjusted contribution per completed order.
2. **Customer outcome guardrails:** verified resolution, repeat contact, chargebacks, CSAT with response coverage, and 28-day repeat ordering.
3. **Operational diagnostics:** channel mix, AI transfer, abandonment, time to resolution, and data-linkage coverage.

The fact and dimension mart layer should make the denominator, time window, event anchor, and eligible population explicit for every metric. It should publish raw platform measures separately from verified outcome measures.

## Why platform metrics are not enough

Amazon Connect defines first-contact resolution as a closed case with exactly one voice, chat, or email contact. That is useful but depends on correct case closure and case-to-contact linkage. It excludes open cases from the rate, which can bias the result upward when unresolved cases remain open ([Amazon Connect metric definitions](https://docs.aws.amazon.com/connect/latest/adminguide/metrics-definitions.html)).

Microsoft's bot dashboard documents a more serious naming trap: its bot "deflection" count can include conversations the user abandoned as well as conversations the bot resolved. A lower escalation rate can therefore coexist with worse customer outcomes ([Microsoft bot dashboard](https://learn.microsoft.com/en-us/dynamics365/customer-service/use/oc-bot-dashboard)). Google defines virtual-agent resolution as an interaction completed without escalation, which is still a system event rather than proof that the customer's underlying problem stayed solved ([Google CCAI data dictionary](https://docs.cloud.google.com/contact-center/ccai-platform/docs/data-dictionary)).

For ForkDash, call "no human transfer" **technical containment** and reserve **verified containment** for cases with positive resolution evidence and no adverse follow-up.

## Recommended governed mart metrics

| Metric | Production definition | Grain and denominator | Why it matters | Main caution |
|---|---|---|---|---|
| Contact rate | Distinct contacts / completed orders | City-week; all completed orders | Normalizes workload for order volume | Do not use raw contact count; the week 8 promotion changes volume |
| Technical AI containment | AI-started contacts with no human transfer / AI-started contacts | Contact; AI-started contacts | Measures routing outcome | An abandonment can look like success if only transfer is observed |
| Verified AI containment | AI-started contacts with a resolved signal, no human transfer, no same-order/issue repeat contact in 7 days, and no later chargeback in the observation window / eligible AI-started contacts | Contact; contacts with enough follow-up and a trustworthy order/customer link | Measures durable self-service | Requires explicit follow-up eligibility and linkage coverage |
| Human escalation rate | AI-started contacts transferred to an agent / AI-started contacts | Contact | Diagnoses workload shifted to agents | A decrease can be caused by blocked access rather than better automation |
| Abandonment rate | AI-started contacts ending through abandonment, timeout, or user exit before a resolved signal / AI-started contacts | Contact | Captures fail-quietly behavior | Keep separate from containment and resolution |
| First-contact resolution | Eligible issue episodes with one contact and no same-order/issue follow-up in 7 days / eligible issue episodes | Issue episode; linked episodes with 7 days of follow-up | Connects quality and workload | CRM `resolved` alone is not sufficient; report observed linkage coverage |
| Repeat-contact rate, 72h and 7d | First contacts followed by another contact for the same order and normalized issue within the window / first contacts eligible for full follow-up | Issue episode | Detects delayed work hidden by lower initial contact volume | Use both windows; customer-only matching can merge unrelated issues |
| Contacts per issue episode | All contacts in an episode / issue episodes | Issue episode | Captures long-tail workload better than binary repeat rate | Needs deterministic episode rules and sensitivity analysis |
| Observed CSAT | Average score among submitted surveys | Contact; survey respondents | Direct sentiment signal | Optional response means this is respondent CSAT, not population CSAT |
| CSAT response rate | Submitted valid surveys / survey-eligible contacts | Contact | Shows whether observed CSAT is representative enough to interpret | Always segment by channel, issue, treatment, and resolved status |
| Adjusted CSAT | Weighted mean using response-propensity weights from pre-response variables | Contact; eligible contacts with supported covariates | Sensitivity check for changing respondent mix | Weighting cannot repair bias from unobserved drivers; cap extreme weights |
| Support cost per completed order | Sum of contact handling cost / completed orders | City-week | Compares cost across changing volume | Use provided handling costs and keep transferred AI at $5.75 total, not AI plus another agent charge |
| Customer-remediation cost per order | Absolute refunds and credits / completed orders | Order cohort | Captures visible service recovery cost | Standardize ledger signs and distinguish goodwill credits from refund reversals |
| Chargeback incidence | Orders with an initial chargeback / completed card orders | Order cohort, anchored to order week | Captures customers bypassing support | Finance posting date lags the service event; use mature cohorts |
| Gross chargeback loss | Initial disputed amount plus $18 fee per chargeback | Order cohort | Measures economic exposure | Report recovered amounts separately and avoid double counting refunds |
| Net chargeback loss | Initial disputed amount plus fees minus recovered dispute amounts | Order cohort with a fixed maturity window | Measures realized loss | Recent cohorts are right-censored |
| Support-adjusted contribution | 12% of completed order value minus handling cost, refunds/credits, net chargeback loss, and fees | Order or city-week | Best combined business outcome in the supplied context | Label simulated or unavailable cost components explicitly |
| Support-adjusted contribution per completed order | Support-adjusted contribution / completed orders | City-week | Recommended executive outcome | Present components beside the total so a favorable aggregate cannot hide customer harm |
| 28-day repeat-order rate | Customers placing another completed order within 28 days / customers with a completed index order and 28 days of observable follow-up | Customer-order cohort | Behavioral loyalty guardrail | Exclude right-censored index orders and avoid counting the index order |
| Time to next order | Days from index completed order to next completed order; analyze with survival curves | Customer-order cohort | Uses timing and handles variable follow-up more honestly | Promotion exposure and baseline customer frequency are confounders |
| Data linkage coverage | Contacts linked confidently to an order / all contacts | Contact, segmented by city/channel/week | Makes downstream metric reliability visible | Never silently drop unlinked contacts from numerator and denominator |

## Definitions to encode in the fact and dimension mart layer

### Issue episode

An issue episode is the ordered cluster of contacts sharing a trustworthy `order_id` and normalized `issue_type`, where adjacent contacts occur no more than seven days apart. If `order_id` is unavailable, customer-level matching should be labeled lower confidence and should require a narrower time window plus compatible issue types.

Publish:

- `episode_linkage_method`: direct order reference, mapped customer plus time, or unlinked.
- `episode_linkage_confidence`: high, medium, or excluded.
- `is_repeat_72h` and `is_repeat_7d`.
- `contact_sequence_number` and `contacts_in_episode`.

### First-contact resolution

Use two measures:

- `crm_reported_fcr`: CRM says resolved on the first contact.
- `verified_fcr_7d`: one-contact episode, positive resolution evidence, and no repeat within seven days.

This separation is consistent with the industry difficulty of combining disposition codes, survey answers, case reopening, and observed repeat contacts. NICE describes FCR as resolution without follow-up and notes that it is commonly assessed using surveys, quality review, and system data rather than a single field ([NICE FCR overview](https://www.nice.com/faq/general-customer-experience-contact-center-faqs/what-is-fcr-in-contact-centers)).

### AI containment and resolution

Publish four mutually understandable outcomes for AI-started contacts:

1. Verified self-service resolution.
2. Human escalation.
3. Explicit abandonment or timeout.
4. Unknown outcome.

Do not force unknown and abandoned sessions into "deflected." Microsoft distinguishes resolution, escalation, and abandonment in its current business-value metrics and calls abandonment a fail-quietly signal ([Microsoft Copilot Studio metric reference](https://learn.microsoft.com/en-us/microsoft-copilot-studio/guidance/agent-business-value-metrics-reference)).

### CSAT and survey coverage

Pew's total survey error framework explicitly separates nonresponse error, measurement error, coverage error, sampling error, and processing error. Optional post-contact surveys therefore need a response-rate companion and a respondent-mix check, not just an average score ([Pew Research survey methodology](https://www.pewresearch.org/u-s-survey-methodology/)).

Minimum publication bundle:

- Mean CSAT and distribution of scores.
- Response rate.
- Respondent counts.
- Response rate and CSAT by channel, issue, treatment/control, resolved status, and week.
- Unadjusted and propensity-weighted sensitivity estimates when sample size permits.

Do not fill missing CSAT with zero, carry scores forward, or call the respondent mean the satisfaction of all customers.

### Chargebacks

Anchor chargeback outcomes to the order date for causal analysis, but retain `posted_date` for finance reconciliation. Use a maturity flag such as `has_28d_finance_followup` and compare only equally mature order cohorts.

Visa recommends tracking dispute activity as a proportion of sales, separating initial from net disputes after responses, and segmenting channels when their risk differs ([Visa Dispute Management Guidelines](https://bd.visa.com/content/dam/VCOM/global/support-legal/documents/merchants-dispute-management-guidelines.pdf)). Stripe confirms the accounting pattern: a dispute reverses the payment and adds a dispute fee, with later response-related outcomes recorded separately ([Stripe dispute fees FAQ](https://support.stripe.com/questions/dispute-fees-faq?locale=en-GB)). ForkDash's supplied $18 fee should override outside vendor pricing.

Recommended outputs:

- Chargebacks per 1,000 completed orders.
- Gross disputed dollars per order.
- Fees per order.
- Net loss after recoveries per order.
- Lag distribution from order date to finance posting date.
- Reason-code mix.

### Loyalty and repeat ordering

Treat repeat purchase as a lagging behavioral guardrail, not proof of causality. A longitudinal hospitality study found that short-term satisfaction patterns and medium-to-long-run patronage patterns can differ substantially after service failures and recovery ([Norvell, Kumar, and Dass, 2018](https://doi.org/10.1177/1938965518762835)). This supports publishing both attitudinal CSAT and behavioral repeat ordering instead of substituting one for the other.

For the 12-week case window, use 14-day and 28-day repeat rates only for index orders with complete follow-up. Also publish Kaplan-Meier-style time-to-next-order curves or customer-week retention by treatment/control and issue outcome. Adjust or stratify for pre-period order frequency, city, promotion exposure, order problem type, and customer tenure when those variables are available or simulated.

## Metric hierarchy for leadership

### Primary decision metric

**Support-adjusted contribution per completed order**, compared using treatment versus control and pre versus post.

### Hard guardrails

- Verified FCR must not materially decline.
- Seven-day repeat-contact rate must not materially increase.
- Chargebacks per 1,000 mature orders and net chargeback loss per order must not materially increase.
- 28-day repeat-order rate or time-to-next-order must not materially worsen.
- Observed CSAT must be paired with stable response coverage and respondent-mix checks.

### Diagnostic counter-metrics

- AI technical containment versus verified containment.
- Abandonment and unknown-outcome rate.
- Human escalation rate and time before escalation.
- Channel mix.
- Contacts per issue episode.
- Linkage coverage and follow-up maturity.

## Data-trust controls

Every metric row should carry:

- `metric_name` and a versioned definition.
- `grain`.
- `numerator`, `denominator`, and units.
- `event_date_type`: contact, order, or finance posting.
- `observation_window_days`.
- `eligibility_rule` and right-censoring flag.
- `linkage_confidence` or minimum coverage threshold.
- `is_synthetic`.
- `data_as_of` and model run timestamp.

Recommended data-quality tests:

- Unique and non-null primary keys at each source grain.
- Accepted values for channel, handling, ending reason, issue type, status, and ledger entry type.
- No contact before its linked order beyond an explicitly allowed tolerance.
- Finance entries map to known orders or appear in an exceptions mart.
- No survey score outside its valid range.
- Reconciliation of mart contact counts to staged contact counts by week and channel.
- Reconciliation of ledger totals by entry type before and after enrichment.
- Treatment-city assignment is invariant and launch begins in week 7.
- Post-period promotion exposure begins in week 8 and is modeled separately.

## Practical interpretation rule

A successful result requires all three statements to be true:

1. The treatment improves support-adjusted contribution per order relative to the counterfactual.
2. The improvement is not created by reclassifying abandonment, suppressing access, shifting costs into delayed finance events, or excluding unlinked records.
3. Customer guardrails remain within predeclared tolerances over a fully observed follow-up window.

If only contact volume and direct handling cost improve, describe the launch as **operationally cheaper but not yet proven successful**.
