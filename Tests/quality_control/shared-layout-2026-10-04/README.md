# Shared score layout review

67 focused native checks passed with no failures. New app-created parts inherit the score's scale, system gap, and side margins. Explicit part overrides freeze all three values; returning to shared settings resumes synchronization. Future parts, one-step undo/redo, save/reopen, asymmetric margins, preview cancellation, and PDF export are covered.

The migration check used the existing Brahms Quartet excerpt under four legacy configurations: its original settings, equal custom settings, differing custom settings, and asymmetric project margins. All 38 output pages across 10 parts match the pre-change exports pixel-for-pixel. The baseline was compiled from Core sources copied before any production edit for this request; its inputs and per-page raster hashes are preserved separately from the new implementation.

`results.json` lists every assertion. `source-hashes.json` identifies the 25 Core Swift files, two test tools, and real-score input files used. `provenance.json` includes the baseline source, PDF, and raster hashes. `pre-change-baseline-inputs.zip` contains the untouched Core sources, baseline generator, and exact legacy project fixtures; the large source PDF remains in its existing repository location. The small PDFs here are synthetic export fixtures demonstrating shared and local settings, not newly extracted musical parts.

Run the focused current-code tests from the repository root with:

```
tools/test_shared_layout.sh .build/shared-layout-review-before/fixtures
```

Omitting the baseline argument runs the ownership, persistence, geometry, and preview checks without comparing historic raster outputs. To regenerate the legacy comparison fixtures, restore the archived files under `.build/shared-layout-review-before`, compile its `baseline.swift` against the archived `Core` Swift files, and run that binary from the repository root before running the current-code tests. The baseline generator reads `output/pdf/brahms-preservation/String Quartet No. 3- Op. 67 - excerpt- PDF pages 1-3.partsmithproject` without changing it.

This review did not open or modify the user's running application or project documents. Native Inspector interaction is evaluated separately.
