# Native paired endings in Auto — 3 October 2026

The production Auto direction workflow now includes the separately reviewed paired first/second-ending detector. This check runs fresh native recognition on every original page of Brahms IMSLP93521 (39 pages, nine unchanged saved corrections) and Mozart K.498 (29 pages). Both scores use the previously initialized instrument profiles. It does not test automatic instrument-name discovery, printed-header selection or automatic rest compression.

All five known pairs are found, with no additional pair in these two scores and no recognition issue. Brahms retains 604 main crops and 42 copied rows; Mozart retains 405 crops and 10 copied rows. Both native plans exactly match the frozen native integration expectations. Ending metadata remains separate from navigation and keeps both source-page dependencies, source rectangles and literal OCR evidence. The broader corpus scan is a separate review, not implied by these two positives.

## Complete exported parts

All seven parts are exported through the app's `addScoreParts`, layout engine and PDF exporter: 64 Brahms pages and 39 Mozart pages. Every main source rectangle, physical staff identity, part/system order and output-page assignment matches the earlier delivered drafts. Saved projects contain all parts and bands, the original source bytes and unchanged corrections.

Every one of the 103 output pages was rendered at 144 DPI and compared with the earlier drafts. **101 pages are pixel-identical.** The initial exact-placement check stopped at Mozart's viola ending row; that discrepancy was investigated rather than hidden with a numerical tolerance. The native detector's page-25 first/second-ending union differs from the older Python prototype by about 0.10 points vertically. Two source-copy rows change (Viola and Piano); their slightly different height moves subsequent rows by 0.00213 points on output Viola page 9 and Piano page 16. These differences remain explicit in `export-comparison.json`.

Both changed full pages and enlarged source/output regions were visually checked. The first/second numerals, dots, horizontal brackets and descending hooks are complete above the correct systems. No new target-note clipping or intersystem overlap was observed. Existing neighboring fragments remain visible, especially in the viola. The native plan is not claimed to be pixel-identical to the older Mozart prototype. The comparison tool treats main-crop changes as errors and records every changed placement/page for source review; a successful process exit alone is not a musical-quality pass.

## Actual document worker and cancellation

A separate complete Brahms run uses `PartsmithDocument.detectScore`, including fresh staff analysis, all five direction phases and the app's review initializer. All 604 bands and 42 source-copy rows exactly match the fresh native workflow. The run takes 63.96 awake seconds on this Mac; its 50 ms main-loop heartbeat has a maximum observed interval of 63.6 ms. All progress/completion callbacks are on the main thread, the project remains unchanged until acceptance, and progress clears when finished.

A second real worker run is cancelled after entering the ending phase. Cancellation clears progress synchronously, the superseded completion never publishes, and no stale direction event arrives. A one-page replacement completes in 0.327 seconds with 12 bands. These are measured runs, not timing guarantees.

## Regression and UI scope

The permanent ending-app suite passes 54 coordinator/planner/review assertions plus 27 worker/lifecycle assertions; the optional frozen 68-page replay passes 65 plus 27. Existing direction-app tests pass 113. Additional suites pass: crop quality 755; planner 83; heading 59; navigation 77; destination 24; native ending 69 (including fresh Vision image controls); system-boundary crops 423; rest detection 250 including 34 real-score fixtures.

The universal Release app builds for arm64 and x86_64. Independent code review covers the ending labels, links to both printed source members, per-recipient removal and existing focus behavior. Live SwiftUI interaction with this new build remains unverified because no computer-use tool is available. This distinction is not an acceptance barrier in the product; there is no new required review checkbox.

## Remaining musical failures

This is a draft preview. The nine whole-neighbor Brahms occurrences, other neighboring fragments, missing shared directions and unresolved page turns remain. The six immutable Brahms ending safety-envelope failures remain recorded in the earlier native-ending review; source inspection found complete ending ink, but the conservative rectangles were not relaxed. Unsupported unpaired, third/list endings and ambiguous source layouts are not inferred. The separate 48 near-edge musical-stem failures also remain open. This integration makes the reviewed ending behavior available through Auto; it does not establish complete-corpus musical readiness.

The broader ending scan subsequently found seven missed pairs across Brahms IMSLP09200, Brahms IMSLP242312 and Schumann06822, plus five redundant Piano copies where Schumann already prints local endings. Those findings constrain the app feature beyond this two-score integration check; see `ending-corpus-2026-10-03`. The preview retains these explicit limits while recipient-aware suppression is investigated.
