# Independent corrected-page matching and navigation review

The corrected-page provider used the render cache’s default 300 dpi, while document Auto records corrected-page staff geometry at 180 dpi (`rasterScale: 2.5`). The matcher correctly rejects different pixel dimensions, so this integration mismatch prevented matching on corrected pages. The production provider now uses the same 2.5 scale as Auto and retains its refusal to substitute an uncorrected raster.

All nine saved Brahms IMSLP 93521 corrections pass the dimension comparison after this change. The original source, all correction corners, profile, and stored native staff analyses are unchanged. The test calls the actual frozen render cache and template matcher; it does not resize an image to satisfy the guard.

| Physical source page | Stored and fixed image | Original provider image | Original suggestions | Fixed suggestions |
|---|---|---|---:|---|
| 2 | 1068 × 1535 | 1780 × 2559 | 0 | 2, requiring review |
| 7 | 1068 × 1535 | 1780 × 2559 | 0 | 3, source supported |
| 17, 39 | 1065 × 1535 | 1776 × 2559 | 0 | 0 |
| 19, 23, 28, 38 | 1068 × 1538 | 1780 × 2563 | 0 | 0 |
| 34 | 1068 × 1535 | 1780 × 2559 | 0 | 0 |

For each tested page, the first four physical staves are the explicitly initialized quartet template. The remaining source groups were checked against the original pages: page 2 contains three quartet systems, and page 7 contains four. After the fix, page 2 proposes IDs 4–7 and 8–11; page 7 proposes IDs 4–7, 8–11, and 12–15. These are the expected complete groups in source order. Page 7’s original and native corrected images were viewed directly. Page 2’s original image was viewed directly. Suggested bounds are navigation targets, not extraction crops.

Seven corrected pages still abstain because the matcher cannot establish their printed connections. The scale correction does not establish broad scanned-score recall or automatic instrument identity. This test reuses saved native analyses; the matcher performs its own staff-inventory recheck. It does not rerun the complete document Auto workflow, export parts, or interact with the full application UI.

The first sandboxed harness attempt returned no image from the native correction renderer and trapped at the harness’s forced optional. The same frozen rendering code succeeds outside that sandbox. The successful native results and exact executable hash are retained; no software renderer, raw-image fallback, correction change, or geometry adjustment was substituted.

## Navigation and panel review

The current view saves a pending suggestion before changing pages, clears the previous page’s focus while updating its image, and then applies the pending suggestion. Same-page navigation applies the new selection directly. Both paths set a fresh focus identifier, highlight the selected staff IDs, switch to fit width, and clear the previous bar inputs. The recreated scroll reader uses an initial callback.

An independent scroll harness found that a positioned one-point marker exposed a page-sized target. The final view uses a one-point marker in vertical layout, matching the separately tested correction. The [scroll review](../system-template-scroll-independent-2026-10-03/README.md) records actual viewport measurements for same-page and different-page targets; those tests belong to that review, not this renderer harness.

The panel disables its result controls while assignments are applying, leaves Stop available, and checks the captured review again before committing. Source, correction, assignment, and profile changes invalidate the pending match. The earlier [batch review](../system-template-batch-independent-2026-10-03/README.md) retains the independent cancellation, stale-input, ordering, and atomicity controls. No further actionable defect was found in this final integration review.

## Evidence

`summary.json` binds the source, profile, inventory, native executable, tested matcher, and final UI files. `render-results.json` retains every tested page, dimension, suggestion, confidence, and diagnostic. Original source pages 2 and 7 and the native corrected page 7 are included for visual review.

`evidence.zip` preserves the frozen Core, before/after UI sources, harness versions, build/run logs, complete source inventory, profile, all nine exact corrections, and selected analysis records. `archive-manifest.json` hashes every member. The original PDF is referenced by its source hash and repository path, rather than duplicated in the archive. No production source, source PDF, score project, or published part output was changed by this reviewer.
