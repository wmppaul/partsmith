# Full native corpus regression: connector and staff harmonic fixes

The frozen comparison covers all **36 PDF inputs and 1,477 physical pages**. Only `NativeScorePageAnalyzer.swift` and `StaffBandDetector.swift` were replaced from checkpoint `975ee3d`; both replacement files correspond to candidate checkpoint `627cb04`. Every other Core file and both Swift CLI snapshots remain identical to the baseline. Source PDFs, profiles, corpus, runner and executable hashes were verified.

| Result | Baseline | Candidate |
| --- | ---: | ---: |
| Completed input PDFs / pages |36 /1,477|36 /1,477|
| Full native export sets |16|16|
| Exported parts |77|77|
| Exported pages |597|596|
| Existing unresolved score setups |20|20|
| Native analysis / planning / export errors |0|0|

No score changed extraction status. No new unresolved pages or added/removed planned bands appeared. The runner validated all exported bands, their ordering and source identity, PDF hashes, embedded immutable source, editable-project part order and each saved crop. The single output-page reduction is in the 93521 Quartet.

Staff geometry changes only on independently verified Bohème page 167: three detected half-staves become six complete staves. The other 1,476 pages retain exact staff/image geometry. Component membership or ownership changes on 77 pages; total multi-owner components decrease 1,470→1,421. These component counts are diagnostics, not proof that all resulting crops are musically correct.

Only 14 planned crop geometries change: the 12 previously source-reviewed raw 93521 Quartet bands on pages 6, 28, 31, 33, 37 and the two historical 09200 bands on page 7. All other planned crop geometry and source-marking metadata remain unchanged. See `connector-separation-v8.json` and its independent source reviews for the changed-band preservation evidence.

All 16 native export sets also passed `tools/review_score_output.py` with two parallel workers: **77 parts and all 596 pages rendered**, with every expected page PNG independently confirmed present. The checks passed ordering, source identity, staff containment, preserved aspect ratio and non-overlapping placement geometry. `connector8-harmonic-export-geometry.json` records every PDF and geometry-report hash plus a hash of each set’s rendered PNG names/content hashes. This is automated geometry and render verification; it is separate from the existing independent visual/music review of the 14 changed bands and does not establish that all 596 pages contain the correct music.

## Every page with a component or ownership change

| Corpus input | Pages |
| --- | --- |
| lightly-skewed-01-mozart-piano-quartet-k478-imslp-478563 | 11 |
| lightly-skewed-03-brahms-symphony-no1-op68-imslp-317803 | 2, 54, 79, 80 |
| lightly-skewed-04-schumann-concertpiece-4-horns-op86-imslp-291222 | 54 |
| lightly-skewed-06-puccini-la-boheme-sc67-imslp-885132 | 34, 44, 66, 70, 71, 79, 106, 108, 154, 164, 166, 167, 244 |
| lightly-skewed-08-mendelssohn-hear-my-prayer-woo15-imslp-40163 | 6 |
| lightly-skewed-09-brahms-gesang-der-parzen-op89-imslp-109040 | 10 |
| lightly-skewed-10-brahms-string-quartet-no3-op67-imslp-242312 | 22 |
| medium-skewed-01-mozart-piano-quartet-k478-imslp-86903 | 23 |
| medium-skewed-04-schumann-concertpiece-4-horns-op86-imslp-51506 | 5, 14, 16, 40, 46, 48, 56, 61, 76 |
| medium-skewed-05-brahms-string-quartet-no3-op67-imslp-09200 | 7 |
| medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521 | 6, 24, 28, 31, 33, 37 |
| medium-skewed-08-brahms-gesang-der-parzen-op89-imslp-109041 | 10 |
| medium-skewed-10-schubert-winterreise-d911-imslp-00414 | 11, 30, 64 |
| rest-detection-beethoven-symphony-no5-op67-complete-imslp52624 | 9, 11, 12, 18, 21, 23, 25, 27, 28, 30, 31, 33, 35, 37, 40, 41, 42, 43, 45, 46, 48, 52, 53, 60, 61, 62, 66, 77, 78, 82, 84, 88, 90, 98 |

The JSON companion retains per-page component counts, owner histograms, exact changed staff geometry, all changed crop bounds and per-part output counts. The isolated run lives in `.build/auto-qc/connector8-harmonic`; `snapshot.json`, `comparison.json`, `corpus/aggregate.json`, logs and per-score results preserve the execution trail. One jobs=3 runner completed without restarts after observation timeouts.

This is a successful regression check, not an unattended-extraction quality pass. Twenty existing score setups still need resolution, and partial neighboring notation remains in reviewed outputs.
