# Known limitations

Partsmith remains a geometry-first, assisted extraction app. The score-part-extraction skill is a parallel workflow for ChatGPT/Codex; neither performs notation recognition or re-engraving.

## Detection and musical review

- Find Staves runs offline on one page at a time. It detects five-line staff geometry, not instrument identity or musical completeness.
- Staff counts can be wrong on severe skew, curved scans, faint or broken lines, and dense engraving. Line confidence does not certify crop boundaries.
- Lyrics, dynamics, slurs, ledger notes and shared tempo/rehearsal marks require visual review. Instruments can disappear during tacet passages, so repeated staff order must be checked before applying it.
- Scan rectification and staff detection are separate steps. Rectification remains editable; failed rectification cannot be silently used for staff proposals.
- Rectangular whiteout areas can remove spatially separate neighboring fragments. They cannot separate ink that physically overlaps target notation. Changes to a crop or rectification require reviewing its whiteouts again.

## Editing and layout

- Whiteout areas are edited numerically in the inspector and checked in Preview; direct drawing/dragging of whiteouts on the source canvas is not implemented.
- Bands retain left/right trims, but the source overlay still emphasizes full-width top/bottom editing. Inspect Preview to judge horizontal trimming.
- No notation reflow, transposition, generated multimeasure rests or automatic page-turn optimization.
- Explicit page breaks and editorial strip labels are editable in the native band inspector. Drag reordering and automated musical page-turn planning remain absent.
- Native export respects printable margins. Scale above 100% is capped at the available width; unusually tall indivisible bands shrink to fit and may need manual readability correction.
- Rotated PDF pages and unusual CropBox/MediaBox combinations need special care. The skill rejects unsupported geometry rather than silently mapping it into a native project.

## Platform and workflow

- macOS only; direct local build, not an App Store or notarized release.
- Source PDFs are embedded in project bundles for portability.
- Background staff detection supports cancellation and stale-result checks. Preview/export and some older analysis paths can still block on very large scores.
- No page thumbnail sidebar, batch multiselect editing, or automatic matching of layout templates across varying pages.
- Focused regression harnesses cover extraction, layout, export masks and native detection transactions. They do not replace testing across a larger engraving/scan corpus.
- The historic bundled sample project contains exploratory crops and is not a musical gold standard. Use the reviewed examples and recipes described in [EXTRACTION_WORKFLOW.md](EXTRACTION_WORKFLOW.md).
