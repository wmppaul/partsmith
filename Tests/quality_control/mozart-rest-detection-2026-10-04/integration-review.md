# Independent rest integration review

Reviewed the current model, layout, document worker, and PDF renderer against the detector changes. The latest reviewed inputs are identified in `context-source-hashes.json`.

- Source context accepts one or two groups, each containing five finite, ordered lines within the original crop. Groups cannot overlap, and the first group matches the retained legacy staff geometry.
- The shared PDF/preview renderer draws one rest symbol on each retained staff and one count above the top staff. Source clefs, keys, meters, braces, and endings remain source fragments.
- A following source-context replacement is a join barrier: its new printed prefix cannot be discarded. An existing context may extend through later bare rests only when the detector verified a plain closing bar and no trailing instruction.
- Mixed joins retain the initial context, original opening markings, and every constituent source-band identity. Labels, later directions, explicit breaks, contradictory known bar numbers, excluded rows, and known system gaps stop joining.
- Review identified a cross-page gap: a source row could precede a known later system on its page and still join to the next page. The root fix now consults the project-wide last-system inventory and refuses that known gap.
- The historical real Mozart package initially failed the document worker despite correct detector matches. Its unchanged Allegro/TUTTI source copy ends at x=0.2642223, beyond the meter-only prefix x=0.2408 but before the first rest x=0.2977778. The document now retains valid source copies ending before that first rest, fixing the overly narrow guard without trimming or deleting the marking.

The older source-context regression passed **120 checks**, covering ten positive score crops. Every sampled original prefix/suffix pixel matched its source reference exactly (zero changed pixels in every fixture). This run includes the latest document guard and cross-page inventory fix and was built from a frozen Core snapshot. The only test adjustment was explicit `usesSharedLayout = true` in its synthetic part setup, avoiding a legacy nil-to-shared-layout migration difference during JSON round-trip comparison. No production code was edited during this review.
