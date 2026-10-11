# Brahms Quartet recheck — October 10, 2026

The recommended **assisted IMSLP93521 delivery** is in [output/pdf/brahms-recheck-2026-10-10](../../../output/pdf/brahms-recheck-2026-10-10/README.md). It contains the complete four parts, 151 source systems per part, 604 crop bands and 78 output pages (20/20/19/19). The 39-page original is embedded unchanged in the editable project; page 1 is cover material. This is a recheck and assisted correction, not a detector change or a fresh-Auto success claim.

The final project preserves every crop and instrument identity in the latest [October 4 reviewed project](../../../output/pdf/auto-qc-2026-10-04/brahms-quartet-93521-reviewed-trims/README.md), including its seven source-reviewed crop trims, the Viola page 8/system 2 `in tempo` descender repair, nine saved page rectifications and all 42 previous shared source copies. It adds 72 explicitly reviewed source copies: 23 rehearsal letters in three lower parts (69 destinations), plus the shared page 31/system 4 fermata in those three parts. The resulting total is 114 copies. No music was transcribed, erased or replaced.

The author inspected all 83 fresh corrected Auto output pages, all 78 broader assisted cue output pages, and all 43 pages changed by retaining the seven trims. The other 35 final pages have identical complete PNG hashes to the already viewed broader assisted pages. Final saved-project decode and native reexport produced identical placement geometry and identical page rasters at 36 DPI on all 78 pages. This is a complete pagination and crop-placement overview, supplemented by targeted source review; it is **not a new exhaustive note-by-note oracle for all 604 crops**. Existing reviewed crop geometry is inherited explicitly.

An independent reviewer compared all seven trimmed rows in the immutable original, corrected full-width source context and final PDF. They also reinspected all 72 new actual cue destinations beside 24 original source regions after the final repagination. No intended target notation loss was identified in those seven rows; intended letters and fermata glyphs were complete at all new destinations. Band identity and order, all 42 older copied-region rectangles and above/below placement flags, all page bounds and absence of vertical placement collisions were independently verified. See the [independent receipt](../brahms09200-recheck-2026-10-10/cross93521/README.md); its hashes bind the actual final PDFs and project.

Some partial neighboring staff lines, note fragments, dynamics and source page debris remain. The seven trims reduce complete foreign five-line staff-core inclusions from seven to zero in the native staff-line inventory; that geometric count does not mean every foreign fragment is gone. The earlier typed header and 48-point side margins are retained. Current literal system spacing and the additional cue rows produce more pages than the older 64-page export; musician-chosen page-turn placement is outside this recheck.

## Fresh Auto findings

Fresh current native `PartsmithDocument.detectScore` used the compact four-instrument profile, all 39 pages, automatic source-header detection and shared-direction copying. One run used the previous nine rectifications and a separate run used the unrectified original. Both found all 604 intended staff cores with correct source order and no blocking direction issues; the rectified plan is semantically identical to the earlier recorded detection plan. This does not establish complete notation coverage.

Fresh corrected Auto still clips the foot of Viola's own `in tempo` descender on page 8/system 2 and omits the 72 lower-part cue destinations listed above. The unrectified run also clips the Viola forte hook on page 34/system 4; the rectified/assisted output retains it. Endings on page 6/systems 3 and 4 and page 37/system 2, the Da Capo below page 28/system 2, and Coda on page 28/system 3 were visually checked in actual exports and are present. Strict black-pixel checks against broad source-oracle rectangles also include adjacent beams, notes and slurs; those apparent rectangle misses must not be reported as omitted cue glyphs without visual classification.

The second 25-page IMSLP09200 source has a separate [fresh-Auto report](../brahms09200-recheck-2026-10-10/README.md). These manual corrections do not change its results. The author here independently viewed all 53 of its output pages as a pagination overview and recorded the duplicate conditional ending direction in Violin II. Its source-context review and musical findings belong to that separate report.

## Evidence and replay

- `complete-band-inventory.json` and `.csv`: all 604 part/source-page/system/output-page identities and exact native geometry.
- `parent-preservation.json`: exact latest-parent retention, existing-copy preservation and native schema-default normalization (`usesSharedLayout: true`). Only the project modification timestamp and new source copies otherwise change.
- `manual-cue-additions.json`: frozen source coordinates, exact per-page dimensions, intended part/system and source provenance for all 72 copies. Some source pages differ by one point in size; a first harness draft used a constant size. Independent review caught that conversion error, and the final coordinates match within 1e-8. The failed draft is retained as intermediate evidence and is not delivered.
- `retained-seven-trims.json`: prior frozen target envelopes and exact seven crop edges, reused without widening or tightening further.
- `audit.json`: complete native structural checks and clearly separate broad-rectangle/pixel guard results.
- `final-page-review.json`, `final-v-broad-page-comparison.json`, `reopen-verification.json`: per-page overview, exact carry-forward hashes and native saved-project reexport verification.
- `focused-comparisons/`: actual fresh-versus-final output examples for rehearsal A, Viola `in tempo`/F, and the shared fermata. Independent source/actual-output comparisons are in `../brahms09200-recheck-2026-10-10/cross93521/`.
- `replay.zip`: native harness, preparation/render/audit/report scripts, raw/rectified fresh plans and inventories, saved geometry/project JSON and logs. No alternate detector or exporter is used. Run commands from the repository root on macOS with PDFKit/AppKit and Python's PyMuPDF/Pillow/NumPy available.
- `source-hashes.json` and `source-hashes-final.json`: production detector/model/layout/export files remained unchanged during the run.

Individual full-page PNGs and most repetitive contact sheets are ignored scratch under `.build/brahms-recheck-2026-10-10/verbose-page-renders/`. `verbose-render-location.json` retains their checksums and locations; `render_review.py` regenerates them from actual PDFs. Selected compact contact sheets and focused comparisons remain here. Broad assisted and fresh draft exports remain separate scratch comparisons and must not be advertised as the recommended final delivery.

Original source SHA-256: `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`.
Corrected review derivative SHA-256: `be1074d1436da4737bab07e360d1f6b4fda8b011db7b3a598e60cd62891cf8b4`.
