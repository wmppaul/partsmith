# Heading glyph continuation study — 2026-10-03

The bounded source-ink continuation fix passed this study and was promoted by root on 2026-10-03 as the exact frozen detector `9e6ca0f8b208068d0de6219a6d8997cd2038c9b0b43fd888eb41732b6d6a2db9`. The initial study and historical failed drafts remain unchanged. Baseline is `e9ef3d16bbb95ad88093157a76603abe0b7eaac2`. This bounded change recovers source pixels belonging to a letter already intersected by an accepted heading rectangle. It does not recognize new headings or claim whole-score recall.

## Frozen source obligations

The previous accepted-heading source review identified a visibly clipped initial **A** in Brahms quartet IMSLP 09200, physical page 14, and a tiny initial-A fringe in IMSLP 242312, physical page 14. Its independently drawn initial-A guards, original 63-region inventory, source hashes, and complete-heading obligations were copied unchanged before experiments. No source guard, crop oracle, or acceptance threshold was relaxed.

The original source failure arises in Vision's incomplete word envelope plus insufficient fixed horizontal padding. Ink measurement only observes what is already inside that source rectangle; the planner faithfully copies the rectangle, so it cannot recover the omitted stroke. The candidate therefore runs before grouping and ink measurement.

## Candidate behavior

The helper follows a connected dark component crossing a horizontal source edge, using a search bounded to 1.5 staff spaces. A component must have text-like dimensions, enough original ink inside the rectangle, and a complete visible boundary inside the search window. Components touching the vertical or horizontal search limits, including connected staff/clef/stem fragments, cannot justify expansion. The staff boundary caps vertical search. The source rectangle can only expand horizontally; all old edges and pixels remain retained, and unchanged coordinates keep their exact original doubles.

This is source-pixel continuation, not a new uniform margin. Disconnected neighboring text cannot justify growth. The fixed search radius also intentionally declines a letter whose complete edge lies beyond that search. All five staff positions must be finite, in [0,1], and strictly ordered; invalid saved geometry returns the original rectangle. Cancellation checks include the connected-component queue and discard partial results.

## Completed source and focused controls

* All 63 accepted fragment rectangles were replayed against their hash-bound original source-page rasters. Exactly two boxes grew; the other 61 remain exactly unchanged. Every original rectangle remains wholly enclosed.
* 09200 page 14 grows left by 3.389 pt at the 216 dpi review raster: all 57 previously omitted dark pixels return. All 199 initial-A guard pixels survive. Every added dark pixel lies inside the frozen A guard; no additional staff/slur pixels enter.
* 242312 page 14 grows left by 0.611 pt: the one previously omitted dark pixel returns. All 57 initial-A guard pixels survive. No added dark pixels lie outside that A guard.
* Both before/after source contexts were visually checked. The severe A stroke is visibly restored; the light edition change is only the previously documented fringe.
* 20 dedicated controls pass, covering left/right recovery, isolated-glyph idempotence, bounded search, separate neighboring text, horizontal staff, shallow slur, stem/clef continuation, unchanged original metronome/punctuation ink, invalid geometry, and cancellation.
* The existing 59 shared-heading controls pass against the scratch candidate.

An initial implementation round-tripped unchanged horizontal doubles through pixel coordinates, changing 14 boxes and failing strict non-shrink equality through floating-point noise. It was rejected; the final helper reuses each original coordinate unless there is actual outward expansion. The rejected source/results are retained under `historical-drafts/`.

One initial synthetic right-side fixture accidentally extended 16 pixels past the edge while the unchanged bounded search reached 12 pixels. The failed draft is retained under `historical-drafts/`; the final suite includes that original farther shape as an explicit refusal control and a truly mirrored 8-pixel crossing as the symmetry control. The source guards, search reach, and implementation were unchanged by this test-fixture correction.

## Full native validation

The fresh 16-score/449-page native heading run completed with zero OCR/render errors and all 16 plans applicable. It retained all **6,324 crops, 62 coalesced heading blocks, and 251 copied rows**. Exactly the two expected Agitato rectangles and their six recipient copies expanded. Every other inventory field, complete assignment field, and OCR observation is exactly unchanged. Both new native boxes also pass the original pixel-center guard checks: all 57 severe-edition pixels and the single light-edition fringe pixel return, with no added dark pixel outside the initial-A guards. The full original crop envelope remains intact.

Its baseline is the prior full `candidate-final` run, whose **23 Core Swift files are byte-identical** to this task's frozen e9ef3d1 baseline. `native-baseline-binding.json` binds all 64 baseline native evidence files. This avoids rerunning the same baseline OCR while preserving exact source provenance.

