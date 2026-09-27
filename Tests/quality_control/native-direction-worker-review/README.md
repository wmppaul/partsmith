# Native direction worker verification

Review and continuation: 2026-09-27. The three completed recognition inventories are from 2026-09-24; cancellation and save/reopen/export verification were performed on 2026-09-27. This is a native app-model/production-export regression check, not a fresh certificate of every musical detail or a live SwiftUI inspection.

The real `PartsmithDocument.detectScore(copySharedDirections: true)` worker completed all selected pages of three immutable scores. It used native PDFKit, Vision and saved perspective corrections, with no injected recognizer. No production files were changed for this review. The tested frozen Core files exactly matched the current Core files when checked; hashes are in `provenance.json`.

| Score | Source pages | Parts | Main crops | Copied directions | Export pages |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ave verum | 4 | 8 | 64 | 7 | 8 |
| Mozart K.498 | 29 | 3 | 405 | 8 | 39 |
| Brahms Op.67, IMSLP 93521 | 39 | 4 | 604 | 27 | 64 |
| Total | 72 | 15 | 1,073 | 42 | 111 |

The entire Brahms source was analyzed. Its first, nonmusic page was automatically excluded from crop planning; the resulting review remained acceptable without a manual blank-page gate. The nine saved corrections are unchanged, on one-based pages 2, 7, 17, 19, 23, 28, 34, 38 and 39. No correction was re-estimated.

## Native recognition and progress

Compared with the matching native CLI heading/navigation/destination baseline:

- Every band ID, intended staff assignment, main crop boundary and copied-direction rectangle is identical.
- All 12 heading records and both Brahms navigation records are identical. The latter include the printed repeat destination linked from source page 28 to page 26.
- Staff detections and page dimensions are identical. Ink-component inventories differ on one K.498 page and 13 Brahms pages; these differences do not alter any crop, assignment, heading or copy.
- All three reviews have `canApply == true`, zero direction issues, unchanged source/project data before acceptance, and cleared progress after completion.
- Every observed progress publication and completion callback runs on the main thread. The production source dispatches detection and recognition through its worker operation queue; the test does not replace the worker runner.

Ave completed in 4.42 seconds and K.498 in 37.51 seconds. Their 50 ms main-run-loop heartbeat had maximum observed intervals of 53.5 ms and 63.5 ms, respectively. The first Brahms run took 628.90 wall-clock seconds and contains large simultaneous progress/heartbeat gaps (maximum 318.61 seconds). That run alone is **not evidence of responsive Brahms processing**; machine sleep/suspension was not instrumented, and the gap's cause is not proven. A separately instrumented repeat resolves the current performance check below; the old run’s cause remains unproven.

`comparison.json` preserves complete phase progress and the metadata comparison. `worker.log` is the original completed run, retained rather than overwritten.

The 2026-09-27 repeat used `caffeinate -i` for the process lifetime and recorded both `CLOCK_UPTIME_RAW` and `CLOCK_MONOTONIC_RAW`. It completed all 39 Brahms pages and all direction phases in **63.02 seconds on both raw clocks**. Its 50 ms main-loop heartbeat had a maximum raw-uptime interval of **78.2 ms** across 1,260 ticks. Every callback remained on the main thread, the review had zero issues, and project/source data were unchanged. All 604 main bands and 27 copies were exactly identical to the first run's plan, including the linked destination. Six pages have different ink-component inventories, with no changes to staves or recognized metadata.

The repeat's `Date` elapsed measurement was 64.73 seconds and its largest `Date` heartbeat interval was 1.763 seconds, despite a 78.2 ms raw-clock maximum. This demonstrates why the old wall-clock-only gaps are insufficient to diagnose a UI stall. The report does not attribute those older gaps to a proven cause. See `brahms-awake-summary.json`, `brahms-awake-comparison.json` and `brahms-awake.log`.

## Real cancellation and replacement

A further native corrected-Brahms run was cancelled after the first heading page completed:

- `cancelScoreDetection()` returned in 0.000014 seconds and cleared progress synchronously.
- A new request for original source page index 1, with direction copying disabled, completed in 0.191 seconds and returned exactly that page's 12 bands.
- No cancelled completion callback and no stale direction progress appeared.
- Source and project data stayed unchanged.

See `brahms-cancel.json` and `cancel.log`. This is one real-recognizer cancellation point; the separate injected app suite covers all four direction phases, replacements and stale-state cases.

## Apply, save, reopen and export

The recorded worker analyses were passed through `ScoreDetectionReview.initial`, the actual `addScoreParts` transaction, the project's ISO-8601 Codable package schema, disk save, disk read/decode, and a new `PartsmithDocument`. Re-encoded saved JSON was byte-identical and every embedded `source.pdf` retained its exact source SHA-256. The reopened document retained the profile, all saved corrections, all bands and all copied markings.

Every part was then exported through the production `PartLayoutEngine` and `PartPDFExporter`. All 111 pages are pixel-identical at 150 DPI grayscale to the matching CLI baseline, with identical main/copy placement geometry. No output page is blank and no music/copy rectangle extends beyond its output page. All source bands remain in order. PDF and project hashes plus per-page raster hashes are in `export-comparison.json`.

The export harness uses the same JSON package schema as the app, rather than opening a SwiftUI `FileDocument` file panel. This verifies serialization and reopened document/export behavior; it does not claim a live UI save/open interaction. Matching baseline title/composer settings are used solely for a meaningful exact rendering comparison. These scratch regression exports are not replacements for the separately reviewed deliverables.

## Limits

- This proves that integrating the existing native direction detectors into the document worker preserves their tested output. It does not prove all directions in arbitrary scores are detected.
- The current app worker does not include the separate experimental paired-ending detector. Those brackets are intentionally absent from both sides of this comparison.
- Known large neighboring-staff spillovers and still-unhandled shared directions in the baseline remain outstanding; identical pixels do not make those defects acceptable.
- Full fixed instrument profiles were initialized from the existing corpus profiles. This does not retest instrument-name OCR, changing orchestration, automatic source headers or automatic rest compression.
- This run exercises app model/worker/production export code, not the packaged window UI.

## Reproduction

`native_worker.swift`, `export_reopened.swift`, `compare.py`, `compare_exports.py` and `config.json` are the exact harnesses/settings. Large inventories, plans, binaries and regression PDFs remain under `.build/qc-native-app-worker-v1`; their hashes and source paths are recorded. Compile each Swift entry point with the Core `DocumentModel`, `Detection`, `Layout` and `Export` Swift files and macOS SDK, using the frozen source hashes. Native Vision checks require normal Mac access; sandboxed Vision failures are not musical detection results.
