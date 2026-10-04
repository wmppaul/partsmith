# Brahms horizontal alignment, scale, and spacing regression

The 39-page score in the user's screenshots is `sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf`. This review uses four existing Violin I bands on source page 3 from the reviewed Brahms project. It does not rerun extraction or modify that project.

## Results

- At the same requested 1.05× scale, the former layout shifted section A 19.70 output points left of the following system because its tiny right-edge scan speck made its retained crop wider. The new layout maps the same source x position identically for all four strips, with numerical spread below 0.0000001 pt. See `alignment-comparison.png`.
- Requested scales 1.3× and 1.4× are both applied. Their actual notation-size ratio is exactly 14/13. These deliberately exceed the available width: the exported pages visibly clip clefs and key signatures at their physical left edge. They demonstrate the user-authorized override and should not be treated as usable musician parts. The app must warn about clipping.
- With Balance Page Fill enabled, gaps measure exactly 100 and 200 pt. The four-strip example uses one and two pages, respectively. Balancing no longer reduces the chosen gap.
- 11 baseline checks and 69 candidate checks pass. All seven rendered pages across six cases are pixel-identical to independent complete-original-crop references when rasterized by CoreGraphics at 2×. Source-image transformation matrices in both PDFs also match exactly. Screenshots use MuPDF for visual inspection; its clip-dependent resampling differs, so it is not the pixel oracle.
- The original project and PDF remain byte-for-byte unchanged. Every source-band ID, order, and vertical crop bound is preserved. Existing neighboring notation inside the stored crops remains visible.

The fixture uses 30 pt side margins to match the screenshot setting and hides headers/page numbers to isolate music geometry. `verify.swift` generates the reference from each complete original source crop; it does not reuse the exporter's trimmed crop. `before/results.json`, `after/results.json`, and `review.json` contain measured geometry and results. Source hashes cover all 25 Core files used by both test binaries, with only the layout engine differing between baseline and candidate. The baseline layout source is included for reproduction.

## Reproduction

From the repository root, compile `verify.swift` with the Core DocumentModel, Detection, Layout, and Export Swift files, then run the resulting binary with `after`. To reproduce the baseline, substitute `baseline-PartLayoutEngine.swift` for the current layout engine and run with `before`. Both runs write private test output under `.build/brahms-alignment-2026-10-04`. The original reviewed Brahms project and source are required at the paths recorded in `input-hashes.json`.
