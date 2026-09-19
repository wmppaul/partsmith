# Offline native staff detection review

Run `bash tools/test_staff_detection.sh --samples` from the repository root. This builds the actual Swift detector and document APIs, checks synthetic and document behavior, and regenerates `index.html` / `results.json` with full-page overlays. The app uses only built-in macOS frameworks; no network, downloaded model, Python, or server is needed at runtime.

## Measured sample results

Numbers are detected five-line staves, not verified playable parts. Page numbers below are one-based PDF pages.

| Source (pages 1–3 unless noted) | Expected | Original raster | With app rectification where estimated |
| --- | --- | --- | --- |
| `Partsmith/Resources/Fixtures/SampleScoreFixture.pdf` (pages 1–2) | 2 / 2 | 2 / 2 | — |
| `normal/01_chamber/mozart_string_quartet_kv387_score.pdf` | 16 / 16 / 16 | 16 / 16 / 16 | — |
| `normal/01_chamber/mozart_trio_eb_major_kv498_score.pdf` | 16 / 20 / 20 | 16 / 20 / 20 | — |
| `normal/04_choir/mozart_ave_verum_corpus_kv618_cpdl18715_complete_score.pdf` | 16 / 16 / 16 | 16 / 16 / 16 | — |
| `lightly_skewed/02_brahms_clarinet_trio_op114_imslp_114011.pdf` | 12 / 16 / 16 | 12 / 16 / 16 | 12 / — / 16 |
| `medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf` | 16 / 20 / 20 | 16 / 20 / **19** | — / — / **20** |

Score paths are under `sample_scores/` except the fixture. The medium quartet's third PDF page needs the existing 0.675° app rectification to recover the omitted staff. A dash means no correction was estimated above the app's threshold, or no correction was requested for that sample. Corrected images in the report come from the actual `SourcePageRenderCache`, with no fallback to the original image.

The macOS graphics sandbox used by development tooling can make CoreImage return nil, including with its software renderer. The report's corrected cases were verified with local graphics access outside that sandbox. The detector's app integration rejects a failed requested rectification instead of applying original-image coordinates to a corrected page.

## Iterations and checks

The first detector missed dense beams that connected adjacent staff-line peaks. A local peak threshold separated the long staff lines from the shorter beams. Independent horizontal windows then recovered slightly bowed/slanted scanned lines. Fitting the full five-line height, rather than just the first line interval, stopped small scan/raster spacing errors from accumulating.

Automated checks cover blank/text-only pages, isolated short beams, faint and tilted staves, imperfect spacing, top-down geometry, notation padding, deterministic results, and adjacent staves. Document checks exercise multi-staff grouping, duplicate suppression, one-step undo/redo, invalid/nonconsecutive groups, background detection, cancellation, and stale page/rectification rejection. The first five source fixtures have count assertions; the exact medium quartet is an additional measured stress case with its uncorrected miss retained in the report.

## Required review

The green boxes are editable proposals. They can clip lyrics, figured bass, ledger notes, slurs, and crowded dynamics, or omit a shared tempo/rehearsal marking above another staff. This was observed directly in the choir and scan overlays. A matching staff count does not prove correct crop boundaries, instrument assignment, system grouping, complete measures, or playable output. The review sheet requires explicit selection and grouping, warns about these limits, and leaves bands editable after applying. Use rectification first for tilted scans; compare the entire page with the proposals; group piano staves explicitly; then resize, preserve shared markings, and inspect the final export.
