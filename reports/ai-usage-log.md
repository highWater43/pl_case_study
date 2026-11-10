# AI usage log

## How AI helped expand my ideas

I developed the analytical direction. AI helped turn those ideas into a measurable and repeatable analysis.

| My idea | How AI helped | How I tested it |
|---|---|---|
| Defined the 2-by-2 comparison | Turned it into SQL and a visual | Confirmed all eight cities, all 12 weeks, and the campaign timing were included in both groups |
| Proposed value left per order | Broke it into traceable financial components | Reconciled each component to order, support, and finance data and checked that costs were not counted twice |
| Proposed the faster human help simulation | Connected it to customer and financial outcomes | Changed only eligible records after week 7, kept the original data fixed, and reran the same 2-by-2 comparison |
| Chose the targeted simulation signals | Helped define the required data and calculations | Confirmed which signals exist in the source data and disclosed missing staffing and customer-exit data |
| Set the recommendation direction | Tested alternatives, risks, and competing explanations | Required value left to improve while resolution, abandonment, disputes, and repeat ordering stayed within acceptable limits |

AI also drafted the generator, PostgreSQL build scripts, fact and dimension models, validation tests, documentation, and presentation layouts. I reviewed and revised those outputs against the case requirements.

## AI errors and corrections

- The first raw-load script used a `psql` variable inside `\\copy`. That meta-command did not expand the path as expected. The build failed loudly and the loader was changed to local server-side `COPY`.
- The first fact scorecard included cancellation and late-delivery estimates without corresponding dimension labels. A validation gap was identified, definitions were added, and a test now requires every published metric to have a metric-dimension entry.
- Initial metric framing could have overemphasized direct cost and contact reduction. External research and the case requirements led to support-adjusted contribution, verified resolution, chargeback maturity, and observed loyalty guardrails.
- The first cost-per-resolution calculation divided a per-order cost by a per-contact resolution rate. Those units were not compatible, so the measure was removed from the decision story.
- The first simulation comparison did not preserve the original four-city by four-city, before-and-after design. It was rebuilt to change only eligible after-period records in the four changed cities and rerun the same comparison.
- The initial presentation draft overemphasized an exact synthetic savings estimate and used technical language without explaining the business logic. The final structure leads with the decision, explains one order from purchase to value left, and labels every simulation.
- CRM `resolved` was not accepted as ground truth. The derived definition requires an appropriate resolved end state and no same-order repeat contact within seven days.
- A modeled 90-day loyalty scenario can look like observed evidence. It was isolated, labeled assumption-only at every mart output, and kept separate from the mature observed 28-day reorder proxy.

## How outputs were verified

- The generator uses fixed seed `20261106` and writes source row counts and SHA-256 file hashes to `data/raw/manifest.json`.
- The project was rebuilt from an empty database after each material SQL change.
- Thirty-seven persisted warehouse assertions verify volume, uniqueness, experiment balance, attribution, referential integrity, unit normalization, promotion timing, mart completeness, narrative direction, and simulation labeling.
- Final checks show 55,941 unique orders, 5,999 deduplicated contacts, 99.10% contact attribution, zero orphan finance entries, and zero error-severity data-quality failures.
- Executive metrics were queried directly from the fact models and exported to CSV.
- Every displayed number was traced to a governed fact model or an explicitly labeled simulation.
- Industry claims were recorded with primary or authoritative links and labeled when company-reported.
- Causal conclusions are described as directional and quasi-experimental, not randomized-trial proof.

## Verification boundaries

- Guardrail thresholds are proposed decision rules rather than values supplied by the case brief.
- Simulation checks establish reproducibility, not proof that projected outcomes will occur.
- Public research links should be checked before external use because source pages can move.
