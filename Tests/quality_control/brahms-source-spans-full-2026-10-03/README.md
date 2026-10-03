# Complete Brahms source-span experiment: rejected

The private V1 musical-span recognizer is rejected. A fresh native analysis of all **39 pages and 604 assigned bands** introduces eight false musical spans on five pages. Thirteen crops grow; ten of those now contain complete unrelated staff cores, adding **14 whole-neighbor incidences**. No production detector, exported part, or application bundle was changed by this experiment.

The candidate preserves every ordinary component and every existing ownership alternative. No old crop contracts. Those preservation properties do not make unnecessary neighboring staves acceptable, and the passing small synthetic subset does not override these real-source failures.

## Inputs and scope

- Original score: `sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf`, SHA256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`.
- All nine saved page rectifications are retained, without re-estimation. Corrected pages use the native display renderer at scale 2.5; uncorrected pages use the native analyzer renderer.
- Starting production analyzer: `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`.
- Frozen V1 analyzer: `00749e09b47ed1740feeab4d53aa77e7ce17658edb3d5a0f81fe60a51bf81fe1`.
- The exact initialized four-part profile, previous complete native inventory, renderer dependencies, page raster hashes, and candidate results are bound in the saved evidence. Staff detection is freshly rerun on all 39 source images; all observed staff geometry remains exactly equal.

The first preparation found only eight cached page images and stopped. All 39 were then rendered from the original PDF with the saved corrections; dimensions match the previous inventory on every page. All eight previously cached images are pixel-identical to their newly rendered counterparts. The comparison helper initially expected a nonexistent flattened `bands` field; it was corrected to read `plan.pages[].assignments` before candidate execution. Its self-check returns zero changes for the baseline and rejects deliberate component removal and crop contraction.

This is a detector/planner experiment, not a candidate PDF export or musical certification of all four parts. The private Release replay took 5.14 seconds, excluding source PDF rendering; it is not a live app responsiveness measurement.

## Source findings

All changed regions were reviewed in original source context, with fitted-body boxes inspected separately. An independent reviewer examined unannotated source contexts before the diagnostic overlays and reached the same rejection. None of the new spans connects true noteheads belonging to different parts.

| Source page | New span records | What the recognizer actually follows |
|---|---:|---|
| 23 | 2 | The same ordinary barline through Violin I, Violin II, and Viola; duplicate seed columns fit a slur crest and a staff/barline intersection. |
| 28 | 1 | An ordinary barline in the Coda crossing ties and slurs. |
| 29 | 1 | The right terminal double barline; staff/end-line junctions are falsely accepted as bodies. |
| 38 | 2 | One ordinary measure barline and one right system boundary, including staff intersections and a broken staff-end pocket. |
| 39 | 2 | Ordinary inter-staff barlines crossing slurs; the instrument notes are independent. |

Fourteen of the sixteen fitted endpoint bodies are classified as filled heads. The failure therefore cannot be fixed solely by rejecting hollow shapes. At this raster scale, a one-pixel boundary tolerance and an interior that includes the shaft can make a thick cross look like a filled ellipse. A mostly white surrounding ring does not establish a separate musical body.

The [independent 29-case challenge](../musical-span-independent-2026-10-03/candidate-v1/README.md) recovers nine complete owner envelopes without new losses, including the full broken-stem case. The [separate attached-symbol and three-head addendum](../musical-span-attached-addendum-2026-10-03/README.md) additionally finds a false hollow span in an attached `pp` context and incomplete outer-owner coverage when three true heads share one shaft. Those useful bounded results remain separate from the real-score rejection.

## Evidence and next step

[comparison.json](comparison.json) lists all thirteen changed rectangles and eight added spans. [summary.json](summary.json) records exact counts and scope. `source-and-results.zip` preserves the native inventory, candidate result, renderer and replay sources, all candidate Core dependencies, input hashes, comparison self-checks, and source-review panels. Full-page rasters and binaries are rebuildable and omitted from the archive; their hashes and original renderer inputs are retained. Every archived member is hash-bound in `archive-manifest.json`.

A subsequent experiment must distinguish the complete source body from thin strokes continuing through its neighborhood. It must preserve the full connected head-to-head interval for every affected owner, including three-head cases. The rejected V1 must not be combined with the earlier numbered-line cleanup or included in an app release.
