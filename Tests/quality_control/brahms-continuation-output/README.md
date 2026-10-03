# Brahms 93521 combined-candidate output review — 2026-10-03

The complete four-part native output is preserved at `output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-continuation/`. It contains the PDFs, editable reopened project, original embedded score, corrected source-review PDF, exact plan and placement manifest. This review supports the bounded two-crop improvement and complete export/pagination preservation. It does **not** certify that every pre-existing musical ambiguity in this difficult scan is resolved.

## Source and production path

The immutable original 39-page PDF is SHA256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. Baseline and combined-candidate inventories come from separate complete native PartsmithDocument/coordinator runs, owned by root. The combined snapshot contains the ordered staff-continuity V2 analyzer (`e6541355…`) and heading glyph continuation (`9e6ca0f8…`). Each variant's exporter was compiled against its own frozen Core. The nine saved corrections on physical pages 2, 7, 17, 19, 23, 28, 34, 38 and 39 are exactly equal to the prior delivery; p29 is uncorrected. The initial cover is automatically skipped.

Both variants use native Auto review/application, project package encode/decode, reopening, PartLayoutEngine and PartPDFExporter. Their saved plans are exactly equal to the corresponding fresh worker plans. The original PDF bytes survive inside each package unchanged. Prior title/composer, Letter paper, 48pt margins, scale1, preferred gap16, balance-page-fill and consistent-scale settings were retained exactly. No manual crop or instrument assignment was added.

| Part | Systems | Pages | Copied shared directions | Pixel-identical baseline/candidate pages |
|---|---:|---:|---:|---:|
| Violin I | 151 | 17 | 1 | 0 |
| Violin II | 151 | 16 | 14 | 15 |
| Viola | 151 | 16 | 14 | 16 |
| Violoncello | 151 | 15 | 13 | 15 |
| **Total** | **604** | **64** | **42** | **46** |

All source bands remain in exactly the same score order, with no missing, repeated or reordered placement. Every copied direction's source rectangle is unchanged. Exactly two main source rectangles differ: p29s1 Violin I's bottom moves 91.652912→75.762052pt, and Violin II's top moves 35.268801→59.223679pt. Neither part retains the full neighboring staff there. The separate heading continuation fix produces no source-heading change in this edition.

## Source-first notation and output inspection

Before the candidate page comparison, I viewed the original full p29 first system and read the existing independent source obligations. The ten independent envelopes were copied unchanged, including their historical analyzer label. All ten remain contained in **both** actual exported variants (20 checks). The p29 target notes, ledger/accidental shapes, slurs, articulation, p/pp, hairpins, repeat signs and Poco Allegretto heading remain visible in the actual output. Violin II's low sharp note at the right is retained. The copied heading above Violin II remains at the same musical location.

Every baseline and candidate output page was rendered at110dpi (128 pages), and every corresponding page was compared pixel-for-pixel. All 64 candidate pages were visually checked in the complete per-part overview sheets. Detailed before/after inspection covered Violin I pages1,8,13,14,17 and Violin II page12, including both changed source rows and the changed page turn. The remaining Violin I page overviews were checked for layout continuity; their complete side-by-side comparisons are retained. This is a layout/delta review, not a new full musical transcription audit of every unchanged crop.

The two shortened source crops trigger normal automatic reflow. Violin I spacing changes across all17 pages; source p31s2 moves intact from output page14 to13. Page13/14 changes from9+9 systems to10+8. All other system-to-page assignments are unchanged. Violin II changes only output page12, with the same nine systems. The other46 pages are pixel-identical, including all Viola and Cello pages.

All placed bands and copied-direction blocks remain inside the48pt margins, with no overlap. The smallest union-to-union block gap is5.170pt for Violin I,5.273pt for Violin II,6.216pt for Viola and5.973pt for Cello. The practical music scale is unchanged; the two bottom-fit placements differ in width by at most0.0000065pt from floating-point fit arithmetic. No blank or sparsely orphaned new output page appears, and page counts remain17/16/16/15.

## Independent output review

A second agent independently rendered and viewed **all18 changed candidate pages**, the current corrected source, both changed p29 strips, and the complete p31s2 strip moved across the page turn. Its [review](independent-review.md) accepts the bounded crop improvement as a draft, with no new clipped note, dropped system, off-page content or collision. It separately verifies the difficult page turn and retained neighboring fragments rather than treating them as solved. `independent-results.json` and `independent-hashes.json` bind its source/PDF checks and images; every delivered PDF hash matches that independent review.

## Remaining limitations

The new Violin I page13→14 turn remains within continuous fast playing, as the previous turn did; this release does not optimize turns around rests. Seven previously documented whole-neighbor overlaps remain elsewhere, together with many foreign staff/note/slur fragments. The new p29 strips still contain neighboring fragments at their edges. These are complete **draft** parts and are not a claim of clean engraving or universal crop correctness. The broader source audit and unresolved synthetic musical-stem cases remain in `residual9-boundary-independent/` and the root's continuation report.

## Evidence and reproduction

`frozen-inputs.json` binds both whole native inventories/plans, frozen Core snapshots, original previous layout, source guard and original p29 image before output inspection. `comparison.json` records every placement change and all64 raster comparisons; `layout-geometry.json` and `output-guards.json` preserve margins/gaps and all20 envelope results. `delivery-hashes.json` binds the installed10 files. The complete source-first image and prior after-strip musical review remain in `residual9-boundary-independent/source-review/`.

`export_reopened.swift` and `build-export.sh` are the actual exporter harness and builder. `review.py` checks native-plan equality and previous source/layout settings, renders all128 pages, compares pixels and creates the retained visual sheets. It requires Pillow/NumPy and Poppler. `check_layout.py` runs the unchanged envelopes and independent output-block checks. `artifact-bindings.json` binds the large scratch exports, render pages, source/binaries and delivery files; `report-hashes.json` binds this durable report. No original score or prior delivery was replaced, and the shared delivery index remains root-owned.
