# Staff recall validation, 2026-09-20

Two source-verified misses are repaired without using instrument counts or an extraction profile:

| Source | PDF page | Missing physical staff | Before / after |
| --- | ---: | --- | ---: |
| Medium Mozart K478, IMSLP86903 | 25 | First system Violin | 19 / 20 |
| Medium Schumann Frauenliebe, IMSLP51733 | 14 | Last system lower piano | 14 / 15 |

The Mozart system has a different tilt from the page-wide estimate. The new fallback requires complete five-line patterns in both outer windows and independent evidence for every interpolated line in the middle window. It preserves the estimated page-center coordinates.

The Schumann passage has repeated beams joining two staff-line peaks into a broad ink plateau. Splitting those peaks is confined to a fallback requiring a complete ordinary clef-margin pattern, a complete ordinary wide-window pattern, and at least three ordinary full-width peaks. The clef margin and the left wide window partly overlap; the global evidence is an additional guard. Primary detections and the coordinates of existing staves remain unchanged.

An earlier unrestricted peak-splitting prototype falsely found two staves on the Brahms IMSLP93521 title page. It was rejected. The final fallback finds zero there and on the real quartet catalogue, Frauenliebe cover/blank, and Winterreise cover/blank used as negatives.

## Evidence

- Every source and every physical page in the corpus was processed: **36 PDFs, 1,477 pages**.
- Against candidate1, exactly **two added staves** are found, at the source locations above. **No other additions, no removals of previously detected staves, and no changes to previously detected five-line coordinates** occurred.
- Source hashes, full page counts and complete page-index coverage were checked for each input. The detector source and compiled executable are hash-bound in the reports.
- `tools/test_staff_recall.sh` checks all five target line coordinates against independently inspected source positions, not just total counts. The source position tolerance is three pixels at the native 1,800-pixel-wide render.
- The new harness also checks differing local tilts/curves, short beam/ledger artifacts, disconnected short fragments and text, incomplete four-line rows, flat saturated blocks, cancellation, and six real nonmusic pages.
- The existing staff synthetic/document tests and all **19** existing sample-page cases pass. They were compiled with all Core sources because the older `tools/test_staff_detection.sh` source list omits dependencies now used by `PartsmithDocument`.
- A separate read-only agent review found no concrete blocker in the fallback gates.

The committed summary is `staff-recall-validation.json`. The detailed frozen run is `.build/auto-qc/staff-recall-v2/aggregate.json`; its hash is in the summary. The frozen executable and detector source are beside that report.

## Reproduction

The focused regression is:

```sh
bash tools/test_staff_recall.sh
```

For a complete detector-only comparison against existing inventories:

```sh
.build/test_staff_recall \
  --corpus Tests/quality_control/corpus.json \
  --baseline .build/auto-qc/candidate/all-samples \
  --out .build/staff-recall-corpus.json
```

For parallel runs, freeze the compiled executable and detector source first, then use `--offset 0 --stride 3`, `--offset 1 --stride 3`, and `--offset 2 --stride 3` with three different output paths. Pass the frozen source as `--detector-source PATH`. Reports are saved atomically after each source; source failures are recorded and do not silently remove that source from the report.

This is raw-source staff geometry evidence. It does not establish instrument identity, final crop/notation preservation, omitted silent bars, shared directions, pagination, or the optional rectified workflow. The recovered Mozart staff still needs crop review because notation-component analysis uses a page-wide angle; the real short piano ossia on Mozart page 1 also remains a separate preservation requirement.
