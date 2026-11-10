# Research synthesis: what ForkDash should copy

## Bottom line

The successful pattern is not to remove human support and treat lower contact volume as proof of success. Strong operators automate bounded issues, retain an obvious escape path, preserve context during handoff, ramp gradually, and judge success using verified resolution plus downstream customer and financial outcomes.

The full evidence and links are in:

- [Industry case studies](industry-case-studies.md)
- [Metric framework research](metric-framework-research.md)
- [Causal design research](causal-design-research.md)

## Practices worth copying

### DoorDash

DoorDash combines automated and live support, allows escalation at any point, passes context to agents, rolls out by feature flag, and monitors first-contact resolution, CSAT, errors, handle time, and manual tasks per order. It also codifies issue policy before automating and uses simulation before a small live ramp.

ForkDash should copy the rollout mechanics and context-preserving handoff, not just the AI front door.

### Airbnb

Airbnb explicitly detects requests for a human and honors them. Automated content is used when confidence is high, while other cases go to an agent with context.

ForkDash should distinguish a successful answer from a user exiting a difficult journey.

### Grab

Grab automates bounded missing-item refunds while routing safety, food-quality, and ambiguous cases to people.

ForkDash should create an issue-level eligibility matrix with hard human-routing rules.

### Uber

Uber separates policy logic from the channel that presents it. One policy engine can serve self-service, bots, IVR, messages, and agents.

ForkDash should simplify policy and resolution identifiers across channels, not only simplify the contact UI.

### Bank of America and Klarna

Both illustrate high-scale AI assistance while preserving live-chat or phone options. Their public metrics are company-reported and should not be treated as independent causal evidence.

ForkDash should define success as answered need plus an appropriate fallback, not containment alone.

## Metric contract to copy

Use three levels:

1. Primary business outcome: support-adjusted contribution per order.
2. Customer guardrails: verified resolution, repeat contact, chargebacks, CSAT plus response rate, and mature repeat ordering.
3. Diagnostics: contact rate, channel share, technical containment, escalation, abandonment, and linkage coverage.

Technical AI containment means no human transfer. Verified containment means positive resolution evidence, no human transfer, no repeat contact within the declared window, and no later adverse outcome within the available maturity period.

## Analytical design to copy

- Use treatment versus concurrent control and pre versus post, not a single before/after trend.
- Publish an event study and pre-period balance rather than relying on one aggregate estimate.
- Keep the national `FREEDEL` promotion visible as a calendar shock.
- Tie finance outcomes to order cohorts while retaining posting dates for reconciliation.
- Exclude right-censored orders from finalized loyalty rates.
- Emphasize effect size and cross-city consistency because only eight city clusters exist.
- Use a larger prospective randomized or stepped rollout for the next decision.

## Where public evidence is weak

Most company examples are authored by the company or its vendors. They often omit denominators, uncertainty, selection rules, or negative outcomes. They support operating-design choices, but they do not justify copying reported effect sizes into ForkDash assumptions.
