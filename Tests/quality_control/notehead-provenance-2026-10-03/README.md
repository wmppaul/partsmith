# Notehead-to-stem provenance prototype — rejected on real source

**V1 is rejected and was never promoted.** The frozen candidate repairs 49 cases in unchanged synthetic source-mask controls, but the independently chosen real-score controls recognize none of seven genuine heads and falsely accept a tie/staff-line enclosure as a hollow notehead. A separate native replay adds whole neighboring staff cores to four diagnostic crops because thick or displaced staff-line ink is mistaken for a filled head. No production file, planner rule, source mask or acceptance oracle was changed.

Baseline: `77f409a2d40639012918c9843895c557ba4f8a71`. Its analyzer is unchanged from the preceding `d2a43e1` study. Candidate analyzer: `8c2fa3f665dd1c41f95ac44b9f30fc0a6cdc094f5cac016cd866711badd41af3`. The two 23-file Core snapshots are archived in `frozen-core.zip`; only `NativeScorePageAnalyzer.swift` differs. The initial design and fit tolerances were frozen before any candidate results in `design-before-results.md`. No thresholds were adjusted to these real holdouts.

## Proposed evidence and implementation

The candidate supplements the existing preservation witness. It searches for a compact inclined oval on the conventional side of the **specific physical spine**, with its center constrained by body-to-spine contact. A fit must have ink in all four outline quadrants, a filled interior or an actually enclosed original white cavity, surrounding white paper, direct original ink rows into that same spine, inward stem continuation, and no sustained outward continuation beyond the body. A tie is allowed to cross part of the surrounding annulus; its full connected extent is not treated as the head's extent.

All measurements use the original native thresholded source. Predicted staff rows and the physical spine are excluded from positive oval sampling; predicted staff rows are also excluded from the paper test and direct attachment. The old witness and its uncertainties remain intact. The existing outward-only ownership-alternative model and all planner semantics are byte-identical to baseline.

`candidate-v1.patch` is the complete code change. `sourceNoteheadEndpoint` returns the fitted center, radii, angle, filled/hollow interpretation, attachment-row count and support measurements. A pre-test code audit corrected a cavity flood that could reuse a partially visited escaping white component; its initial unused binary/build log are retained in scratch. The tested candidate finishes each white component and uses the original design thresholds. This was done before observing any candidate outputs and is recorded in `candidate-v1-binding.json`.

## Fixed source controls

| Control | Baseline | Candidate | Result |
|---|---:|---:|---|
| Current permanent crop checks | Existing checkpoint | 765/765 pass | The printed third-annotation limit remains explicit. |
| Earlier 297 source cases | 238 pass / 59 fail | 238 pass / 59 fail | Every decoded result is exactly equal, including crop bounds. |
| Expanded 336 cases | 336/336 pass | 336/336 pass | Every decoded result exactly equal. |
| Independent terminal-body 180 cases | 58 failures | 24 failures | 34 repairs, no new failing cases or worsened owner envelopes. |
| Independent tied-head supplement 36 cases | 24 failures | 9 failures | 15 repairs, no new failing cases or worsened owner envelopes. |
| Pure structural cases within the 180 | 72 | 72 | All retain their target music; none gains a whole neighbor. |

Every independent source PNG and owner mask is unchanged. The parent independently recomputed **432 owner observations from 216 source/mask files**; every claimed pixel count, envelope and loss matches. Its script and complete result are copied unchanged into `independent-evidence/`. The fixed-source comparison files retain exact case identities and source hashes.

The 24 remaining 180-case failures comprise eighteen interrupted-stem cases and six half-resolution hollow cases. The nine tied-supplement failures comprise seven filled-lower-tie cases and two half-resolution hollow cases. Rejection or missed recognition remains uncertainty; it is not proof that the source contains no musical body. The earlier permanent known limit—detached annotation `[610,295,620,304]` remains outside the upper crop—is neither removed nor counted as a successful guard.

`fixed-source-review/` contains five source-defined before/after panels: one repaired filled head, one repaired hollow head, one repaired tied head, one unresolved interrupted stem, and one unresolved half-resolution hollow head. Blue pixels are immutable owned source pixels, red pixels are outside the crop, and green lines are crop boundaries. Pixel counts are asserted against the test JSON when rendering. Parent independently inspected all five panels. These artificial long-stem cases intentionally share a musical envelope across physical staves; their enlarged crops are conservative preservation, not proof that ordinary independent instrument parts should share a staff.

## Independent real-score failure

The independently authored [real-source study](../notehead-provenance-independent-2026-10-03/README.md) froze 22 cases before viewing this prototype: seven genuine own-stem heads, two deliberate wrong associations with a neighboring barline, and thirteen earlier structural false witnesses. Its unchanged holdout SHA is `f9ae21baf633a86a217d260c54db97751a88f4984f76f5f17fa2836e69186a2c`.

