# Source-body provenance V2 — bounded experiment, not promoted

The source-derived contour experiment recognizes two genuine development noteheads that V1 missed and rejects the 15 old wrong-association/structural negatives. It improves five frozen synthetic cases without new loss. It does **not change any of the 254 planned crops across the 12 real pages replayed**. This is partial evidence for a positive musical witness, not a demonstrated improvement to real Auto output. Production was not edited, and no full-score or full-corpus run was requested for this candidate.

The design and first candidate were frozen before fresh independent holdouts were inspected. That fresh review is pending at this checkpoint; the prior 22 real examples are development data, not independent evaluation of V2. Candidate Native SHA256 is `2a76c26e292b1ba4baeb74d7388cb2172a5be41025d58de04efbef986da607db`. The frozen baseline is commit `8571acd5d0367a0c011212b7ce577e9b49e25408`, Native `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`, planner `0cfd6f6fdb1b926a16c4984f63a6d0a4fdf0261878875508916c646a739784b2`.

## Why V1 failed, and the bounded change

Logging the unchanged V1 gates reproduced the four real in-search failures. P01's surviving hollow fit had 13 dark samples in an 18-pixel interior, so it was neither filled nor sufficiently light. P02's deepest fit sat above the true hollow body and failed surrounding paper. P03/P05 did not survive the outline/physical-spine gates; their observed contours did not match the fixed angle/extent family. The precise split between an actual tied extension and body-extent error in every rejected template is not independently proven. The V1 false F05 fit accepted a seven-sample cavity (five light pixels) made by a staff/tie/barline intersection. Full per-template traces, summaries and the original logging-only source are retained.

V2 replaces the new V1 helper, not the existing production preservation witness. It measures sustained original horizontal runs in both flanks of the tested spine and uses their row thickness as occlusion evidence. It proposes filled bodies from original interior maxima and hollow bodies from original enclosed white components. Thirty-two radial traces supply actual nonstaff contours; a least-squares conic derives inclination and extent. A compact ellipse must have supported quadrants, limited residual, surrounding paper, a genuine interior/cavity and an unbroken attachment on at least two nonstaff rows to the exact tested spine. A staff line cannot supply the missing wall of a hollow head. Physical stem continuation is measured after fitting body extent.

The prior terminal-body witness, structural gates, typed outward-only ownership alternatives and planner behavior remain unchanged. Failure of this new helper means uncertainty, not permission to trim. One candidate was tested; no thresholds, masks, crops, fixtures or oracles were adjusted after results. The first build failed on Swift unary-minus spacing; that syntax-only failure and corrected build log are retained.

## Fixed source-mask results

| Check | Production baseline | V2 | New/worsened source loss |
|---|---:|---:|---:|
| Crop-quality checks | 765 pass | 765 pass | None |
| 297 independent cases | 238 pass, 59 fail | Exact same JSON | None |
| 336 expanded musical cases | 336 pass | Exact same JSON | None |
| 180 source controls | 58 failures | 55 failures | None |
| 36 tied-head controls | 24 failures | 22 failures | None |
| 72 pure structural cases within 180 | No whole-neighbor additions | Same | None |

The 765 suite still prints its preexisting three-row-gap detached-annotation limit. Neither that known limit nor the 59 failed 297-case envelopes is relabeled as passing. The 180/36 comparison scripts verify all original source/mask PNG hashes, owner envelopes, pixel counts and case identities. Repairs are `filledOuter-rotated-r0.5`, `mixedOuter-rotated-r0.5`, `hollowFirstSpace-rotated-r1.5`, `filledIncomingTie-rotated-r0.5`, and `filledOutgoingTie-rotated-r0.5`. The remaining 55 + 22 failures remain explicit. V2's synthetic recall is substantially lower than rejected V1's; V1's higher recall did not justify its real false positives.

## Development source review and limits

Direct helper results are 2/7 own-stem positives, 0/2 wrong-barline associations accepted and 0/13 structural witnesses accepted. P03 (filled tied bottom-line head) and P05 (filled head beside a separate barline) are true musical bodies attached to the tested physical stems. The two context panels show untouched native source beside the fitted ellipse and exact spine. P03 follows the inclined head closely; P05 is a coarse silhouette and includes uncertainty around its staff intersection. Both were visually checked. Neither result proves that this ordinary note stem enters the full two-staff structural-removal path.

Both hollow heads remain unrecognized. The local-line retry also exposes initialization sensitivity: P03 succeeds with the original input but fails with independently measured input lines. Independent flank peak selection then chooses a stronger neighboring line for the bottom-line estimate (367.68 instead of 371.26 native pixels), and the ordered-spacing guard refuses the whole witness before body proposals. P01 has the analogous local-input refusal. P02's original input also yields inconsistent line spacing; its local-input retry reaches contour fitting but still does not accept a head. P05 produces identical measured line geometry and succeeds under both inputs. Thus source-supported horizontal thickness is useful but independent peak selection does not yet establish invariant five-line identity. No corrective tuning was made in this study.

## Twelve real-page replays

Fresh baseline and V2 workers used the same frozen detected staff geometry, original PDF bytes and original native rasters. Corrected Brahms93521 p38 used the saved rectified raster, never corrected coordinates on the raw PDF. Both match every frozen component multiset. Equal-bounds component order differs on some pages, so complete plans were explicitly recalculated: all 12 plans and 254 assignment rows are equal. No enlarged/tightened crop region or new component required a changed-source review.

Eleven plans are neutral, one-part-per-detected-staff diagnostics on unresolved variable-layout scores, not initialized orchestral extractions. The corrected p38 plan uses the real quartet profile. Its known Viola/Cello whole-neighbor crops remain. The two accepted helper examples do not establish a real crop repair, and there is no claimed whole-score recall certification.

Single-run native timing was 4.20 s wall / 3.87 s user for V2 versus 4.17 / 3.82 s for baseline. Fixed180 was 1.45 / 1.17 s versus 1.14 / 1.09 s; tied36 was 0.66 / 0.25 s versus 0.26 / 0.24 s. These include launch/render/output work and concurrent compilation; they are not a statistical benchmark or full-corpus latency claim. Baseline timing binaries' six compiled source files match this frozen baseline.

## Reproduction and disposition

`frozen-core.zip` contains all 23 baseline and 23 candidate Core files. The additive patch and standalone helper are included. Runnable frozen harnesses, source/gate diagnostics, native source bindings, compressed full results, exact logs and the development source panels are retained. Large native binaries and full native-page rasters stay in scratch with hashes in `external-evidence-bindings.json`; source/mask fixtures remain in their unchanged earlier reports. Run `reproduction/run.sh NEW_SCRATCH_DIRECTORY` from the repository root to reconstruct the candidate and rerun the bounded fixed/native checks.

Hold this prototype for independent fresh-source review. The next design issue is source-supported *joint* ordered staff-line identity and a reliable hollow-body contour under occlusion. Do not loosen the fitted-body tests or remove the existing preservation witness based on these results. No app packaging or production promotion is justified by this report alone.
