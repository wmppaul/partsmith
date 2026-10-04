# Monotone mask: independent full-corpus comparison

The numerical comparison is complete and finds **no new complete neighboring staff in any planned crop**. Nineteen existing foreign-staff relations are removed. Staff identities, assignments, order and unresolved coverage remain unchanged. Visual preservation review is incomplete: 157 of 1,282 changed crops have an exact source-review receipt, and 1,125 remain pending. This report does not approve a production release or certify complete parts.

The root-owned runner freshly analyzed all 36 unchanged corpus PDFs, totaling 1,477 physical pages. The independent comparison uses the same initialized profiles and production analyzer's saved raw analyses, replanned with the candidate's unchanged current planner. Every original PDF/profile hash was rechecked, and every baseline inventory hash matches the previously verified archive. The earlier physical PDF page geometry is reused only because the original PDF bytes are exact. No duplicate baseline detection or native worker was started by this reviewer.

| Check | Result |
| --- | --- |
| Planned bands | 6,936 before and after; none added or removed |
| Detected staff identities, geometry and order | Exact on all 1,477 pages |
| Part/system assignments and order | Exact |
| Invalid source/staff/crop geometry | None found |
| Plan metadata and unresolved reasons | Unchanged |
| Crop changes | 1,282 rectangles on 264 pages |
| Warning-only band changes | 176 |
| Crops with inward edges | 1,038; source review remains necessary |
| Outward-only crop changes | 244 |
| Whole-foreign-staff relations | 87 → 68; 19 removed, **zero introduced** |
| Pages with component changes | 1,448 |

Each band's foreign-staff ID set is checked separately. “Whole foreign staff” means that the complete five-line vertical core of a different detected staff lies inside the crop; it is not a musical ownership judgment. The three new neighbor regressions from the [previous experiment](../envelope-compatibility-corpus-independent-2026-10-03/README.md) are absent. This does not imply that partial neighboring fragments are clean or that all target notes are retained.

Source review is reused conservatively. An earlier observation counts only when the original source bytes, physical page, staff ownership and **both** old/new crop rectangles match exactly. That permits 127 prior reviewed areas to be reused: 28 in K478 478563, 95 in Trio 114011, and four in Schumann 270922. Root newly reviewed 30 changed source rows on raw Brahms 242312 pages 1, 2 and 16. Their entire semantic assignments also match the fresh full-score results exactly. Together these cover 157 changed crops. Eleven formerly reviewed rows have different geometry and require new inspection; no similar-looking area is substituted for them. `source-review-reuse.json` lists every accepted receipt and the outstanding per-score counts. The pending queue contains all remaining 1,125 changed crops.

Unresolved inputs remain explicit. Nineteen profiles require system assignments and produce zero bands in this raw run. Only 490 pages have assignments; 987 retain unresolved reasons, and 15,712 detected staves are unassigned. These are not extraction passes. The component comparison identifies 958 pages with unassigned staves requiring further diagnostic review; no neutral diagnostic parts were generated here. Prior source classifications remain valid without altering plans: Trio 114011 pages 34–35 contain a blank scan and a text-only catalog, while K478 478563 page 38 contains a real editorial Piano ornament staff alongside three ordinary systems. That additional music cannot be silently omitted.

This study covers raw source analysis and initialized-profile planning. It does not run full shared-direction recognition, review exported PDFs or optimize page turns. The separate corrected 39-page Brahms study uses saved source rectifications and has its own source guards/review; its conclusions are not substituted for this raw corpus. Existing source losses in the bounded synthetic suites remain unresolved, as recorded in [the independent monotone controls](../numbered-monotone-independent-2026-10-03/README.md).

The frozen candidate Native analyzer is `95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0`, and its native corpus executable is `1fdf770ef72181cd15cff11ea07986ab40501d503bfa3de6dccf6b5359eedc7e`. The baseline analyzer is `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`. Both plans use `77212ba8218ba38b525e306ec40270268d44ccdcf3c0942585c790da94c2ace7`. Every frozen Core source hash is checked. Neither production nor source PDFs, profiles, existing projects, guards or delivered part sets were edited by this evaluation.

Evidence:

- `candidate-inventories.zip` preserves all 36 fresh inventories/plans, initialized profiles and the 25-file frozen candidate Core. `baseline-archive-reference.json` binds the predecessor archive containing all 36 unchanged normalized baselines; they are stored once.
- `comparison-data.zip` contains every crop change, all per-band foreign-staff sets, all page coverage/order/geometry checks and complete review queues. `component-deltas.json.gz` retains the full component differences for all 1,448 changed pages.
- `reviewed-three-page-contexts.zip` contains the 30 newly reviewed raw Brahms contexts, with the original root receipt under `source-review/`. Prior reviewed images remain in the hash-bound predecessor and sibling reports.
- `native-run/` stores the locked runner, inputs, final status, source/executable bindings and logs. `scripts/` preserves the read-only independent comparison, review-reuse and packaging steps.
- `archive-payloads.json` lists every compressed payload hash. Archives were reopened and every payload verified; `manifest.json` binds the final report files.

The algorithm is held at this result while preview editing work proceeds. Further source review—not numerical totals alone—is required before claiming broader extraction reliability.
