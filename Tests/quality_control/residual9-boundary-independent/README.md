# Independent boundary controls and source review

The frozen continuity candidate removes two whole-neighbor crops on Brahms 93521 physical p29 without losing observed target notation. The new 297-case source-mask matrix has no newly failed case or worsened retained target envelope; the frozen 336-case matrix is exactly unchanged. **This is a bounded non-regression result, not a solution to musical-stem ownership.** The baseline's 96 failures in the new matrix and all 336 failures in the earlier matrix remain explicit.

Production was not edited by this review. The candidate analyzer is SHA-256 `e89e43a50394d08271e413e8c9a2da811da61bb7c03889e9edcd0213dea5b9aa`, copied from the parent's scratch snapshot to an immutable independent snapshot. Baseline commit is `e9ef3d1`, analyzer `fc9a15ae4c69b920df829f3e7eb2488d7c209310f995fa60d6df3f58053bdcc2`. The full-corpus run remains parent-owned; its independent audit and scope are recorded below. Any eventual promotion remains parent-owned. The separately frozen deterministic V2 is reviewed below; V1 evidence is retained unchanged.

## Source obligations precede the candidate

`source-guards.json` is a byte-identical copy of all ten existing envelopes, SHA-256 `e097a2b80032e18b85606f4f02c13e24870162857a02bf95f6b58786f2cdbe0c`. It includes the nine affected crops and adjacent p31 Violin I reference. The historical analyzer identifier inside that file is deliberately unchanged. No envelope or acceptance tolerance was relaxed.