- Genuine heads: **0/7 recognized**, including **0/4** inside the declared vertical search window. Three out-of-window examples are explicitly limited coverage, not successful native cases.
- Four in-window positives retested with independently source-measured local staff centers: **0/4 recognized**. This input-fidelity follow-up was prepared after primary results and is not represented as a blind holdout.
- Wrong nearby-barline associations: both return no witness.
- Structural intersections: **1/13 false acceptance**, F05 on Brahms Symphony IMSLP317803 p28. The purported hollow oval, center `(864.0231,1345.1257)`, encloses a light pocket bounded by a tie, staff line and barline; it is not a notehead.

These are direct helper checks, not complete native connector-erasure tests. No confirmed real musical spine crossing two full staff cores was found in those source contexts. That coverage gap remains open. A false F05 helper classification is not excused by an unchanged output crop: the old witness already preserves an alternative there. The independent report and its complete 74-file manifest are hash-bound by `evidence-bindings.json`.

## Native replay: actual effects and source review

After all fixed suites passed, the frozen candidate replayed twelve previously bound native pages with cached staff geometry, then replanned them. Eleven pages use **unnamed one-part-per-physical-staff diagnostics on unresolved variable-layout scores**. Corrected Brahms93521 p38 uses the existing quartet profile and exact saved rectified raster. This is not a fresh full-document staff/instrument detection run.

Three pages gain four typed ownership alternatives. No ordinary or previous alternative component is removed. Exactly four crop rows change, all strict source-rectangle supersets:

| Unresolved neutral row | Edge before → after, fraction of original page | Extra whole neighboring core |
|---|---|---|
| Schumann51506 p3 staff0 | bottom `.2270213361 → .2585339412` | staff1 |
| Schumann51506 p3 staff1 | top `.1876472178 → .1561346128` | staff0 |
| Schumann51506 p63 staff17 | bottom `.9039150984 → .9236629976` | staff18 |
| Schumann51506 p63 staff18 | top `.8782448025 → .8412700125` | staff17 |

These are **four newly contaminated diagnostic rows, not initialized instrument parts or four repaired musical passages**. The source p3 labels identify Kleine Flöte and Grosse Flöten, but the diagnostic does not solve the score's instrument assignment. All previous source crop area remains present; this does not certify that the original crops contained every intended marking.

Logging-only diagnostics reproduce the exact candidate component multisets on all three changed pages. Source/fit closeups show that the new p3 fits at approximately `(1289.13,416.06)` and `(1465.13,416.06)`, and the p63 fit at `(1236.74,2190.56)`, lie on **horizontal staff-line ink adjoining barlines**, not on a genuine notehead's own stem. A fixed ±1-row exclusion around the predicted staff center leaves actual thick or displaced line ink available as apparent outline, interior and attachment. The intended “non-staff” evidence requirement therefore is not established from source provenance.

Beethoven52624 p32 gains two single-owner alternatives, with **no changed crop**. Its new fitted oval does cover a genuine filled head attached to the shown vertical stroke, but this incidental source fit is not one of the frozen seven positives and does not prove musical ownership across two complete staff cores. Corrected Brahms p38 and the other nine page plans are exact. The four changed neutral crop panels, two full source contexts and four exact witness closeups are in `real-source-review/`. All were visually inspected. `component-comparison.json` and `targeted-plan-comparison.json` retain every identity and exact coordinate.

No full39 worker, full1,477-page corpus run, export, pagination change or production promotion followed these real-source failures. The experiment was stopped as rejected rather than tuned to the 22 cases.

## Runtime and what remains unresolved

The 180-case run took 1.55 seconds wall / 1.22 seconds user CPU, versus baseline 1.24 / 1.15 seconds. The tied36 candidate took 0.48 / 0.27 seconds; twelve-page native replay took 4.46 / 4.00 seconds. These are single observations with other build activity, not a production benchmark. The first timing wrapper's optional kernel-clock query was denied after completion, returning wrapper exit1; successful complete output and the timing prefix are retained. Later portable timing avoids that query. This wrapper limitation is separate from the actual source-recognition failures.

The proposed compact shape can help independent synthetic preservation cases, but it does not yet establish real source identity. Reliable evidence must distinguish actual horizontal staff continuation from a body outline, distinguish a tie/staff pocket from a hollow head, and retain true heads despite ties and scan damage. Original source masks, source-defined real holdouts, the no-new-or-worsened-loss rule, and outward-only planner semantics remain requirements. No new heuristic is claimed from this failed study.

## Reproduction and bindings

`evidence-bindings.json` binds frozen Core, candidate binaries, original PDFs/rasters, independent reports and losslessly compressed JSON. `report-hashes.json` binds the durable report. Large PDFs, native rasters and binaries remain at their recorded paths; detailed comparisons, source review panels, code and results are archived here. The prior terminal-body report retains the exact corrected p38 source raster.

From the repository root, with Xcode:

```sh
bash Tests/quality_control/notehead-provenance-2026-10-03/reproduction/reproduce.sh .build/notehead-reproduction-new
```

The script extracts the frozen candidate into a new directory, runs the fixed 180/36/765/297/336 suites, and performs the twelve-page component replay/replanning. It does not use current production Core or run the rejected candidate across the corpus. The script is syntax-checked; individual build/run commands produced the archived evidence. Independent helper probes remain runnable from their separate source-bound report. Logging-only source-witness instrumentation, rendering scripts and the parent mask checker are included for inspection.
