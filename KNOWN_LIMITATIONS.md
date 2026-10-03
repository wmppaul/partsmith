# Known limitations

Partsmith remains a geometry-first, assisted extraction app. The score-part-extraction skill is a parallel workflow for ChatGPT/Codex; neither performs general note recognition or re-engraving. The app can automatically count and replace eligible single-staff, whole-rest strips; this is a narrow notation recognizer, not general optical music recognition.

## Detection and musical review

- Auto Extract analyzes and assigns the entire score offline after a saved, manually verified instrumentation setup. Find Staves remains a single-page tool. Printed instrument names can be picked with local text recognition; this does not establish musical completeness.
- Staff counts can be wrong on severe skew, curved scans, faint or broken lines, and dense engraving. Line confidence does not certify crop boundaries.
- Lyrics, dynamics, slurs, ledger notes and shared tempo/rehearsal marks require visual review. Instruments can disappear during tacet passages, so repeated staff order must be checked before applying it.
- The current complete-score regression covers 84 source pages and 1,357 printed staves across five scores. All counts match independent source maps, with additional tests for dense piano and false narrow staff patterns. This is a measured corpus result, not a guarantee for arbitrary scores.
- Neighboring notes can remain when complete target preservation is the goal. A preservation pass does not mean a cleanly isolated part. Missing target notation always fails; a cleaner-looking strip is not evidence of musical correctness.
- The October 3 stem-preservation revision passes all 336 expanded musical-source fixtures and improves a separate 297-case suite from 201 to 238 passes. The remaining 59 cases, including broken source strokes and curved ownership, are still failures. Uncertain connections can add neighboring music: corrected Brahms93521 page 38 retains an extra staff in Viola and Cello because a curved tie resembles a terminal note body. This is a documented false positive, not proof of a shared musical stem.
- Separate diagnostic crops on unresolved orchestral pages expose the same tradeoff: 18 of 20 expanded staff crops add a neighboring five-line staff core. They retain their previous source pixels, but do not establish recovered target notes or correct instrument assignments. The raw corpus's 91-to-87 whole-neighbor count covers its 6,936 provisional assigned crops and excludes these unassigned diagnostics.
- Scan rectification and staff detection are separate steps. Rectification remains editable; failed rectification cannot be silently used for staff proposals, preview or PDF export. The app reports the source page that needs correction.
- Rectangular whiteout areas can remove spatially separate neighboring fragments. They cannot separate ink that physically overlaps target notation. Changes to a crop or rectification require reviewing its whiteouts again.

## Editing and layout

- Whiteout areas are edited numerically in the inspector and checked in Preview; direct drawing/dragging of whiteouts on the source canvas is not implemented.
- Bands retain left/right trims, but the source overlay still emphasizes full-width top/bottom editing. Inspect Preview to judge horizontal trimming.
- **Expand Crop** moves all four edges outward by a chosen number of source PDF points, clamps at page edges, and supports undo. It does not recognize missing notes or remove existing whiteouts. The skill's protected-region guards are not yet enforced by native project editing.
- Automatic rest compression requires a complete single staff with clear barlines and one hanging whole-measure rest per bar. Playing entries, ambiguous opening symbols, interior changes, fermatas, repeat notation and unknown ink cause the original strip to be kept. Opening-symbol recognition currently handles treble and bass clefs; uncertain alto/tenor clefs stay unchanged. Grand staffs, partial-system rest runs and automatically joining successive source strips are not supported. Broad crops with neighboring ink can prevent recognition even when the target staff is silent. Manual counts remain available; original crops are always retained.
- No general notation reflow, transposition or understanding of musically convenient rests for turns. Balanced pagination minimizes page count and avoids sparse final pages; it does not choose turns by listening or reading notes.
- Explicit page breaks and editorial strip labels are editable in the native band inspector. Drag reordering and automated musical page-turn planning remain absent.
- Shared source marking rectangles render at the same scale and horizontal source position above or below a part. Auto's experimental direction option recognizes some printed headings, navigation directions and paired endings; it does not establish complete shared-direction coverage. Rehearsal letters and several observed endings remain missed. Copied boxes can retain neighboring notation or duplicate words already visible locally. The app preserves and can remove these rectangles; editorial text directions can also be added directly.
- Native export respects printable margins. Scale above 100% is capped at the available width; unusually tall indivisible bands shrink to fit and may need manual readability correction.
- Rotated PDF pages and unusual CropBox/MediaBox combinations need special care. The skill rejects unsupported geometry rather than silently mapping it into a native project.

## Platform and workflow

- macOS only; direct local build, not an App Store or notarized release.
- Source PDFs are embedded in project bundles for portability.
- Background staff detection supports cancellation and stale-result checks. Preview rendering runs in the background and cancels superseded changes. Export and some older analysis paths can still block on very large scores.
- Auto has an input-page thumbnail selector; general source-page thumbnail navigation and batch band editing remain absent. Auto flags uncertain cadence, but unusual layouts still need manual page assignment or an explicit reviewed plan; a plausible staff count alone is not proof of the correct mapping.
- Focused regression harnesses cover extraction, layout, export masks and native detection transactions. They do not replace testing across a larger engraving/scan corpus.
- The historic bundled sample project contains exploratory crops and is not a musical gold standard. Use the reviewed examples and recipes described in [EXTRACTION_WORKFLOW.md](EXTRACTION_WORKFLOW.md).