The original 39-page PDF is SHA-256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`; corrected source-review PDF is `3012da56d772c79a5d319282667b9bbfa25d1da747d876b37150930fb55ede38`. The latter retains the nine saved corrections on physical pages 2, 7, 17, 19, 23, 28, 34, 38 and 39. P29 itself is uncorrected. `frozen-inputs.json` binds the exact sources, prior fixed controls, guards, and five source contexts before this candidate review.

All five original right-boundary source contexts and the five subsequently identified surviving-link source contexts were viewed. The [independent native-mask audit](../residual9-boundary-source/README.md) corrected an important earlier attribution: p28's right system boundary is already separated successfully; its surviving connection is an **interior barline**. P24 and p28 retain vertical scan gaps within staff cores. P29, p31 and p35 fail the previous all-five-line continuity fit at different positions. These observations do not justify lowering the 88% core gate or treating all five cases as one endpoint failure.

## New controls

`controls.swift` defines eleven source families, each evaluated at raster scales 0.5, 1 and 1.5; global tilts −1.5°, 0° and 1.5°; and right-side displacements −10, 0 and 10 source pixels. This yields 297 cases. Nominal source rasters are under `fixtures/`; all eleven were viewed in `source-fixture-contact.png`.

The source canvas is 720×760, with three staves beginning at y180, 330 and 480, staff spacing12 and a shared right edge x600–602. Independent per-pixel ownership is assigned while drawing each actual note, stem, beam or slur. The same explicit source-column displacement transforms both the source pixels and their ownership masks **before** native raster resampling. Target envelopes are measured from those transformed source masks, never from a returned component or candidate crop. Genuine cross-staff stems conservatively belong to all three staves. Bare staff/bar lines are not musical target pixels.

| Family, 27 cases each | Obligation | Baseline / candidate full-envelope passes |
| --- | --- | ---: |
| Clean structural boundary | Ordinary notes retained while true barline separates | 27 / 27 |
| Horizontal line breaks | Two upper lines and one middle line interrupted near edge | 27 / 27 |
| Interior vertical break | Missing barline rows inside bottom staff, intact outer endpoint | 27 / 27 |
| Parallel structural paths | Interior and right barline paths; cutting one is insufficient | 27 / 27 |
| Full-height edge musical stem | Three-staff musical stem exactly coincides with common edge | 0 / 0 |
| Near-edge musical stem | Same stem inset8 source pixels | 6 / 6 |
| Broken edge musical stem | Scan gap in genuine full-height musical stem | 0 / 0 |
| Notehead at barline junction | Ordinary owned stems share structural pixels and extend into gaps | 24 / 24 |
| Shared stem into gap | Upper-owned note/beam continues down the structural stroke | 27 / 27 |
| Attached slur | Upper-owned slur meets barline deep in the interstaff gap | 27 / 27 |
| Ledger-line aliases | Missing outer lines plus offset ledger pattern near musical stem | 9 / 9 |
| **Total** | | **201 / 201** |

The three notehead-at-junction failures occur at tilt−1.5°/displacement−10 at **all three raster scales**. The middle-part source envelope begins y292; returned crops begin y294, 295 or294.667 and truncate a real source stem. This is not merely a low-resolution limitation. Full case records preserve these failures.

Crop/source containment uses only 1e−9 source-unit numerical tolerance. The comparator additionally checks that each new crop still contains the intersection of the old crop with each frozen source envelope, including cases that already failed full containment. Its 1e−7 coordinate comparison tolerance is numerical roundoff, not a musical margin. Thus unchanged headline pass counts cannot hide additional target loss within an already failed case.

## Candidate result

The candidate keeps a common continuous displacement with five ordered line slots and a separate missing-evidence distance for each slot. All five must be visible at the interior anchor; at least three must have 80% horizontal support at subsequent steps. Missing evidence can be carried for at most four staff spaces. Existing connector width, 88% core, alias-distance and translated-junction checks remain. Missing support is not counted as observed ink. This is a limited continuity change; it does not implement a structural ownership graph.

- New297: same201 full-envelope passes, zero new failures, zero worsened source-envelope intersections. Fourteen cases change, all in the horizontal-line-break family. Whole-neighbor occurrences across the full matrix decrease223→198; all other case outputs are identical.
- Frozen expanded336: every per-case JSON result is **exactly identical** to the previous current-analyzer baseline, including bounds and source envelopes. All336 existing cross-staff preservation failures remain; none is newly concealed or relabeled.
- Parent's native39 comparison: all staff geometry/assignments remain unchanged; only p29s1 Violin I and II crops change among604. All ten frozen guards remain contained. Whole-neighbor occurrences decrease9→7. This result is retained in `corrected-source-comparison.json`; the native run was parent-owned.
- Parent reports all755 existing checks pass. This independent review did not rerun that separate harness or inspect full exported pagination.

The two changed source-coordinate rectangles, in PDF points from the top left, are:

| Part / physical source region | Before | After |
| --- | --- | --- |
| Violin I, p29s1 | [0,18.9035866,427,91.6529117] | [0,18.9035866,427,75.7620517] |
| Violin II, p29s1 | [0,35.2688006,427,110.6270729] | [0,59.2236791,427,110.6270729] |

## Independent p29 notation review

The full original first system was examined before the before/after strips. Both final strips were then checked across the full horizontal span. Violin I retains the complete heading, clef/key/time, notes and beams, staccato dots, slurs, accents, p/pp, hairpins and repeat sign. Violin II retains its full corresponding notation, including the low sharp note and pp at the right. No target notation outside the frozen guards was found. The only newly discarded notation belongs to neighboring parts.

The after strips still contain foreign fragments: the top edge of Violin II remains beneath Violin I, and Violin II still includes Violin I dynamics/tails above and Viola fragments below. This review supports the removal of two **whole** neighboring staves, not a claim of clean isolated engraving. All pixels in these strips come from the original PDF source; no notation was synthesized or cleaned.

Source and all four comparison strips are retained in `source-review/`. Full part export and page-turn layout are outside this bounded review.

## Ownership constraints for further work

1. Trace ordered staff identities from interior evidence. Do not let missing samples become proof of ink or swap an outer staff line for a ledger line. A common shift and indexed slots prevent converging line tracks but do not by themselves prove all ownership relationships.
2. A common edge across three staves is structural evidence, not sufficient permission to cut: the full-height three-staff musical-stem family deliberately shares that geometry.
3. Represent the structural barline separately from attached musical branches and retain dual-use pixels. Independent nonstructural connections can establish a branch's owner. If a musical branch's only anchor passes through ambiguous shared pixels, preserve its full conservative source envelope rather than assigning it to the nearest staff.
4. Compact broken staff fragments are not reliable noteheads. Earlier local attachment vetoes falsely widened hundreds of crops; independent line identity must distinguish those fragments from music.
5. Account for parallel paths and cycles. A successfully cleared right barline does not prove separation when an interior connector survives, as p28 demonstrates.
6. Verify the resulting crop against source notation and frozen source masks, including partially failed baseline cases. A green legacy test suite or ten-envelope containment alone cannot certify all affected pages.

Code review also identified a potential deterministic-choice issue in the candidate: for equal cumulative scores, predecessor dictionary iteration can retain different missing-distance histories at the same displacement. This can affect later reachability. It is a possible false-negative/repeatability issue, not an observed new target omission; it was reported to the parent separately before promotion. The frozen candidate is not edited here. A second fresh-process run of all297 controls produced exactly the same JSON values (`v1-repeatability.json`), so no actual variation was observed in this matrix. The parent is preparing a separate deterministic version; V1 is not a promotion recommendation.

## Reproduction

`run-controls.sh <Core-directory> <result-json>` compiles the minimal six-source analyzer/planner set and runs all297 source-mask fixtures. `compare.py baseline-results.json candidate-results.json comparison.json` reproduces the complete non-regression comparison. `reproduction-sources.zip` preserves baseline and candidate source snapshots, the unchanged expanded336 harness, new fixture source and run logs. `verdict.json` binds the exact code/archive/source-review images. `297-comparison.json`, `336-comparison.json`, both full297 result sets and candidate-expanded336 retain every outcome, including all failures.

## Deterministic V2 verification

The parent supplied a separate V2 snapshot with analyzer SHA-256 `e6541355b65590e66b9f893a12a12f1d66e73f82ebc328436dbb3d52bcd0a353`. Independent diff review confirms that the only change from V1 sorts predecessor shifts and deterministically resolves equal cumulative scores by smallest maximum missing distance, then total missing distance, then lexicographic missing-distance vector. Remaining ties preserve the earlier sorted predecessor. No acceptance guard or evidence budget changes. This resolves the iteration-order concern; it does not claim complete exploration of every possible trace history.

V2 was compiled against its own immutable six-source snapshot. All297 and all336 source controls ran **twice in separate processes**, all exits0. Every result value, including all returned crop coordinates, is exactly equal to V1 and between both V2 processes. Thus V2 retains the same201/297 passes, all336 historical failures, zero new failures and zero worsened partially retained target envelopes. `candidate-v2/` contains both full runs, baseline comparison, source hashes and an exact source/log archive.

The completed parent-owned V2 native39 output was then independently compared to V1. The entire plan JSON is exactly identical (all604 crops/assignments), as are original source path/hash and all nine saved corrections. Twelve page arrays differ only in ordering of tied ink components; sorted component signatures are identical and every other page field is exact. P29's full page object is exact. `candidate-v2/native39-equivalence.json` binds both actual-result hashes and these checks. The p29 source-first visual review therefore applies unchanged to V2. The later full-corpus audit below completes the additional non-regression check; complete PDF pagination review remains outside this subtask.

## Full 36-input audit, including unresolved plans

The completed baseline/V1 and V1/V2 inventories were independently re-read with `audit-corpus.py`. This does not reuse the parent's crop comparator. It validates all 36 current PDF/profile hashes, source manifests, executable hashes, terminal exit0 records and inventory hashes. It checks exact ordered analysis and plan page coverage, rejects duplicate band/staff IDs, validates each assigned staff ID and part reference, compares every plan field recursively, and compares ink-component **multisets**, not their incidental array order. The roster equals every PDF under `sample_scores` and `Tests/extraction/sources`.

All1477 analyzed pages and all6936 proposed bands retain their coverage. Assignment identity, ordering, candidate staff IDs, omissions, unresolved reasons, plan/page warnings and all other plan metadata remain exact except the two already-reviewed p29 crop edges and their two band-level warning removals. Specifically, the warning that a component still touches a neighboring staff disappears on those same two rows; their remaining caution messages are unchanged. There are no additional hidden band-field changes. Source page geometry and all other analysis-page fields are unchanged.

The parent's352 V1 “ink changed pages” include343 pages whose components differ only in ordering. Only **nine pages have different component contents**. V2 is semantically identical to V1 on every page and has exactly the same complete plan payloads; its363 V1→V2 raw component-array differences are entirely order-only. These comparisons and every input binding are retained in `corpus-v1-independent.json` and `candidate-v2/corpus-v1-equivalence.json`.

Coverage must not be mistaken for complete music extraction:

- Seventeen inputs produce6936 bands on490 pages.
- Nineteen variable-layout profiles, totaling976 pages, deliberately produce **zero bands** and retain their unresolved assignment reasons.
- Eleven additional pages in fixed-layout profiles also retain unresolved reasons. Their blank/title/count-mismatch explanations were not individually reclassified in this audit.
- Thus987 pages carry unresolved reasons; all23801 detected staves and the baseline15712 unassigned staves retain the same coverage state. No missing instruments or rests were silently invented.

Eight of the nine semantic component changes occur in those unresolved variable-layout inputs. An unchanged empty plan alone would not validate them. The original full-width source contexts were examined first, including all branches connected to the changed regions. Then a diagnostic profile assigned one neutral row per observed staff, without inferring an instrument name or system layout. This yielded15 changed staff crops across seven unresolved pages; the eighth page's diagnostic crops remained exact. **All15 before/after source strips were visually inspected. No newly lost target notation was found.** These diagnostics were never substituted into user projects or delivered as complete parts.

| Input / physical page | Changed source connection and independent finding |
| --- | --- |
| Schumann Concertpiece51506, p23 | Right boundary splits observed rows0/1. High and ledger notes, slurs, beams, sf/ff and rehearsal F remain. The upper diagnostic crop also gains space above. |
| Schumann51506, p32 | Right double boundary separates observed rows17/18. Notes, fermatas and printed3/4 changes remain. The upper row's Solo label grazes its unchanged top in both versions, an existing limitation. |
| Beethoven52624, p40 | Structural connection between resting upper rows. Clefs, key signatures and every visible bar rest remain. |
| Beethoven52624, p47 | Structural connection between upper rows. High notes, ledger lines, accidentals, dynamic and printed ending brackets remain; the upper edge is unchanged. |
| Beethoven52624, p52 | An unowned isolated segment is a broken interior barline in the source. Both resting staff crops remain complete despite smaller edges. |
| Beethoven52624, p55 | Structural connection between resting rows. Clefs, key signatures, staff cores and bar rests remain. |
| Beethoven52624, p66 | Three-staff component becomes upper row plus lower pair. All three diagnostic rows retain their own notes, ledger lines, slurs/ties and dynamics. The lower pair remains broadly shared, with substantial foreign notation. |
| Beethoven52624, p71 | A printed a2 and slur touch the broken right boundary. Analysis tail fragments change, but **every diagnostic crop is identical**. Original-source output still contains the a2, complete slur and notes. This is not a claim that the analyzer independently classifies every attached slur pixel. |

The ninth region is Brahms93521 p29, already reviewed against its two intended parts and immutable source guards. The exact same nine semantic regions occur in V2, so no additional source regions were omitted from review. The actual raw-corpus whole-neighbor count is93→91 among emitted bands; the corrected39-page Brahms experiment's9→7 is a separate measure. Neither count describes the zero-band variable scores.

The full-corpus non-regression gate therefore supports this bounded continuity change. It does **not** establish musical completeness for 36 scores, solve variable instrument assignments, validate arbitrary future manual groupings, or fix the existing 96/297 and336/336 synthetic ownership failures. No production source, extraction inputs or original source guards were changed by this audit.

`corpus-source-review/` retains original contexts, enlarged p52/p71 structural/slur details, all17 before/after diagnostic crop pairs including the two Brahms rows, full hypothetical plans, exact source-coordinate strip rectangles, per-region findings, and archived original/both-candidate page analyses. `provenance.json` binds all of these artifacts. The reviewed source images preserve original source pixels; they are not cleaned or re-engraved notation.


## Packaged app identity

The current continuation ZIP was independently verified against its completed Release product, build log, all34 recorded production sources and all23 files of the frozen combined Core. Exactly two production source hashes differ from the preceding heading-block build: `NativeScorePageAnalyzer.swift` and `ScoreSharedHeadingDetector.swift`. The ZIP passes CRC validation; its executable matches both the declared hash and the completed build product. Both x86_64 and arm64 Mach-O slices require macOS14.0, matching the bundle plist. The log contains a successful universal Release build.

`release-identity.json` records the exact checks and tool output; `verify-release.py` reproduces them without rebuilding or launching the app. Archive SHA-256 is `93563a97b8559f72a37d840617500186b35273d711b1dcfa8543b2809aebb440`; executable SHA-256 is `5c28a3e2aa9e9d282d925c7213fdfe1294cbbb56a433b0de5fd94ae42cc9efd5`. The executable has only the linker's ad-hoc signature, no developer team or sealed resources. This is not a public-signing or notarization check.

The parent completed the separate PDF-output review and finalized the build record. The final identity check was rerun: all package/source checks still pass, and the stable identity projection is exactly equal to the pre-finalization record. The final full build-record hash is bound in `release-identity.json`. PDF-quality statements in that build record retain their separate parent-owned review scope; this package check does not independently repeat them. No running user app or user document was opened or changed for this check.
