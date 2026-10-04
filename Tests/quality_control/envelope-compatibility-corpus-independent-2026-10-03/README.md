# Envelope compatibility: independent full-corpus comparison

**Rejected for promotion.** The private numbered-line envelope candidate adds complete neighboring staves to three Brahms 242312 crops. Root reviewed all three original source contexts and found no intended notation recovery that warrants the expansion. An overall reduction in neighboring staves does not cancel these individual regressions. Production and delivered parts were not changed by this study.

The comparison covers every input in the unchanged 36-score corpus: 1,477 physical pages and 6,936 planned bands. The candidate was freshly analyzed by one root-owned runner. The baseline reuses the production analyzer's saved raw pages and replans them with the same current planner. Independent checks confirm that every baseline raw page and historical plan was retained exactly. No second baseline detection was performed.

| Check | Result |
| --- | --- |
| Source PDFs and initialized profiles | All 36 byte hashes verified; every original PDF page geometry recorded |
| Staff geometry, identities and order | Exact on all 1,477 pages |
| Part/system ownership, band identities and order | Exact; no added or removed bands |
| Invalid staff or crop geometry | None found |
| Plan metadata and unresolved reasons | Unchanged |
| Changed crop rectangles | 1,517 bands on 353 pages |
| Warning-only band changes | 164 |
| Crops with an inward edge | 1,248; these require source review |
| Crops with outward changes only | 269 |
| Complete foreign-staff relations | 87 before, 71 after: 19 removed **and 3 newly introduced** |
| Component changes | 1,451 pages; complete deltas retained |

“Complete foreign staff” means that all five detected staff-line coordinates for an unassigned neighboring staff fall within that band's vertical crop. This is a geometric diagnostic, not a note-ownership oracle. Every before/after foreign-staff ID set was compared separately for all 6,936 bands. Root's source inspection independently confirmed the three new cases:

| Source | Band | Newly included neighbor |
| --- | --- | --- |
| Brahms Quartet, IMSLP 242312, page 1 | System 1, Cello | Viola |
| Same source, page 2 | System 2, Cello | Viola |
| Same source, page 16 | System 5, Viola | Violin II |

Source review stopped after those decisive failures. The reviewer inspected 3 of that score's 269 changed crops. Separate completed source reviews cover all 10 changed Schumann 270922 crops and all 147 changed Mozart K478 478563 / Brahms Trio 114011 crops. Those bounded reviews found no newly omitted intended notation; partial neighboring ink remains. In total, 160 of 1,517 changed crops were visually reviewed, leaving 1,357 unreviewed. These are source-area reviews, not complete exported part or pagination checks. The [two-score independent report](../envelope-corpus-two-score-source-review-2026-10-03/README.md) stores its 147 contexts once; its hashes are bound here.

Coverage remains unfinished. Nineteen profiles explicitly require system assignments and produce zero bands in this raw run. Across the corpus, only 490 pages have planned assignments; 987 retain unresolved reasons and 15,712 detected staves remain unassigned. They are included in the comparison, not counted as successful extractions. A queue records 961 pages with both unassigned staves and changed components. Neutral diagnostic crop jobs were not executed after rejection.

Root additionally inspected three unresolved original pages, without changing their plans. Trio 114011 page 34 is a blank scan and page 35 is a publisher catalog with no music. Mozart K478 478563 page 38 contains three regular five-staff systems plus a small editorial Piano ornament staff linked to the first system by an asterisk. All 16 staves are correctly detected, but the fixed five-staff profile rejects the page. The ornament is intended source music; it must not be silently discarded. Schumann 270922 page 13 also retains its existing omitted song number 7 above the unchanged vocal top edge, a separate shared-heading limitation.

The candidate Native analyzer is `e32b5a76928b505efbeba6fa5bc9aef4b58ed0e2b7d11ddeef3269b73570996f`; the production baseline analyzer is `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`. Both plans use planner `77212ba8218ba38b525e306ec40270268d44ccdcf3c0942585c790da94c2ace7`. The source/PDF/profile hashes, executable bindings, frozen before-comparison protocol, and every physical page's PDF geometry are preserved. No source guard, ownership expectation, correction or fixture was changed to improve these results.

Evidence is arranged as follows:

- `independent-summary.json`, `new-whole-neighbor-regressions.json`, and `source-review-accounting.json` give the verdict and exact review limits.
- `comparison-data.zip` contains every changed crop, all per-band foreign-staff sets, every page's assignment coverage, order/geometry checks, and compact source-review queues. `component-deltas.json.gz` preserves complete component changes for all 1,451 affected pages.
- `native-inventories.zip` contains the full 36 baseline and 36 candidate inventories/plans, initialized profiles, and the frozen 25-file candidate Core. Original PDFs remain in the corpus and are hash-bound rather than duplicated.
- `reviewed-source-images.zip` holds the 13 root-reviewed crop contexts and three additional original-page images. Original review receipts and full context indexes are under `source-review/`; unreviewed index entries are not promoted to review passes.
- `native-run/` preserves the runner, source bindings, logs, baseline replan receipt, corpus roster and construction protocol. `scripts/` preserves the independent comparator and packaging steps. Their historical paths identify the original workspace run; no script starts a native worker merely to inspect this report.
- `archive-payloads.json` records every archived payload hash; `manifest.json` binds the final report files. Archives were reopened and their payload hashes verified after creation.

The narrow controlled-suite successes remain separately recorded in [the independent compatibility tests](../numbered-envelope-independent-2026-10-03/README.md). They did not establish robust behavior on the full corpus. This experiment supplies a failed real-source example for further diagnosis, not a production release or improved part set.
