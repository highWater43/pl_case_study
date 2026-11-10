# Industry patterns for contact simplification

Research date: 2026-11-06

## Executive takeaway

The closest successful patterns do not remove human support and declare lower contact volume a win. They make routine resolution easier, preserve an obvious human escape path, pass full context when escalation occurs, launch in small controlled ramps, and judge success on resolution quality and downstream behavior as well as cost.

For ForkDash, the most defensible move is therefore not to copy the current four-city design. Copy the operating model behind DoorDash, Airbnb, Uber, Grab, and Bank of America: issue-level automation eligibility, rapid escalation for sensitive or failed cases, end-to-end event instrumentation, phased rollout, and a balanced scorecard.

All numeric outcomes below are company-reported unless otherwise stated. They are useful design evidence, not independent proof of causality.

## Closest analogues

### 1. DoorDash: unified automation with escalation available at any point

DoorDash built a shared in-app chat layer that combines live and automated support. It retained control of customer-journey and resolution logic, passed customer context to agents, and allowed users to escalate at any point. The rollout started on lower-volume web traffic, expanded by feature flag, and could be ramped down quickly. DoorDash monitored agent and customer feedback, errors, CSAT, average handle time, first-contact resolution, and manual tasks per order. It reported reduced escalation, improved CSAT, faster resolution, and fewer manual touchpoints, but did not publish effect sizes. [DoorDash, "Building a Unified Chat Experience"](https://careersatdoordash.com/blog/building-a-unified-chat-experience-at-doordash/)

**Copy for ForkDash:**

- Keep a visible human escape path instead of adding steps to hide it.
- Pass order, issue, prior-contact, and attempted-resolution context into the agent handoff.
- Use feature flags by city, issue type, channel, and journey stage.
- Make FCR and manual tasks per order first-class measures, not only raw contact count.

### 2. DoorDash: codify policy before automating it

DoorDash also built decision graphs to standardize issue handling before expanding automation. The approach made policy consistent, reduced agent navigation, and improved issue-resolution time by up to two minutes, with a reported improvement in customer satisfaction. The platform was designed around frequent issues while leaving agents available for exceptions. [DoorDash, "Using a Decision Engine to Power a First Class Customer Experience"](https://careersatdoordash.com/blog/customer-obsession-decision-platform/)

**Copy for ForkDash:** Build an explicit issue-policy matrix for late orders, missing items, wrong items, safety, fraud, and high-value orders. Specify required evidence, allowed remedies, escalation rules, and maximum automated refund before changing channel access.

### 3. DoorDash: simulate long-tail failures, then validate on small live traffic

DoorDash's 2026 chatbot evaluation platform simulates multi-turn conversations, backend tool responses, and policy edge cases before production. In one validation, 302 simulated order-status conversations produced a 46% escalation rate versus 44% in 175 conversations at 1% live traffic. DoorDash reports that the approach reduced simulation hallucinations by 90% and turned a weeks-to-months manual review loop into minutes. [DoorDash, "Inside DoorDash's one-click simulation and evaluation platform"](https://careersatdoordash.com/blog/doordashs-one-click-simulation-and-evaluation-platform-for-support-chatbots/)

**Copy for ForkDash:** Use synthetic conversations for rare, risky scenarios, but calibrate them against a small production sample. Treat simulation as a pre-launch gate, not evidence of business impact.

### 4. Airbnb: self-service plus explicit human-intent detection

Airbnb redesigned voice support so callers can describe issues naturally. Its system routes high-confidence informational requests to relevant help content and sends other cases to an agent with context. Crucially, a separate model detects requests such as "agent" or "escalation" and honors them. Airbnb reports over 90% precision in manual evaluation of the article-matching flow, and an experiment found that a short paraphrased issue summary increased article engagement and self-resolution, although no effect size was disclosed. [Airbnb, "Listening, Learning, and Helping at Scale"](https://airbnb.tech/ai-ml/listening-learning-and-helping-at-scale-how-machine-learning-transforms-airbnbs-voice-support-experience/)

**Copy for ForkDash:** Measure whether the answer is relevant and whether the issue was actually resolved. Do not interpret a user abandoning a difficult path as successful self-service. Honor explicit human requests immediately.

### 5. Grab: automate only bounded issues and route sensitive cases to people

Grab's missing-item automation uses LLM classification, menu context, and a constrained refund policy. Safety and quality signals such as mold, undercooked food, or foreign objects are immediately routed to a human. Grab reports roughly 32,000 fewer manual tickets per month after rollout across most markets. [Grab, "How Grab Support automated partially missing items refunds"](https://www.grab.com/inside-grab/stories/how-we-taught-llms-to-solve-the-missing-muffins-mystery/)

**Copy for ForkDash:** Automate narrow, reversible resolutions first. Create hard human-routing rules for food safety, harassment, suspected fraud, repeated failure, vulnerable customers, and ambiguous/high-value remedies.

### 6. Uber: one policy engine across channels

Uber's Policy Engine separates policy authoring from channel presentation. The same resolution logic can power in-app self-service, asynchronous messages, chatbots, IVR, and agent-assist workflows. This reduces inconsistent policy application while allowing channel-specific experiences. [Uber, "Customer Support Automation Platform"](https://www.uber.com/in/en/blog/customer-automation-platform/)

**Copy for ForkDash:** Simplify the policy and data model, not just the UI. A single resolution identifier and policy version should follow a case across AI, phone, email, and agent handling.

### 7. Bank of America: publish answer quality and preserve live handoff

Bank of America reported that more than 98% of clients using Erica obtained the answers they needed, while also adding live-chat connections for more complex requests. In its business platform, CashPro Chat volume rose 41% while live-agent chats fell 16% after Erica technology was added. These figures are not a controlled causal estimate, but they demonstrate a stronger success definition than contact suppression: answered need plus a live-service fallback. [Bank of America, Erica milestone](https://newsroom.bankofamerica.com/content/newsroom/press-releases/2022/10/bank-of-america-s-erica-tops-1-billion-client-interactions--now-) and [CashPro Chat results](https://newsroom.bankofamerica.com/content/newsroom/press-releases/2023/09/enhancements-to-bofa-s-cashpro--chat-create-greater-efficiencies.html)

**Copy for ForkDash:** Track verified resolution and appropriate channel shift separately. A lower human-contact rate is beneficial only when downstream repeat contact, complaint, refund, and chargeback rates do not worsen.

### 8. Klarna: useful scale benchmark, but treat the headline cautiously

Klarna reported that its AI assistant handled two-thirds of customer-service chats in its first month, repeated inquiries fell 25%, resolution time fell from 11 minutes to under 2 minutes, CSAT was comparable to human agents, and projected annual profit improvement was USD 40 million. These are Klarna's own launch claims, not an independent evaluation. Its current help center still offers both 24/7 AI chat and a customer-service phone number, which is a useful signal that AI-first does not require phone removal. [Klarna launch announcement](https://www.klarna.com/international/press/klarna-ai-assistant-handles-two-thirds-of-customer-service-chats-in-its-first-month/) and [Klarna customer service](https://www.klarna.com/nz/help/)

**Copy for ForkDash:** Use speed, repeat inquiry, and cost as complementary measures, but do not use containment alone. Retain a reachable phone path, especially for failed automation and high-severity cases.

## What the case-study fact and dimension mart layer should measure

The external patterns support the following minimum scorecard:

| Outcome family | Primary measures | Why it matters |
|---|---|---|
| Demand and access | contacts per 1,000 orders, contact attempts, channel mix, human-request rate, path abandonment | Separates genuine issue reduction from suppressed access |
| Resolution | verified resolution, first-contact resolution, repeat contact at 24h/7d/14d, reopen/escalation rate | Tests whether deflection actually solved the problem |
| Experience | CSAT with response rate, customer effort, time to resolution, complaint rate | Captures friction and survey selection bias |
| Financial | handling cost, refund/credit cost, chargeback amount and fee, contribution margin at risk, cost per resolved issue | Prevents support savings from hiding shifted costs |
| Loyalty | 7d/28d reorder rate, order frequency, churn proxy, promo-adjusted retention | Captures lagging customer harm |
| Safety and fairness | inappropriate automation, denied-human-request rate, outcomes by city/issue/value/customer segment | Protects high-risk cases and identifies uneven impact |
| Reliability | policy version, tool/error rate, fallback rate, data freshness, join coverage | Makes results reproducible and diagnosable |

## Recommended operating pattern for ForkDash

1. Restore an obvious human option for users who request it or fail automation twice.
2. Limit automation initially to bounded, reversible issue types with high-confidence data.
3. Randomize or stagger within cities by eligible order/customer, rather than relying only on the original four-city comparison.
4. Pre-register a primary outcome of **fully loaded cost per resolved issue**, with guardrails for repeat contact, CSAT, chargebacks, and 28-day reorder rate.
5. Maintain immutable event logs for exposure, steps attempted, policy version, handoff, resolution, money movement, and later customer behavior.
6. Run offline scenario simulation, a 1% live validation, then gradual ramps with automatic rollback thresholds.
7. Review transcripts and failures by issue type weekly, and feed recurring product defects upstream instead of repeatedly automating around them.

## Evidence limitations

- Most public examples are company-authored success stories and omit confidence intervals, denominators, and negative outcomes.
- Lower live-agent volume is not itself evidence of better customer outcomes.
- Reported CSAT may be non-comparable because response propensity changes across channels.
- ForkDash should use these examples to justify design and measurement choices, not to assume the same effect sizes.
