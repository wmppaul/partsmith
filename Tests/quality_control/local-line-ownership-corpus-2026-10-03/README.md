# Local staff ownership V2: complete raw-corpus comparison

This private candidate was run once across all **36 original PDFs / 1,477 physical pages**. All 6,936 planned bands retain their assignment identities and order. There are **65 changed crop rectangles on 42 pages**, with no new whole-foreign-staff relationship. Every changed source area was visually reviewed. No new intended-notation omission was observed at those changed edges, but the result is **not a preservation or cleanup pass**: one existing text omission is only partly recovered, many expansions add neighboring fragments, and ownership changes on unresolved pages remain unevaluated. Production and published outputs are unchanged.

The candidate is the unchanged measured-local-line V2 from [the focused study](../p34-local-ownership-v2-2026-10-03/README.md), Native SHA256 `46ad9d2041991d4c9e2743519ef708d699c30b6846493abf70f7b94818d5d540`. Its planner is the frozen `77212b…` version. The already compiled inventory executable, SHA256 `79042a72be93269b3dc9a973ea8fe4e0e2cb9eadc5b711ad6e481f6d26d9a70c`, was reused byte for byte. No existing permanent, 297-case, or 336-case controls were rerun here.

## Comparison and the focused baseline check

The baseline is production Native `9f8d7e…` raw analysis, previously replanned without analysis changes with the same `77212b…` planner. It is **not** the private `95a958…` cleanup experiment. Every original source, profile, baseline, executable, and snapshot hash was checked. The initialized profiles do not establish automatic instrument-name discovery.

The original historical comparison is preserved in `comparison/comparison.json`. It exposed 58 unexpected non-component fields on all ten pages of *Hear My Prayer*, IMSLP 40163: 33 confidence values, 24 line fractions, and one bottom fraction. The largest line displacement was approximately 0.397 native pixel; the bottom displacement was one pixel. Its source bytes were unchanged.

A separately authorized, matching fresh production run of **that PDF only** reproduces the candidate's staff geometry, non-component fields, component geometry/owner multisets, and plan exactly. Thus those ten-page differences are historical-baseline drift rather than evidence of a V2 change. The precise underlying rendering/history cause is not established, and decoded raster equality is not claimed. `fresh-production-40163/comparison.json` records the check without rewriting the historical full-corpus result.

After this explicit attribution, V2 changes **1,679 component owner sets on 294 pages**. Every change removes the old owner set to leave an unowned component; source component bounds remain unchanged. Of these, **729 changes are on 139 zero-plan pages** and remain unfinished scope. These exact counts exclude all 331 historical 40163 groups, including nine paired owner changes—not just its 322 unmatched geometry groups. `comparison/attribution-summary.json` records this correction to the earlier informal 1,688 / 738 totals.

All physical PDF dimensions, assignment identities, assignment/staff ordering, and unresolved outcomes remain matched. Both versions have 490 pages with assignments, 987 unresolved pages, 23,801 detected staves, 15,712 unassigned staves, and 19 zero-band profiles. Zero-band inputs are not successful extractions.

## Source review of all 65 changed crop areas

Original PDF page renders were inspected first, followed by every full-width context showing production red and candidate blue edges. The recorded geometry contains 63 outward-only changes, one downward shift with an inward upper edge, and one upper-edge contraction. Both contractions remove only upper neighboring staff-line fragments, above the intended notation. Per-band whole-foreign-staff ID sets are unchanged; the aggregate 87 relationships is not used to hide per-band regressions.

- **One complete recovery:** raw Brahms 93521, page 34, system 4, Viola retains the full previously clipped forte. The independent 372-pixel source obligation is unchanged. The expansion also includes neighboring Cello fragments.
- **One partial recovery, still failing:** raw Brahms 93521, page 8, system 2, Viola recovers the bottoms of “in tempo,” but the `p` descender remains clipped. Its independently measured foot requires a crop bottom of at least **283.402858 pt**; V2 stops at **282.428130 pt**. A one-original-pixel white clearance is **283.640015 pt**. The Cello top line passes through this own instruction, so preserving the foot with a horizontal rectangle necessarily retains that line fragment.
- **62 other rows:** no additional own-notation recovery demonstrated; they add neighboring staff/music fragments or edge clearance. One of these also trims upper-neighbor fragments as the row shifts down.
- **One remaining row:** the 0.6041 pt K478 page 22 Viola upper contraction removes only a neighboring Violin line fragment.

The page-8 omission is also directly visible in the complete production shared-workflow **Viola output page 3**, whose source rectangle matches the old raw crop. Page 8 has no saved rectification. `source-review/p8-in-tempo/production-output-binding.json` binds the PDF and placement. The new independent lower-foot oracle records 53 original nonwhite pixels: V2 fully retains eight, partially retains eight, and excludes 37. This is an additional source obligation, not a replacement or relaxation of existing guards.

**Source-review erratum:** the frozen [real-12 study](../p34-local-ownership-real-cases-2026-10-03/README.md) described page 8, system 2, Viola as adding only neighboring fragments. The closer original-source inspection here corrects that statement: it provides partial own-text recovery while still clipping the `p` foot. The previous report and all previous guards remain unchanged. The exact landmark and original/output details are preserved here for a separate manual draft repair; that repair is not part of this candidate or evidence run.

`source-review/per-band-review.json` contains all 65 distinct source-bound outcomes. No new shared-instruction removal was observed in these changed areas. This does not establish shared-direction recall: the raw inventory worker does not run optional heading, navigation, or ending recognition. Existing defects elsewhere are not waived. No full output was regenerated or certified in this study.

## Execution and evidence

The original full run used two native workers and completed in **211.64 seconds** after input validation, without retries or duplicate score invocations. The focused ten-page production attribution run took 1.53 seconds, excluding its compile. These are observations under concurrent work, not performance guarantees or a controlled speed comparison. Persistent run status and per-score PID/result receipts are preserved for audit; all processes completed.

`native-candidate-evidence.zip` contains all 36 candidate inventories, logs and progress receipts, the focused production inventory, the complete frozen candidate Core, matching production dependencies, and the unchanged inventory harness. The 36 exact production baseline inventories are already stored once in the earlier corpus archive; `baseline-reference.json` records their verified compressed payload hashes. `reviewed-source-images.zip` stores every reviewed changed-band context plus the original page-8 source and actual-output proof. Redundant contact sheets/full-page renders are reproducible from the unchanged original PDFs and hash-bound generator. `archive-payloads.json` binds every newly archived file.

This study leaves the automatic crop algorithm private. The 139 zero-plan pages with ownership changes still require meaningful assignment-aware evaluation; existing failed preservation controls and unresolved profiles remain explicit unfinished work.
