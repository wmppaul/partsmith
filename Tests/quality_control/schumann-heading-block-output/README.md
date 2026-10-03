# Schumann 06822 — complete output review of the heading block fix

Draft, 2026-10-03. The final native Auto result copies the complete **SCHERZO. / Molto vivace. / dotted-quarter = 138.** block into all four recipient parts. All 825 music crops are unchanged, and the full five-part export remains 74 pages. Existing neighboring notation and local heading duplication remain; this is a bounded change review, not print-ready approval or a whole-score recognition claim.

## Authoritative run and output

The actual `PartsmithDocument.detectScore(profile:copySharedDirections:true)` coordinator ran fresh staff detection and all shared-direction phases over the original 56-page score. It automatically skipped the empty first physical page, produced 825 bands, reported no direction issues, allowed applying the plan, and left the project unchanged during detection. Its authoritative inventory/plan are under `.build/heading-blocks-2026-10-03/native-worker-final/schumann-{inventory,plan}.json`. The separate heading-only corpus replay is supporting evidence; it was not used as the export input.

The exporter was compiled from the immutable final Core at `.build/heading-blocks-2026-10-03/candidate-final/Core`. Its re-created plan exactly equals the actual coordinator's plan, including the heading metadata. Source, profile, title, composer, layout settings and rectifications match the prior delivered native Auto set. The editable project's embedded source matches original SHA-256 `b8b9f6431438a6bd4c9593fffb46278418fbb211b7d81b6953d920faf8cf744e`.

New complete output: `.build/schumann-heading-output-2026-10-03/parts/`, including all five PDFs, `manifest.json`, `plan.json` and `Schumann Piano Quintet Op44 — Auto QC.partsmithproject/`. No older output or app package was changed by this review. `provenance.json` binds the final Core, worker, inventory, exporter, source, all PDFs and editable project.

| Part | Systems | Pages | Changed output page |
| --- | ---: | ---: | ---: |
| Violin I | 165 | 12 | None |
| Violin II | 165 | 12 | 6 |
| Viola | 165 | 12 | 6 |
| Violoncello | 165 | 12 | 6 |
| Piano | 165 | 26 | 12 |

## Exact change and source review

Exactly four shared-heading copies change, all at physical source page 26, system 1: Violin II, Viola, Violoncello and Piano. Each old source rectangle `[65.80830, 37.78978, 122.83850, 52.31939]` is contained in the new rectangle `[65.80830, 37.78978, 147.42612, 59.57051]` (top-down PDF points). The count remains 35 source copies overall: the four expanded headings replace the incomplete versions. All other copies, including the 15 ending copies, remain unchanged.

The original source was inspected before reading the final candidate bounds. A source-only guard was measured at 576 dpi and frozen. All four copies contain every required text, metronome and punctuation pixel in `[65.875, 40.125, 145.875, 57.875]`. The numeral and music symbol remain original source pixels; no text was retyped or re-engraved.

**Four strict conservative guard failures remain recorded.** The original larger guard ends at y60.0 and includes a tiny isolated scan speck below the word Molto at x82.875, y59.75–60.0. The copied rectangle ends at y59.57051. Original-source inspection shows this speck is separated from the text by blank rows and lies well left of the metronome and final punctuation. It is not required musical ink. The frozen guard was not moved: `source-guard-validation.json` reports all four strict failures alongside all four complete-text successes; `p26-source-speck-classification.json` preserves the source-only classification.

All 74 output pages were rendered at 108 dpi and compared with the prior delivered PDFs. Seventy page rasters are pixel-identical; only the four pages in the table change. Thirty-one band placements move vertically within those same pages. Page breaks, part/system order, main crop bounds and staff identities are unchanged. No page overflow or adjacent band-plus-copy envelope collision is introduced. Each expanded heading keeps uniform scale and a 4-point gap above its music crop.

The reviewer inspected the original full heading and first system, all four old and new copied rows, all four previous full pages, and all four changed full pages. The complete metronome note, dot, equals sign, 138 and final period are visible. Before/after rows and full pages are archived in `row-review/` and `page-review/`; `comparison.json`, `new-copy-rows.json` and `changed-page-index.json` give the exact identities.

## Remaining draft limitations

- Piano source p26s1 retains its locally printed Molto vivace, so the complete shared block repeats those words while supplying the previously missing metronome. The unchanged Cello crop includes the neighboring Piano Molto vivace below its staff, making the wording appear there too.
- Piano p19s3/output page 9 still repeats Agitato; that page is pixel-identical to the previous set. Opening Allegro brillante wording also remains repeated, with the shared copy supplying its metronome.
- Dense main crops still contain neighboring notes, staff lines and slur fragments. All those crops are unchanged by this heading fix.
- The known Schumann p29s3 missed ending pair and Cello p18s2 neighboring Piano ending remain. Neither ending recall nor general cleanup is established by this change.

`known-limitations.json` retains these distinctions. Runtime was 218.23 seconds wall / 212.86 seconds awake under concurrent checks; maximum main-thread heartbeat interval was 1.430 seconds wall / 0.154 seconds awake. These are measurements of this run, not responsiveness guarantees.

The archived `export.sh` refuses to overwrite an existing completed output; choose a new destination for reproduction. `compare.py` is bound to the exact baseline and authoritative native inventory and does not run OCR. Source and binary bindings are in `provenance.json`.
