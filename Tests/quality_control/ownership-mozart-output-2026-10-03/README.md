# Mozart K. 478: complete native Auto output comparison

**Complete reviewed draft, ready for the parent release step.** Both actual document workers process all 30 source pages with the unchanged supplied instrument profile. There are no unresolved assignments, skipped pages, manual mappings, rectifications or manual page breaks. The final candidate creates four parts with 119 systems each: Violin 8 pages, Viola 8, Violoncello 9, Piano 18; 43 pages total. The source-embedded editable project was saved, decoded, reopened and exported through the native app model.

Private final set: `.build/ownership-mozart-output-2026-10-03/candidate/parts/`. Actual baseline: sibling `baseline/parts/`. Intended later publication: `output/pdf/auto-qc-2026-09-21/mozart-k478-86903-preservation/`; this report does not assert that publication has occurred.

## Source and execution binding

The original `sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf` is bound by SHA256 `33ba263af431caa89d16530adcce3bf230b9c8b2e2367b737835c112fcfc99c8`. Its four-part profile is `Tests/quality_control/profiles/medium-skewed-01-mozart-piano-quartet-k478-imslp-86903.json`, SHA256 `5d93694865c47331398c9926dae08956fa45473c6d885148d603c322fe30f533`. The initialized names/order are Violin, Viola, Violoncello and two-staff Piano; this is not a test of automatic instrument-name recognition.

The baseline freezes all 23 Core files from commit `82b606e`. The older raw-corpus candidate-v2 snapshot contains a different heading detector, so it was not used as the full app baseline. The tagged candidate differs from commit 82 in only the analyzer and planner: SHA256 `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01` and `0cfd6f6fdb1b926a16c4984f63a6d0a4fdf0261878875508916c646a739784b2` respectively.

Both workers call `PartsmithDocument.detectScore(profile:copySharedDirections:true)` on the complete source, including native staff and shared-direction recognition. Each completes with 476 bands and 6 copied directions, zero issues, unchanged project, main-thread completion and cleared progress. Measurements under concurrent checks were 50.17s baseline and 50.62s candidate, with roughly 61ms maximum wall-clock heartbeat interval; these are observations, not timing guarantees. Full logs, progress, inventories, plans, configs, the23-file snapshots and binary hashes are retained in `evidence/{baseline,candidate}/`.

The exporter applies the native review transaction, saves an original-source-embedded project, verifies exact JSON roundtrip and embedded source equality, reopens it and exports all parts. The native layout verifies that no band is lost or reordered. The original scan is preserved without deskew or cleanup. A shorter typed title, “Mozart — Piano Quartet, K. 478”, replaces an overlong test title; both versions were identically re-exported. All musical placements and all nonheader pixels remain exact in that title-only step (`title-fit-check.json`). Earlier-title outputs remain in scratch `parts-long-title-not-delivery/` and are not the final set.

## Compared results

`worker-comparison.json` and `full-plan-diff.json` show only two crop-bound changes and removal of their now-unnecessary ambiguous-connection warnings. All other plan fields, staff metadata and shared heading/navigation/ending recognition metadata are unchanged. All six copied source rectangles remain exact. There are no substitute recognition fixtures or manually edited assignments.

| Crop | Before vertical bounds, points | After vertical bounds, points | Final output |
|---|---:|---:|---|
| Source p25, system1, Violin |40.8179–96.5419|40.8179–82.6475|Violin p7|
| Source p25, system1, Viola |44.1404–101.9788|68.0024–101.9788|Viola p7|

All86 baseline/candidate pages were rendered at 108 dpi and compared. Forty-one of 43 candidate pages are pixel-identical to the corresponding baseline; only Violin p7 and Viola p7 change. No strip changes output page; total pages and systems per page are unchanged. All unchanged strip dimensions are exact, with no fitting roundoff. Every destination rectangle, including copied directions, remains inside its page and does not intersect a neighboring row. `output-comparison.json` binds all final PDFs and every placement.

## Source and visual review

This reviewer inspected the original p25 context and full page before the fresh candidate crop images and froze `source-obligations.json`. Then both final full changed pages and their high-resolution exported rows were inspected. The Violin's low sharped opening note, stems, rests, p, entry accidental, beams, slurs and rightmost figure remain. The Viola's opening note, accidentals, p, sustained chords and long paired ties/slurs remain. The complete neighboring staff is removed in each changed crop; partial fragments remain.

The parent independently inspected both changed full pages and both exported rows against its earlier source-first review. Both reviews found no new target-note, slur or dynamic loss and no new layout collision. The final title-only export preserves those reviewed musical pixels. All six copied-direction rows and all four first pages were additionally viewed. `visual-review.json` records the exact scope; the final full changed pages and row images are retained here.

## Draft limitations

- Neighbor staff fragments remain throughout these unchanged scanned crops. This improvement does not provide a generally clean separation.
- The original source itself cuts ongoing notation at the right edge, including p25. The export cannot restore ink absent from the original.
- Piano source p1 Allegro and p12 Andante already appear locally and are duplicated by automatic copies. Cello crops also include those neighboring Piano headings, producing doubled headings. These conditions are pixel-identical in baseline and candidate; all six source-copy rows are preserved as evidence.
- The complete score has not been checked note by note for recall, and its page turns have not been optimized for performance. Fixed profile resolution is not proof of universal instrument identification or full musical completeness.

`delivery-hashes.json` binds the final private set and original embedded source. `report-hashes.json` binds this durable evidence record. Parent publication may copy the verified set into the intended output folder and record that separately without changing this report.