`compare_native.py` compares all full heading objects, OCR observations, complete assignment geometry/ownership/order/warnings, and copied rows. It never normalizes away OCR or geometry differences. Fresh baseline and candidate PartsmithDocument/coordinator runs also completed both full affected PDFs (26 + 25 pages), including staff detection, headings, navigation/destinations, shared endings and local counterpart recognition. Their **960 complete crop assignments are exactly equal**, except for the two corrected heading rectangles propagated to six source-marking rows. All four runs have applicable plans, zero direction issues, unchanged projects, main-thread completion and cleared progress. The final blank page in 242312 is automatically skipped in both variants. Candidate completion times were 103.5 and 73.5 seconds with maximum heartbeat intervals of 65 and 69 ms; these concurrent, unpaired timings are diagnostic, not a performance benchmark.

The raw full-worker inventory diff retains 22 scalar differences caused by five pairs of ink components changing array order. Every component object, including staff ownership, has an exact matching object in the opposite variant; no geometry or ownership value is new or lost. The affected physical pages are 242312 pp1/9/14 and 09200 pp16/25. All non-heading/non-component-order fields match, and all final crop assignment fields match. This pre-existing ordering variability is documented rather than normalized away in the raw diff.

The genuine worker also showed why a fresh baseline was necessary: its modern source analysis differs from the older cached input used for the heading-only pass, including one 242312 crop bottom. Both fresh variants produce the same bottom, so that difference is not attributable to this helper. `worker-comparison.json` preserves the exact fresh comparison and source hashes.

All eight native draft parts were exported by the owner/delivery agent (43 output pages for 242312 and 41 for 09200). PDF rendering and source-to-output review belong to the separate delivery report; this report does not certify every musical crop or page turn.

## Independent review

The independent reviewer passed 272 invariant controls and visually checked all 63 original contexts and candidate boxes. Its source-pixel calculation independently agrees with the frozen guards and the two recovered A regions. See [the independent review](../heading-glyph-independent/README.md).

The review also reproduced three important boundaries: (1) fully contained musical shapes that resemble letters can expand the crop; (2) repeated application to already expanded bounds is **not generally idempotent** because a second detached component can cross the new edge; and (3) faint <224-excluded fringes, detached ink, vertical clipping and letters beyond the search can remain unrecovered. The candidate is called exactly once on fresh OCR boxes before grouping. These limits are retained explicitly; the isolated-glyph idempotence control is not a universal guarantee. No accepted corpus region acquired new musical ink.

## Limits

The 63-region replay certifies preservation and narrow recovery in previously accepted regions, not missing-heading recall across 449 pages. Earlier neighboring notation, companion fragments, missing German tempo changes and song numbers remain explicit in the preceding accepted-source review and Schumann study. Whole-page/whole-score musical readiness is not inferred from passing box controls.

Independent review is complete. Root promoted the exact frozen detector after the full native and source controls; no heading heuristic or fixture was changed during promotion. Large source PDFs, page rasters, frozen Core snapshots and native binaries stay in scratch; their hashes bind the retained evidence.

## Replaying this study

Run from the repository root. `run-controls.sh` and `run-source-regions.sh` compile their dedicated harnesses against the frozen candidate Core by default (or an explicit Core path argument). The source-region replay uses the 62 hash-bound page rasters from the preceding accepted-source review. Its `render.py` can recreate those source rasters from the bound PDFs, including the already rectified 93521 source; corrected coordinates must never be applied to the raw PDF.

`build-headings.sh` compiles the retained `native-run_headings.swift` staged at the scratch `native/run_headings.swift` path; `native-config.json` is its complete 16-case configuration. Running that binary with `candidate` produces the fresh full-page result. `compare_native.py` checks it against the bound native baseline. `build-worker.sh` and `build-baseline-worker.sh` compile the genuine app coordinator harnesses; `worker-config.json` binds the two full PDFs and profiles. `compare_workers.py` retains the full raw diff and separately identifies exact component permutations. `check_native_source_pixels.py` checks the native changed boxes against immutable pixel-center guards using Pillow and NumPy.

The repository baseline commit supplies the 23 original Core Swift files, and `candidate.patch`/`candidate-ScoreSharedHeadingDetector.swift` preserve the complete one-file candidate. `artifact-bindings.json` binds frozen Core snapshots, compiled tools, test outputs, native inventories/plans, and independent review evidence; `report-hashes.json` binds the durable report itself. Large PDFs, full native binaries and page rasters remain outside this report. No original source PDF is modified.

For a subsequent combined Core snapshot, `python3 Tests/quality_control/heading-glyph-continuation/run_combined_checks.py CORE NEW_OUTPUT --include-categories` runs the 20/59/57/272/4 focused suites and preserves all frozen study outputs. The supplied output directory must not already exist. This wrapper only relocates test outputs; all test assertions and fixtures remain unchanged. The first combined run passed 20 + 59 + 57 checks, then the wrapper hit an output-name collision: its independent-result directory had the same name as its executable. Root preserved the linker failure, changed only the two output-directory references to `independent-results`, and ran the remaining 272 + 4 checks successfully in a fresh directory. No production or control assertion failed. All combined results live in `brahms-continuation-native-2026-10-03/regressions/`; they are separate integration evidence.
