# Low-resolution staff-line erasure audit

2026-10-03. Independent scratch investigation, followed by promotion of the bounded fix after review. The production analyzer matches the fully tested scratch candidate except for explanatory comments. Only the minimum erasure thickness changed; the production regression loop gained three additional raster scales and now passes all **755 checks**. Earlier controls and source-envelope oracles are unchanged. Current source and binary hashes are in `production-promotion.json`.

## Finding and bounded candidate

The 103 previously recorded source-envelope failures at 3, 3.6, and 4.8 raster pixels per staff space are genuine crop omissions. Every failing crop clips foreground ink in the actual resampled source mask as well as the exact original source envelope. They are not merely high-resolution oracle differences. Instrumenting the staff eraser and connector separator independently shows that all lost target pixels disappear in staff-line erasure; connector separation loses none of these target pixels.

The original eraser used `max(1, round(0.09 * staffSpace))` as its half-thickness. Its minimum deleted three complete raster rows around each predicted staff line. At three-pixel staff spacing, that is an entire staff space. It can remove the notehead's attachment and lower endpoint while retaining enough stem evidence to plan a crop that ends above the original notehead.

The scratch candidate changes only the minimum half-thickness to zero. It deletes one row when `round(0.09 * staffSpace) == 0`, exactly positive staff spacings below 5.555… raster pixels. At greater spacings, both code paths are identical. The existing stem-crossing exception then checks the immediately adjacent rows rather than rows two pixels away in these small staves. No source/export pixels are erased by either implementation: this fixes the analysis evidence used to choose original-source crop bounds.

## Independent source preservation

`fixtures.swift` keeps the original source musical pixels as the oracle. The source stem and both noteheads are transformed by the fixture's explicit skew and bend. No expected extent comes from detector components or planned crops. All envelope checks are exact, with no tolerance.

| Result over 588 fixtures | Baseline | One-row candidate |
| --- | ---: | ---: |
| Cases with incomplete target source envelopes | 103 | 0 |
| Maximum original-source shortfall | 8 points | 0 |
| Musical connector cuts | 0 | 0 |
| Low-resolution cases without a shared endpoint component | 168 | 0 |
| Changed principal cases at spacing ≥ 6 pixels | — | 0 |

All 1,176 candidate target crops retain their entire independent source envelopes. There are 230 changed low-resolution fixture plans; the 336 principal fixtures are unchanged. Before the additional low-resolution cases were added, the unchanged production crop suite passed all 503 checks with the candidate, including positive structural-connector separation. The promoted suite now passes 755 checks; this adds the 252 low-resolution source-envelope cases without modifying earlier predicates.

A diagnostic ablation that disables staff-line erasure also repairs all 103 omissions, supporting the stage attribution. It is not proposed for production because retaining all staff lines is unsuitable for compact part crops.

The example `source.png` / `low.png` is scale 0.25, tilt −1.5°, bend −6 points. Its source lower notehead reaches y=379 points. The original upper-part crop stops at y=374; the candidate reaches y=386 and retains the complete notehead. Both images were written directly by the native fixture renderer.

## Remaining low-resolution limitations

Additional controls extended existing brace, barline and musical-bridge tests down to 3–4.8 pixel staff spacing. These are diagnostic controls, **not a claim that all 419 pass**. The baseline fails 154 checks and the candidate fails 10.

Six remaining failures are inherited 3-pixel brace/neighbor-staff contamination defects. Four newly failing predicates require a musical component to begin to the right of the page midpoint; the candidate retains staff fragments attached to two narrow bridges and two harmonic figures at 3.6/4.8 pixels, so those components now extend left. The independent source envelopes of all four figures are still inside both target crops (eight checks pass, in `positive-low-regression-check.json`). These are component/contamination precision limitations and are recorded rather than suppressing or weakening the original predicates. This bounded change prioritizes preserving target notes and does not claim perfect low-resolution staff separation.

## Corpus comparison and reproduction

The completed comparison covers **36 PDFs and 1,477 pages**. It finds **zero changed, added, or removed crops**, zero staff/raster geometry changes, and one page with changed analysis components. That page is Beethoven’s decorative cover (`beethoven-cover.png`), where six ornament/text false-positive staff proposals have spacing below 5.56 pixels; the minimum is 3.4864 pixels. The cover has no part assignments in either version. All 23,801 detected staff proposals in the corpus were considered. No actual musical staff in this corpus exercises the new minimum, so the real low-resolution preservation evidence comes from the independent fixture suite, not this corpus no-regression result. The remaining Brahms crop issues are unaffected by this bounded fix.

The full original-source corpus comparison uses independently compiled, frozen current-production and candidate binaries. Each run verifies the exact PDF and profile hashes before analysis. `corpus-comparison.json` records page, component, assignment and crop differences; both run-status records include terminal status and binary hashes. No output equality claim should be inferred from the synthetic tests alone.

Scratch binaries and complete component measurements are in `.build/qc-low-resolution-preservation`. The retained fixture, instrumented analyzer copies, source masks, per-case measurements, and source/binary hashes reproduce the stage attribution and source-envelope checks. Use the frozen staff detector and planner identified by `provenance.json` alongside `baseline.swift` or `single-row.swift` and `fixtures.swift`. The entire corpus scripts and the four additional source-envelope checks are retained here too.
