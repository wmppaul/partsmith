# K488 bar-number export regression review

**Pass for the requested export regression.** The baseline and numbered full exports contain the same nine parts, 53 pages and 702 placements. Every placement record is exactly equal, including source/destination geometry, ordering, instrument/staff assignment, page turns and crop metadata. The only differing per-part manifest field is the PDF byte hash. All 702 stored starting numbers and planned measure counts were independently matched to the reviewed system overrides.

Every page was rendered with the same Poppler renderer at 144 dpi and compared pixel by pixel. All 702 retained notation regions are exactly unchanged. Across the complete pages there are zero removed/lightened pixels; the 170,955 changed pixels are all added dark ink in the left margin, between x=21.5 and 41.5 PDF points, outside the 48pt source-content margin. This verifies actual retained notation, not only equal crop rectangles. It is a regression comparison, not a new whole-score recall certification.

The saved project comparison maps UUIDs to stable project/part/band identities and disregards creation/update timestamps. Apart from the modification timestamp, the only changed project values are the expected 603 ordinary-music `barNumberMode`/`barNumberValue` pairs. The 99 generated-rest items already had their reviewed numbers. The plan gains reviewed `startBarNumber` and `barCount` on all 702 items; all other plan values remain equal.

## Tight-margin actual exports

Using a frozen copy of the current Core (including the final tiny-row fix), this review reopened the **directed** project and exported the complete source-page-17 excerpt for Flute, Piano and Violin I with Scale 1.4 and zero side margins. Choosing the directed project makes this test include three real copied SOLO/TUTTI directions. There are nine placements on three output pages: six ordinary source crops and three generated-rest items.

All six ordinary number rectangles are on paper and disjoint from every placement, all copied directions, other number rectangles and the title. All three PDFs were reopened, rendered at 120 dpi and visually inspected. Numbers 144/150/153 are legible and clear of music; copied directions remain visible. The preexisting generated-rest badges remain legible and do not cover a rest-count numeral or retained source notes. Source-printed bar numbers remain visible, so some labels are duplicated cosmetically. Existing adjacent-staff fragments and tiny fragments within copied directions are retained; this change does not clean them up.

The QA PDFs and rendered pages are in `narrow-p17/`. Their actual placement geometry and source/copy bounds are in `narrow-p17/geometry.json`. They are stress-test excerpts, not replacements for the complete published parts.

## Code and fixture review

The new layout path places ordinary numbers in the margin when there is room, otherwise reserves a separate 16pt row above the source/copies. The final short-row condition reserves that row when the scaled source height is below the 12pt number height. Its pagination height includes that reservation, and capacity checks reject a label that cannot fit. The exporter draws the number into this supplied rectangle without drawing a white badge over the source crop.

The new 142-check generated-rest fixture was inspected together with the final code and its passing log. It covers reviewed spans surviving planning/materialization/apply; omitted optional starts staying hidden; ordinary label on-paper/music/copy/title disjointness at 48/12/0pt margins; twenty very short crops with a 4pt system gap and pairwise number separation; and actual K488 p17 starts/rest counts in all nine exported parts. The short-row assertions would detect the previous successive-label collision. The fixture's source-marking overlap loop alone can be vacuous when no copies are present; this independent actual directed-project excerpt supplies three real copied directions. The fixture was not rerun because the root's current 142-check run already passed; this review instead adds the actual export/pixel evidence.

## Evidence and limits

`export-comparison.json.gz` contains every page/region result and exact metadata differences. `reviewed-number-binding.json` records the 702 checks against reviewed overrides. `source-bindings.json` binds both complete source/export sets, the current fixture/log, frozen Core, replay harness and all rendered images. `compare.py` and `narrow.swift` reproduce this review. No production source or tests were edited.

The initial comparison summary accidentally compared whole part manifests, including changed PDF hashes, when labeling placement equality. The placements had already passed exact equality assertions. That reporting field was corrected, with the initial result retained as `first-comparison-including-pdf-hash-field.json.gz`; no pixel, geometry or acceptance guard changed.
