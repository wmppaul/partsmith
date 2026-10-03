# Brahms crop and heading continuation — October 3

This checkpoint combines two bounded changes against `e9ef3d1`: carrying the identities of five staff lines through short scan interruptions, and retaining connected letter strokes just outside accepted heading boxes. The original score pixels are never edited. Both reviewed source files are now promoted unchanged into the [universal Mac preview](../macos-build-2026-10-03-continuation.json).

## Crop evidence

All 36 corpus PDFs, 1,477 physical pages, were analyzed afresh against a frozen baseline and two candidate versions. V2 adds deterministic trace tie handling; its eligibility rules are identical to V1. Both runs retain every detected staff coordinate, assignment identity and order. Exactly two music crops change, both on Brahms IMSLP93521 physical page 29, system 1: Violin I's lower edge and Violin II's upper edge. Their connected-notation warning is removed; other plan fields remain unchanged. Across the corrected complete quartet, whole-neighbor occurrences decrease from nine to seven and the other 602 crop rectangles are identical.

The baseline and V2 each pass the existing 755 crop checks. Independent review runs 297 new source-mask controls and 336 frozen controls twice. It finds no new failure or worsened target envelope. **The baseline's 96 failures among the 297 controls and all 336 older failures remain**; these changes do not solve musical-stem ownership. Both changed real-score strips were examined against the original full system, including low notes, slurs, dynamics and repeat notation. Foreign fragments remain in the improved strips. See [independent crop review](../residual9-boundary-independent/README.md) and [source/mask tracing](../residual9-boundary-source/README.md).

The raw corpus includes unresolved instrument assignments. It yields 6,936 provisional bands from 17 inputs, not 36 successfully extracted scores. Nineteen variable-layout inputs emit no bands; a further ossia input has a partially unresolved plan. Equality of those plans is not evidence of musical preservation after manual assignment. Most raw component-array differences are ordering alone; nine pages have actual component geometry changes. Eight occur on unresolved Schumann/Beethoven pages and receive a separate source review in the independent crop report. Full musical correctness, automatic instrument naming and omitted-rest inference are not certified here.

## Heading evidence

The heading change follows a complete, connected source component across a horizontal OCR edge within a bounded search. It expands accepted boxes only; it does not invent letters, recognize new headings or shrink existing source bounds. The frozen initial-A guards in two other Brahms editions remain unchanged. Exactly two accepted Agitato boxes grow, restoring 57 dark pixels in IMSLP09200 and one dark pixel in IMSLP242312; every added dark pixel lies inside the original A guards.

Fresh native heading recognition on the retained 16-score/449-page staff inventories preserves all 6,324 music crops and changes only the two boxes and six recipient copies. Separate full native document-worker runs on both complete affected sources repeat staff detection and all direction phases: all 960 main assignments remain exact. See [the glyph study](../heading-glyph-continuation/README.md), [272-control independent review](../heading-glyph-independent/README.md), and [complete eight-part PDF review](../brahms-glyph-output/README.md).

This helper is geometric. A contained musical shape resembling a letter can qualify; repeated application to already expanded boxes is not universally idempotent; faint, detached, vertically clipped or farther ink can remain unrecovered. The native path applies it once to fresh accepted OCR boxes. None of the 63 reviewed accepted regions gains extraneous dark musical ink.

## Combined native workflow

The frozen combined Core was run through `PartsmithDocument.detectScore`, with shared-direction copying enabled, over all 39 pages of IMSLP93521. Both baseline and candidate use the exact original source hash and nine saved rectifications. Each run completes in about 77.2 seconds on this Mac; candidate main-thread heartbeat intervals stay below 56 ms. This is an observed run, not a general performance guarantee.

Both produce 604 bands and 42 copied directions, applicable plans, no direction issues, correct main-thread completion and cleared progress. Detection leaves the input project unchanged. The full plan differs only in the two reviewed crop edges and their associated warning removals. Every heading, ending copy, identity and ordering field is unchanged. Source inventories differ semantically only at the page-29 connector; tied component ordering is recorded separately in `native-comparison.json`.

The complete four-part export and source-embedded project are reviewed in [the output report](../brahms-continuation-output/README.md) and [a second independent review](../brahms-continuation-output/independent-review.md). The quartet still has 64 pages: 46 are pixel-identical to the actual baseline export. All 17 Violin I pages change spacing after automatic page-fill balancing, and Violin II changes only on page 12. Source page 31 system 2 moves intact from output page 14 to 13. Both reviewers examine all 18 changed pages; the resulting turn remains in continuous fast playing and is not a musically optimized turn. No output row is lost, reordered, clipped by the page or overlapped by another output block.

Together with the two glyph editions, this checkpoint delivers 12 complete part PDFs on 148 pages plus three source-embedded editable projects. Old outputs remain available. Suitable musical page turns, missing shared instructions and the seven remaining whole-neighbor cases remain unfinished work.

## Reproduction and provenance

`native-evidence.zip` contains the exact baseline and combined Core sources, actual worker harnesses, fresh staff/direction inventories and plans. `native-evidence-manifest.json` binds every archived member and verifies archive integrity. The retained corpus scripts, input hashes, binary hashes, status records and comparisons bind the 36-score runs; the much larger raw inventories remain in their recorded scratch locations. The independent report additionally checks complete plan objects, ordered coverage and normalized component multisets rather than treating array permutations as geometry changes.

Combined-Core checks pass: 20 glyph controls, 59 existing heading checks, 57 initial-override/grouping checks, 272 independent glyph controls and four heading-category checks. The combined heading regression wrapper initially attempted to link a binary to an existing results-directory path. This orchestration failure is retained; its already-passing controls are not rerun or relabeled. The path was repaired and the remaining suites run separately. No production change or test expectation was needed to repair the wrapper.

The extraction skill now documents the unresolved-page diagnostic check. Its installed reference resolves to the same updated repository file, and the skill validator passes.

No live SwiftUI interaction or replacement of the user's running app is claimed. The saved scores and user's documents remain untouched.
