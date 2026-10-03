# Required representation before a safe crop proposal

The executable prototype serializes original pixel runs for a candidate spine, provisional staff-line channels and connected residual branches. Their union reconstructs the source context exactly. Contacts retain the source coordinates where a branch joins a spine. These are analysis data, not a musical ownership classifier.

A production design would need the following additional evidence, which the current `ScoreInkComponent(bounds, staffIDs, isOwnershipAlternative)` does not retain:

1. **Source binding:** PDF hash, page, rectification transform/hash, native dimensions, ordered staff IDs/line curves and component identity. Reject evidence when any binding changes.
2. **Physical stroke segments:** source-pixel runs and an ordered list of contact intervals. A role belongs to an interval, not necessarily to the entire vertical stroke: structural transport, shared music, or unresolved. The same physical source stroke can carry a chord through two staves and continue as structure through two others.
3. **Staff-line identity:** each horizontal curve retains its numbered staff line, observed pixels, missing spans and uncertainty. Pixels provisionally explained as a staff line may also belong to a notehead or ledger line; they must not be silently discarded. The source graph currently leaves this overlap unresolved.
4. **Musical branches and coupling:** exact retained source runs, attachment intervals and evidenced instrument ownership. A filled/hollow head, tie or shared stem cannot lose a distant owner merely because another segment of its spine is structural. Unknown contacts retain the baseline shared hypothesis.
5. **Separation certificate:** before replacing a broad baseline component, account for all original pixels and every musical-owner obligation. Every removed attribution edge needs a structural proof; every musical branch retains its evidenced owners and bounds. Unresolved contact, incomplete path, invalid geometry, stale binding or cancellation returns the original component intact. Deterministic IDs derive from the bound source runs and staff identities.

The planner would then derive each owner's bounds from that owner's retained branch/segment payloads. Existing outward-only alternatives can preserve uncertain music, but cannot safely shrink an already ordinary, shared component by themselves. Replacing an ordinary broad box requires this complete separation certificate; simply adding local components while suppressing the old box would reproduce the rejected loss mechanism.

This study deliberately does not fabricate the missing musical-role proof. Even a stronger measure-boundary network remains insufficient: the included adversarial sources have two independent aligned structural bars while the third corridor still carries a cross-staff chord. Original owner masks prove that its shared musical span must remain.
