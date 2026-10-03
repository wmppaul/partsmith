# Independent heading glyph continuation review — 2026-10-03

The frozen candidate passes this bounded code and source review. It recovers the two previously documented clipped initial A glyphs, preserves every original source rectangle, and changes no other accepted region in the 63-region replay. This recommendation concerns the single-pass helper at its current native call site; it does not establish heading recall or replace the separate full native workflow checks.

Reviewed detector SHA256: `9e6ca0f8b208068d0de6219a6d8997cd2038c9b0b43fd888eb41732b6d6a2db9`. The candidate is frozen under `.build/heading-glyph-continuation-2026-10-03/candidate/Core`. No production code or source guard was edited by this review.

## Source-first visual result

I read the original accepted-heading obligations and immutable initial-A guards, inspected both original A source enlargements, and viewed all 63 original staff contexts before viewing the candidate crop images. I then independently invoked the candidate helper on each hash-bound source raster and viewed every resulting source box in `crops/sheet-*.png`. These are source-box inspections, not exported-part layout review.

| Frozen item | Original source | Left growth | Dark A pixels outside old box | Outside new box | Newly added dark pixels outside A guard |
|---|---|---:|---:|---:|---:|
| 18 | Brahms quartet IMSLP 242312, physical p14 | 0.610814 pt | 1 | 0 | 0 |
| 32 | Brahms quartet IMSLP 09200, physical p14 | 3.388966 pt | 57 | 0 | 0 |

The original fixed guards contain 57 and 199 dark pixels respectively. Both pass without moving their edges. The added pixels are visibly part of the printed A, not a nearby note or scan mark. The red/green overlays in `initial-A-18-original-with-edges.png` and `initial-A-32-original-with-edges.png` show old/new copy edges on unchanged original pixels.

All 61 other boxes are numerically identical. Across all 63, zero previously included pixel positions are lost. The accounting in `source-pixel-review.json` uses pixel-center containment and the original <128 dark threshold at 216 dpi. Comparing integer pixel left edges would count partially retained edge pixels as lost; that is not the frozen guard convention. No blanket whitespace or staff margin was added.

Metronome notes, dots, equals signs, numerals and punctuation already inside the original boxes remain inside. In particular, Schumann p39 still copies the printed **126**, even though the retained OCR label says 128. Source pixels, rather than OCR text, determine that conclusion. Existing collateral slurs, note/stem/clef fragments, and the KV387 Trio bar number/local forte remain. The two old Schumann p26 fragments appear separately in this frozen pre-grouping 63-region replay; their later coalescing is a separate, previously tested production change.

## Independent controls and code review

`controls.swift` exercises left and right subset cuts at four depths and three ink levels, simultaneous two-sided recovery, unchanged vertical edges, complete original metronome/punctuation bounds, blank and detached ink, shallow beams, components leaving the vertical or horizontal search, malformed bounds, page edges, and malformed/NaN/infinite/unordered staff anchors. Every cancellation callback is tested on ordinary components and a >4096-pixel flood fill after an earlier expansion proposal. A cancelled helper returns the original box atomically. The native caller also checks cancellation before emitting the final measured result.

Final control count and every individual result are in `results.json` and `run.log`. The harness exits nonzero on any failed control. Validation prevents unsafe index/conversion use in the new helper. Expansion only changes the two horizontal edges outward; already accepted metronome or punctuation pixels cannot be removed by this helper. The search is bounded and does not change OCR recognition, instrument ownership, or planner selection.

## Reproduced limits, not hidden passes

The five observations in `results.json` are deliberately separate from the passing invariant checks and are pictured in `adversarial-observations.png`:

* **Shape is not semantic identity.** A fully contained notehead with stem, a compact curved slur, and a complete sharp crossing the crop edge all cause expansion. The helper rejects fragments that leave the window and shallow beams, but it cannot claim to reject every musical impostor. Here the result only adds nearby source ink; no accepted corpus box acquires such extra ink. This is compatible with the user's preference to preserve notation, but matters for future cleanup or tighter guarantees.
* **Repeated application is not generally idempotent.** A disconnected component can straddle the newly expanded edge on a second call: the synthetic left edge changes from 160 to 150 and then 144 px. The current detector calls the helper once on fresh raw OCR bounds before coalescing and measurement, so this chain is not exercised by the reviewed integration. Do not repeatedly feed stored expanded boxes back through this helper without additional provenance or a fixed original anchor. The narrower isolated-glyph idempotence control passes; it is not a universal guarantee.
* **Faint outer fringe can still be missed.** A connected gray238 fringe extending beyond the one-pixel padding is ignored by the <224 connectivity threshold. It remains outside the candidate in the synthetic fixture. The two fixed real A guards pass, but that does not prove preservation of every low-contrast scan fringe, detached punctuation, wholly omitted glyph, vertical clipping, or letters extending beyond the bounded search.

These are scoped limitations rather than newly introduced missing-note failures. No blocker was found in the present single-pass use. The report does not claim that the synthetic impostor fixtures are actual failures in the 16-score corpus.

## Evidence and replay

`input-bindings.json` binds all original PDFs, any rectified review PDF, source inventories, cached page rasters and frozen Core files. Original guards were copied unchanged. `results.json` records the independent helper outputs for all 63 regions; `source-pixel-review.json` independently checks source containment and guard recovery. All source contexts used for the initial review remain in [accepted-heading-source-review](../accepted-heading-source-review/README.md). The owner's broader experiment is [heading-glyph-continuation](../heading-glyph-continuation/README.md).

From the repository root, run `bash Tests/quality_control/heading-glyph-independent/run.sh`, then `.build/extraction-venv/bin/python Tests/quality_control/heading-glyph-independent/review.py`. These commands require the hash-bound frozen candidate and original cached corpus inputs named in the bindings. The source-only frozen Core archive included here preserves the candidate for audit; it contains no binaries or user documents. `manifest.json` binds the final evidence files.
