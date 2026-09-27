# Proposed production integration

The isolated detector now exists at `Partsmith/Core/Detection/ScoreSharedEndingDetector.swift`. Its SHA256 is still `5adb7f35ed5668a80331340db69b4ded4153daf102f079db1041d3489d99db12`, identical to the independently reviewed prototype. It is not yet called from the application or added to the Xcode target.

`bash tools/test_shared_endings.sh` passes 60 controls. The default run replays the recorded complete 68-page result rosters through the production detector's pair selector and requires byte-identical paired results, including literal evidence. It does not repeat score rasterization or OCR. `bash tools/test_shared_endings.sh --vision`, run with normal Mac OCR access, passes 69 controls including all three synthetic full-geometry/Vision prose and Roman-I negatives. The test no longer depends on generated `.build` inventories or fixture images. Test logs are `.build/shared-ending-tests.log` and `.build/shared-ending-tests-vision.log`.

## Model and planner

Add `ScorePageAnalysis.sharedEndings: [ScoreSharedEnding]? = nil` alongside headings/navigation. Keep it distinct from empty-text navigation glyphs: the destination CLI currently filters its empty-text navigation entries when replacing destination recognition. An ending stored there would be deleted by a later symbol scan.

Suggested minimal `ScoreSharedEnding` fields:

- `anchorStaffID` and normalized `bounds`, matching the existing planner's source-copy geometry.
- A stable `pairID` and `pairPageIndices`, including both pages for cross-page endings. These support invalidation of both halves when either source assignment changes.
- Member evidence with source page/system/anchor identity, first/second role, and the detector's literal text observations (mode, text, confidence, bounds). Preserve ambiguous fast `I`; the UI label may say “Printed first/second ending,” but exported numerals remain the source pixels.

Create one page-local metadata item per verified system/anchor in each pair. Union copy rectangles only when both candidates share that page, system and anchor; otherwise create one item on each system. This reproduces the five copied source rows for eight Brahms brackets. Validate finite bounds and page dimensions before normalization.

Reuse the existing planner's navigation-copy geometry through a local adapter or shared helper. Do not put endings into persisted `sharedNavigation`. Preserve explicitly supplied source-marking override arrays (including empty), owner crop overrides, complete contained-original deduplication, and the existing no-overlapping-copy safeguard. Clear ending metadata in the detector's temporary ownership-verification page just as headings/navigation are cleared, once the property exists.

## Workflow and review

Add a fifth `.endings` progress phase and an injectable throwing page service returning `ScoreSharedEndingDetector.PageResult`. It uses the same saved source transformation and 2400×3500 raster limit as the reviewed detector.

Initialize a `PageResult` barrier for every selected physical page, then replace it only with a valid detector result. Include unresolved pages and pages whose raster/OCR failed; do not pass only the successful/eligible pages to pairing. Missing input indices must remain gaps. A verified blank page can preserve musical adjacency, but an empty staff list alone must not be described as proof that the physical page is blank. Unknown staffless pages should remain conservative barriers unless the workflow has affirmative blank-page evidence.

Call `pairs(in:)` only after all selected page results are collected. Pairing is independent of reference-symbol discovery and should run even when there are no navigation sentences or usable symbol templates. Populate only `sharedEndings`; preserve already recognized headings, navigation and destination symbols. Catch a page's Vision failure into the optional issue list and retain ordinary crops, without imposing a new acceptance gate. Cancellation at any stage discards the new pass, matching the workflow's current atomic cancellation behavior.

Extend review bindings to capture/invalidate ending-owned copies. Assignment/profile/staff-identity changes on either source page invalidate the linked pair on both pages, while manual copies and explicit recipient omissions remain authoritative. Crop-only changes should retain recognition as they do now. Keep ending pair provenance separate from destination references; a first/second pair is not a jump destination.

In `ScoreExtractionView`, match ending metadata to its copy rectangle and label it “Printed first/second ending” instead of “Printed repeat symbol.” Use the existing source highlight/removal controls and optional issue presentation. Amend the experimental option/help to say paired first/second endings are included, while unsupported unpaired/third/list endings remain limitations. No checkbox or required review step is needed.

## Required bounded verification before enabling Auto

1. Codable round-trip with old inventories (missing endings), new literal evidence, and pair provenance; destination-only rerun must leave ending metadata intact.
2. Injected workflow tests: all selected pages supplied to pairing, sparse-page gap, unresolved/failed-render/failed-OCR barrier, affirmed blank, no-navigation positive, cancellation during/after page analysis and pairing, and preservation of all other recognition categories.
3. Planner tests: same-system union and cross-system separation, source-owner original kept once, authoritative removed copy not restored, manual copy preserved, and collision behavior unchanged.
4. Review tests: editing either half's source assignment invalidates both automatic copies but not manual markings; removal survives replan/save/reload/apply/undo/redo. No acceptance gate on optional detection failure.
5. Replay the hash-bound final detector results into the current planner and compare the delivered eight Brahms brackets and two Mozart brackets. Confirm main crops, prior copies, per-part system coverage, and source bounds; do not rerun all 68 pages merely to re-establish an unchanged detector result.
6. One packaged-app positive source run and visible label/highlight/removal inspection. Then build/package with the newly included detector. Keep the six frozen safety-envelope failures visible; production inclusion does not turn them into geometry passes or certify all musical directions.
