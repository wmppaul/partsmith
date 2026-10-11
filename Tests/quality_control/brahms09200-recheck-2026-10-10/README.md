# Brahms IMSLP09200: current native Auto recheck, 10 October 2026

The complete 25-page score produces four complete part drafts: 120 systems per part, 480 bands total. No intended note, ledger line, local slur or local dynamic was identified as cut off in the 480 source crop contexts reviewed. **This is not a performance-ready automatic extraction:** shared directions remain incomplete, and neighboring notation is common.

| Part | Systems | PDF pages | Copied source regions | Bands containing another staff's top line |
| --- | ---: | ---: | ---: | ---: |
| Violin I | 120 | 14 | 1 | 80 |
| Violin II | 120 | 13 | 10 | 93 |
| Viola | 120 | 13 | 11 | 86 |
| Violoncello | 120 | 13 | 10 | 12 |

The last column is a geometric indicator of neighboring staff retention, not a count of foreign notes or complete foreign staves. The broad Andante opening and Violin II page 7/system 2 are especially conspicuous. Rectangular crops can legitimately retain adjacent notation to preserve target notes and slurs.

## What was exercised

Current production `PartsmithDocument.detectScore`, with shared-direction copying and automatic source-header proposal enabled, ran on the immutable original source. The initialized four-part compact profile has one staff per instrument and no crop overrides, exclusions, padding overrides or rectifications. Auto completed in approximately 60 seconds, returned no issues, and proposed 32 source copies. Its input project remained unchanged before acceptance.

The current production native apply/layout/PDF exporter then generated all four PDFs and an editable project. Export used a typed title/composer: the automatic header proposal was recorded but was not used in this PDF export. Instrument setup was provided through the profile; this recheck does not test name-picking UI or automatically infer the instrument list.

The input is `sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf`, SHA-256 `ff883e06db2bc69c5de0c45fa447795201805ecf7210b76c50168b64f0570689`.

## Review and findings

All 120 source identities were checked in order in each part against the independently source-reviewed `Tests/full_scores/brahms-quartet-tight-map.json`. Every band retains its detected five staff lines, preserves aspect ratio, stays within the source and output page, and has no collision with adjacent music or source-copy rows. All 53 output pages were viewed; none was blank, off-page or an unexplained isolated short page. Page turns were not certified as suitable for performance.

All 480 source crop contexts were viewed at approximately 1.7 pixels per source point, with blue crop boundaries and context beyond both edges. Forty-six discrepancies against historical padded target guards were additionally viewed in detailed contact sheets. Their excluded ink belongs to neighboring notation or empty guard margin; no intended target loss was identified. This is a visual review, not a note-transcription oracle or an exhaustive output pixel comparison.

Every main source crop rectangle exactly matches the earlier native glyph-continuation output. Current layout and direction copying differ: the earlier native set had 41 PDF pages and 29 copies; this run has 53 pages and 32 copies. These counts must not be presented as an automatic crop improvement.

The conditional **“2da volta rit.” at source page 22/system 1 is now present in all three lower parts**. Violin II retains it twice because its broad music crop already contains the source instruction and Auto adds a separate copy. See [the actual output comparison](direction-p22s1.png).

The first/second ending pairs on **source page 21/system 3, page 23/system 4 and page 24/system 2 are absent in all three lower parts**. See [page 21](direction-p21s3.png), [page 23](direction-p23s4.png) and [page 24](direction-p24s2.png). Many source rehearsal letters and source measure-number gutter labels also are not propagated reliably. A zero-issue Auto result is not proof that shared markings are complete. Check the score. Adding these missing source-marking copies requires an assisted/script workflow; the released app has no general drawing UI for adding a source copy. Crop expansion can retain nearby directions, and Editorial Label can add text at a system start, but it cannot place interior ending brackets at their musical positions.

The machine report contains 357 padded shared-fragment noncontainment prompts, including 238 printed measure-label prompts. **Those are not 357 proven missing glyphs.** A fragment can fail strict rectangle containment while its actual lettering is present. The confirmed ending cases above were decided from original-source and actual-output images.

## Evidence and replay

`input-bindings.json` binds the original and 27 production Core sources. `output-bindings.json` binds the actual native PDFs, project and placement manifests. `structure-and-guard-review.json` records coverage, layout, guard prompts and neighboring-line metrics. `output-contact/` contains the complete 53-page overview, and `guard-prompts/` contains all 46 detailed edge prompts.

`replay-evidence.tar.gz` preserves the frozen production Core, native harness/export utility, profile, analyses, plans, log, summary, saved project JSON and audit/render scripts; every archive member was read back and hash checked against `replay-archive-manifest.json`. Immutable source PDF, exported PDFs and rebuildable binaries are omitted from the archive. Actual PDFs and editable project remain in `.build/brahms09200-recheck-2026-10-10/parts/`.

To reproduce from the repository root on macOS, unpack the archive into `.build/brahms09200-recheck-2026-10-10/`, compile its Core files plus `worker.swift` with optimized Swift/AppKit/PDFKit, and run the worker. Separately compile the same Core plus `tools/export_score_plan.swift`, and export using the archived inventory/profile with the typed title `Brahms — String Quartet No. 3, Op. 67` and composer `Johannes Brahms`. Use a new export directory. Native OCR/graphics access is required. The Python audit/render scripts use PyMuPDF, NumPy and Pillow.

`cross93521/` is a separate, bounded independent review of the other agent's current IMSLP93521 results. It must not be used to claim that the 09200 directions were corrected.
