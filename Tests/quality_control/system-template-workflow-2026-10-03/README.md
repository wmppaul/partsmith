# Reviewed system templates: complete native workflow, 2026-10-03

**Pass for instrument assignment, preserved initialization edits, and counted silent time. Not a musical-quality or performance-ready export pass.** Two independently reviewed Erlkönig examples produced 46 correct additional system suggestions. User acceptance through the actual `ScoreSystemAssignmentBatch` API produced a complete plan, which passed the actual document apply transaction, layout engine and PDF exporter. The accepted and exported plans are equal.

The frozen matcher is `fe3504a1ba9b86659a6bc5bed37ef1e6424ca4c63d8deb959d45f3ad4a8d2df7`; batch implementation is `6ac5b995b42e0440cd43c86872cd1f7471203ef174b61db65a946f3e97759c2b`. All 25 Core files used by this workflow matched current production at the freeze. `source-bindings.json` binds them and the native exporter; `implementation-snapshot.zip` contains these sources. The exporter adaptation only removes its `@main` annotation so the workflow driver can invoke it after the accepted batch.

## Input authority and independence

The original source is `sample_scores/normal/03_piano_vocal/schubert_erlkonig_d328_score.pdf`, SHA256 `dfd76c0ddb804d0587048c61e4edec8dcd7a75b6e39e27420087ed510d89046b`. The complete instrument roster was read from all original pages before this matcher existed, as recorded in [the three-score source audit](../variable-profile-roster-audit-2026-10-03/README.md). The earlier [complete Erlkönig source/output review](../erlkonig-independent-review-2026-10-03/README.md) independently established the printed measure spans and source corrections.

`two-reviewed-seeds.json` supplies only page1/system1 (Piano, Voice absent) and page1/system5 (Voice+Piano). Empty intermediate entries are placeholders, not instrument assignments. The seed retains three explicitly reviewed music-crop rectangles and the complete original-source opening tempo copy for the initial Voice rest. The separately confirmed three additional omitted systems use printed starts4/7/10/13 to supply counts3/3/3; their source evidence is recorded in `confirmed-silent-counts.json`. No measure counts or starts are taken from the matched template. The 43 new full-roster systems keep nil measure metadata.

The initialization fixture deliberately has no automatic heading/navigation metadata. Only its explicit reviewed opening copy is supplied. Later manually reviewed direction copies and post-extraction crop corrections are not part of this identity-matching test.

## Native results

All 18 workflow checks passed (`workflow-summary.json`, `workflow.log`):

- The matcher returns exactly46 correct, complete physical systems; every candidate ID and instrument roster agrees with the independently frozen source map.
- Accepting all suggestions without supplying the three required omitted-part counts fails atomically. The original seed overrides remain unchanged. An incomplete initial review has no exportable bands and cannot apply.
- The completed plan contains96 ordered items:48 per part, comprising92 printed music crops and four3-bar generated Voice rests. Every detected source staff appears once in the correct printed part. The twelve introductory silent bars remain in time and in order.
- Both seed overrides remain exactly equal. Their reviewed source crop edges and explicit tempo-copy edges are reproduced in the accepted plan to numerical precision. Preservation is checked against the stored source obligations, not against a nonexistent partial-plan crop.
- `PartsmithDocument.addScoreParts`, `PartLayoutEngine`, and `PartPDFExporter` export both full parts. The exporter’s replan equals the accepted batch plan.

The ignored scratch outputs are `.build/system-template-workflow-2026-10-03/parts`: Voice has5pages with9/9/10/10/10 systems; Piano has8pages with5/6/6/6/6/7/6/6. `output-bindings.json` hashes both PDFs, source-embedded editable project, plan and manifest. These are validation artifacts and do not replace the already delivered, manually corrected draft.

Across the complete three-score matching study (`three-score-comparison.json`), eight reviewed examples covered82 source systems:56 correct further suggestions among74 unreviewed systems,18 abstentions, and no incorrect roster/system/candidate grouping. Counts by source are Erlkönig46/46, Notte8/18, Mendelssohn2/10. Six suggestions still require separately confirmed silent counts. The matched examples do not constitute automatic instrument-name recognition. The [independent matcher review](../system-template-independent-2026-10-03/README.md) includes the separate fixed32-challenge evaluation; `matcher-controls.json` records this implementer’s23 controls.

## Actual output review and remaining defects

All13 exported pages were rendered and inspected on the included contact sheets. Original source and actual output strips were compared for the known detached hairpin. No new page overflow or placement collision was observed in this layout inspection; it is not a new complete glyph-by-glyph review.

Compared with the previous native-baseline export,91 of92 music-crop rectangles are identical; the sole change is the already reviewed first-Piano top edge supplied in the seed. Compared with the manually corrected draft,88 of92 music rectangles are identical. The four exceptions are precisely the three Voice top-edge cleanup edits and the Piano hairpin expansion that this test deliberately does not apply. `export-comparison.json` records every changed crop/copy row and all source/output bindings.

The important remaining failures are explicit:

- **The original page4/system4 Piano diminuendo is missing.** Its source ink ends at814.9606pt; the native crop ends at798.8612pt. The included original-source context and actual exported strip show the omission. The separate reviewed draft expands this edge to816.5pt; template matching does not perform that correction.
- Large neighboring Piano fragments remain above Voice systems on source pages2/4/6. Smaller neighboring lyric/notation fragments also remain in both parts.
- The initialized Voice rests still omit the common-time indication and occupy four3-bar rows. They are not a newly engraved consolidated12-bar rest.
- Later direction copies are outside this test’s initialization: Andante is not copied to Voice; accelerando and Recit are not copied to Piano. Those three manually reviewed copies exist in the separate complete assisted draft. This test proves retention of the existing opening copy, not automatic direction discovery after assignment.
- Page turns have not been optimized. In this5-page Voice export, turns27→28,84→85 and116→117 split continuing phrases/pickups;54→55 has a rest opportunity. Piano continues playing through its page turns. The separate4-page corrected Voice draft also retains its previously reported three phrase-splitting turns, at different measures.
- Existing printed/generated bar-number duplication remains. The matcher does not infer full measure spans for printed systems.

Notte page3 abstains because the initial Piano clef changes in two systems; an additional reviewed example could address that variation. Page4’s close systems fail the conservative source-edge blank-interval witness. The Mendelssohn arrangement retains unresolved layouts where the current source-template evidence is insufficient. No threshold was weakened to make these scores appear complete.

The matcher reruns source staff detection and checks outer connecting-line continuation. This rejects stale, removed or phantom staff inventories (the initial prototype’s concrete omitted-staff false matches were reproduced before fixing them). It does not prove that the shared staff detector can never miss a staff. Every suggestion still requires explicit user acceptance; separate or uncertain printed group boundaries can require direct score review.

## Reproduction

Run `build-and-run.sh` from this directory or the repository root on a Mac with Xcode and the bound sample PDF. It unpacks the frozen implementation into ignored scratch, compiles `workflow.swift`, and runs matcher→batch→review→document apply→layout→export. The original source PDF is hash-checked before work. No production file or source PDF is rewritten. Repeated export preserves the previous scratch generation under a backup name.

`compare-exports.py` reproduces the comparison/contacts when the previously reviewed native and corrected scratch references remain available. The durable comparison, source obligations, implementation archive and output hashes remain useful without those scratch references. `hashes.json` binds every report/fixture file; archive members are separately checked in `source-bindings.json`.
