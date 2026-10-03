# Remaining seven Brahms source obligations

Independent, source-first audit against HEAD `82b606e`. Production is not edited by this work. This is a bounded structural-continuity investigation, not a claim that every extracted note is correct.

The seven remaining broad crops are physical p24/system2 Viola and Cello; p28/system1 Violin I and II; p31/system1 Violin II; and p35/system1 Violin I and II. Adjacent p31 Violin I is also protected. The prior p29 pair is already fixed and its two guards remain in the unchanged ten-guard file.

## Input identity

`source-binding.json` proves the current complete native worker and previously reviewed corrected V2 plan have identical 39-page staff geometry, component multisets, all 604 band identities, and all seven active crop rectangles. The one pre-existing main-crop difference outside this task is the p28/system2 Cello Da Capo owner expansion. Both corrected PDFs render identically on all four inspected pages. The nine saved rectifications are exact; only p28 among these four pages is rectified. The original source SHA is `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`.

`source-guards.json` is a byte-identical copy of the ten earlier full-target guards: SHA `e097a2b80032e18b85606f4f02c13e24870162857a02bf95f6b58786f2cdbe0c`. No bound was moved or shrunk. Full-source contexts were viewed before local details or any hypothetical tighter crop.

## Source oracle

`source-oracle.json` records five independently selected narrow spine corridors, all actual dark-pixel row runs and explicit white gaps, two staff-line fragment measurements, and thirteen local note/mark preservation obligations. Top-down PDF coordinates, raster scales, origins, and image hashes are explicit. The local boxes supplement the full-target guards; their presence is not an assertion that every enclosed pixel is music. Source images are untouched PDF renders. Rendering at 16 pixels/point provides inspection magnification, not new scan detail.

The original p28 is a 2376×3417 monochrome scan; its saved rectified page is a 1780×2563 grayscale image. Original and rectified spine observations have their own coordinate systems. No approximate affine mapping is used. The other inspected original pages render identically to their current corrected-document pages.

An initial oracle version is retained as `source-oracle-v1.json`. Visual inspection of the small local boxes exposed that the p35 lower low ledger note reached left of the initial local box. The current oracle expands that local box from x340 to x337.5; none of the ten pre-existing guards changes. Every final local musical crop was viewed against its larger source context.

| Region | Source observation | Notes/marks that must remain |
|---|---|---|
| p24/s2 right boundary | Narrow actual spine between Viola and Cello. Internal white gap y295.5625–297.3125pt, 1.75pt (about 7.4 native pixels; raster analysis reports eight missing rows). | Viola final slur, note/stem, and hairpins; Cello high final note/slur, sharp/half-note group, and lower hairpins. |
| p28/s1 interior boundary | Original and rectified sources both show two interruptions within upper staff core. Rectified gaps y45–46.9375pt and y48.4375–49.1875pt. The first is about five native pixels. Full context confirms the same barline across all four staves. | Flagged/ledger notes just to the left and notes to the right in both upper instruments. The third staff also has musical accidental ink beside this same boundary. |
| p31/s1 right boundary | Real system boundary. Narrow small scan interruptions near y83 and87pt. The upper staff's rightmost horizontal evidence is mixed with descending noteheads and isolated tiny line crumbs. | Upper beamed descending notes/slur and final detached note; lower flagged notes, lower slur, and crescendo. |
| p35/s1 right boundary | Real right boundary is continuous within the selected corridor after its physical top at y48.6875pt. Earlier failure of the second horizontal line occurs far to its left. | Upper beamed melody, dots/ledger notes; complete lower rising beam/stems, low ledger note, and long rising slur. |

End-of-corridor white runs are not internal gaps. A row containing a transverse staff junction is not necessarily evidence that the longitudinal barline survives that row. The recorded rasters remain available for distinguishing these cases.

### Horizontal fragmentation versus musical occlusion

On p35 the second-line source corridor y49–51.2pt over x240–275pt contains a longest literal dark-ink gap of 3.4375pt (about 14.5 native pixels, about 1.05 staff spaces). Clear horizontal fragments flank it; a single musical stem crossing near x254 is separately labelled ambiguous. The old window accounting could accumulate 63px of “missing” distance even though actual source fragments repeatedly occur. The grayscale<224 run result is also retained, without using it to overwrite the strict dark-pixel evidence.

On p31 the top-line corridor y46.5–48.8pt over x345–391pt has a longest literal white gap of 5.0625pt. That does **not** establish staff continuity: late descending noteheads occupy x360.8–364, x367.8–373.5, and x375–379.25. The last independently clear long horizontal fragment ends around x357.4. Subsequent tiny crumbs near x384–389 are much shorter than a staff space. Treating those noteheads as renewed staff identity would conflate musical ink with line provenance. The oracle distinguishes raw observed-column runs, certified horizontal fragments, and occluded spans.

## Necessary separation constraints

1. Carry the identity of each original ordered staff line. A neighboring ledger ridge, beam, or descending notehead cannot become a newly found line solely because it occupies a predicted row.
2. Treat missing source pixels as unknown, with two-sided geometric evidence. A short observed gap is different from an entire low-density window. Retain measured gaps and unresolved occlusion; do not manufacture a continuous source stroke in the oracle.
3. Follow the intended spine through the missing interval. On p28, a nearest-dark-pixel continuation can jump sideways to a genuine note stem/flag. Agreement at a system/measure boundary and between staves is useful, but is not itself musical ownership proof.
4. Certifying the structural spine does not certify its attached branches as removable. Notes, accidentals, slurs, and hairpins can share pixels with barlines. Keep gap-only separation and all branch/crop obligations. If shared pixels have unresolved ownership, retaining extra ink is preferable to excluding target notation.
5. Trace geometry to the actual cut location. A shift measured at an inner flank cannot be assumed constant at the barline. Parent's later diagnostic identified this exact p35 mismatch; the existing junction rejection is appropriate until the endpoint geometry is known.
6. Keep the unchanged 755 controls, independently frozen 297 and336 musical-envelope cases, ten source guards, all changed-source inspection, and corpus comparison. Neither a common edge across three staves nor synthetic case counts alone establish preservation.

## First pixel-run candidate: non-regression only

Frozen analyzer SHA `2f0315a0a655fd11109a308702eca35f8eb85251610579606280d2e0339f683a`, `.build/residual7-geometry-2026-10-03/candidate-pixel-runs/Core`.

Independent runs of the unchanged297 and336 fixtures exactly match the current baseline results. Each was repeated in a separate process with identical results. The five supporting Core source files equal the earlier validated V2 baseline byte-for-byte; only the analyzer differs.

- 297: 201 cases retain all target envelopes; **96 pre-existing failures remain**. Whole-neighbor count198 unchanged. Zero changed cases, zero new failures, and zero worsened source-envelope intersections.
- Expanded336: **all336 existing preservation failures remain**, with exact result equality. This includes ordinary analysis resolutions; it is not a low-resolution-only issue.
- Parent's separate755 run passes. Parent's actual39-page result reports no crop changes and all seven broad crops remain. These two parent results are reported as external evidence, not rerun here.

Code review confirms the width/core88% and final junction checks are unchanged. The candidate replaces coarse missing-window accounting with pixel-column runs and requires half a staff space of observed ink to reset a line's unknown budget. However, it also removes the old requirement that at least three lines have80% support in every subsequent window. All five can now be carried through a short entirely unsupported interval until the four-space budgets expire. This is a substantive acceptance change and must be tested as such. A run of notehead pixels can still look like observed row ink; the p31 source makes this risk concrete.

Predecessors remain sorted, so repeated results are deterministic. Equal-score/equal-missing states do not compare `observedRun`; one stored history can discard another with better future continuation. This is a possible conservative missed-path issue, not evidence of a newly accepted invalid path in the measured cases.

**Verdict:** the first pixel-run candidate is a useful diagnostic but provides no user-visible crop improvement. No promotion is recommended from these results. Source-backed endpoint geometry and musical/staff-line provenance remain the next bounded investigations.

## Connector endpoint experiment V2: rejected for actual musical loss

Frozen analyzer `be1b1d5b3d77b164749ad8837043ea14216a1a8b347521466ddd8aa0f32d3db7`, retained in `candidate-connector-target/`. This version changes the trace target from the inward flank midpoint to the connector itself, keeping the first pixel-run candidate's removal of the three-visible-line gate.

Independent full39-page comparison finds exactly two main-crop/warning changes, both p35/system1, and 602 unchanged rows. Whole-neighbor occurrences fall7→5. Semantic component changes also occur on p29, with its crop rectangles unchanged. All thirteen local musical obligations remain contained, but the original full Violin I guard remains **failed**: its bottom is68pt and the proposed crop ends66.3824209715pt. The unchanged guard is neither shrunk nor replaced.

Separate source-clearance inspection: the full p35 original context, both new complete strips, and three enlarged horizontal views across the excluded66.3824–68pt region were examined. That region contains system/barline strokes and the top of neighboring Violin II beams; no Violin I target note or marking was identified there. This is a documented distinction between a conservative rectangular guard failure and observed target-ink loss, not a passing result for that guard. Both proposed strips still include neighboring fragments.

This version is independently disqualified by actual musical loss:

- Parent's755 suite stops on the curved musical figure at bow−5, tilt−1.5°, raster0.4.
- Independent297 finds **two additional ledger-alias failures**, at raster0.5, bow0, tilts−1.5°/+1.5°. All three owners in each case lose part of their source-defined musical envelope: six worsened envelopes. Preservation201→199;15 cases change; whole-neighbor count198→202.
- Expanded336 is exactly unchanged, retaining its336 existing failures.

### Isolated early755 diagnosis

`candidate-connector-target/isolated/` contains the unchanged fixture construction extracted from the755 harness, original and logging-only analyzer copies, rendered fixture at source and analysis resolutions, results, and event traces for baseline, pixel-run/flank, and endpoint variants. Source and analysis pixel hashes are identical across all three. Logging statements inspect existing values; they do not add acceptance branches or change fixture expectations.

The original musical source envelope is `[443,204,459,380]`. Baseline and flank versions produce vertical crop bounds `[154.5,393.5]` and `[179.5,413.5]`, both containing it. The endpoint version produces `[154.5,268.5]` and `[304.5,413.5]`; each omits the opposite notehead and much of the stem.

The mechanism is visible in the native288×240 trace:

1. All versions accept the upper local-fit shortcut at shift+2 for a4.8px staff space. That shortcut alone is insufficient to cut; lower-staff validation previously prevents it.
2. Baseline lower tracing has no surviving states by column161. The pixel-run/flank version reaches its target166 with shift−2, but the resulting full core support fails.
3. Extending the target to180 allows lower-staff paths to transition onto an upper ledger alias. At column168 the near-correct−2/−3 histories have17px unknown distance on the missing outer line. They expire while the aliased−6/−7 histories encounter matching ink and reset their counters.
4. At column174 the surviving histories are−7 and−6; at target180 shift−7 wins. This is approximately one staff-space away from the physical staff. The translated core and final vertical-junction tests then validate the wrong line identities.
5. The separator runs across native x176..<185, y103..<129 and the planned crops lose the independently defined musical envelope.

A geometrically valid final junction therefore does not repair corrupted line identity. The source/analysis images plainly show the tagged cross-staff stem with its two noteheads. The guard was not derived from a component box.

## Connector endpoint plus three visible lines V3: preservation restored, crop quality regressed

Frozen analyzer `6897398abfa58e58d917df9989a0ab75a9a17bf685f38015fe518b294100c8e3`, retained in `candidate-connector-three-lines/`. Parent's755 suite passes after restoring the prior requirement for three80%-supported ordinal lines at every later window.

Independent633 results:

- 297 retains201 complete cases and96 pre-existing failures, with **no new or worsened target envelope**. However35 cases change and whole-neighbor occurrences increase198→248. Structural/readability cases with whole neighbors increase45→73. Affected families include clean boundaries, interrupted horizontal lines, parallel paths, heads at junctions, attached slurs, and shared stems entering gaps.
- Expanded336 remains exactly unchanged, with all336 existing failures.

The independent actual39-page comparison finds four enlarged crops: previously corrected p24/system1 Viola and Cello, and p29/system1 Violin I and II. Every changed crop contains its entire baseline crop, so this is retained-extra-ink regression rather than source loss. The p35 improvement disappears. Whole-neighbor occurrences increase7→11; all ten original rectangle guards and thirteen local obligations remain contained.

**Verdict:** reject V2 for new actual musical omissions and reject V3 for widening previously corrected source crops without improving the remaining seven. No production edits, full-corpus run, or export is warranted for these frozen versions. Parent's next hypothesis separates the known interior identity path from a short one-sided continuation to the actual boundary; that is not tested or endorsed here.

## One-sided endpoint refinement V4: bounded improvement offset by a regression

Frozen analyzer `feb3b98bd99614a8ee8d66704616861a0a4aced9378ac50198d2c4336f56a896`, retained in `candidate-endpoint-refinement/`. This version keeps the interior flank target and the three-visible-line window gate, then evaluates a short one-sided path toward the connector. It carries five unknown-distance/run counters, requires three80%-supported lines along the inward span, and caps additional offset change below half a staff space at the tested resolutions. The final core/junction checks remain intact.

Code-review limits: observed ink still lacks explicit staff-versus-note ownership, and the short path ends just outside the connector envelope; endpoint geometry is extrapolated across half that envelope and checked by the final junction gate. The minimum drift of one pixel is strictly less than half a staff space only when spacing exceeds two pixels. None of these observations changes fixture expectations or proves a new failure.

Parent's755 suite passes. Independent297 retains201 complete cases/96 old failures with zero new or worsened target envelopes. Exactly four interrupted-horizontal-line cases change and whole-neighbor count improves198→191. Expanded336 remains exact, with336 existing failures.

The actual39-page replay improves both p35 crops to the **exact same bounds as V2**, so the full-source visual review and explicit guard-strip clearance apply by source-hash and rectangle equality. The original68pt guard remains failed. However, both previously fixed p29 crops widen again, each containing its entire baseline crop;600 other rows are exact. Whole-neighbor occurrences stay7→7. This is a source-readability tradeoff, not a net improvement to the remaining-seven problem.

**Verdict:** do not promote V4 as-is. Preserve an already validated original connector proof; refine endpoint geometry only when that proof fails, then apply the same original core/junction tests. That proposed next variant is not covered by V4's results.

## Preserve a supported endpoint V5: candidate awaiting broader corpus review

Frozen analyzer `1299e0ab21701803cf04e71137a2fbb46ca834f32d148e8cf6cf1981d3adc962`, retained in `candidate-supported-endpoint/`. A shared `connectorProof` helper contains the exact original translated88% core support and all-five-junction predicates: same source pixels, bounds, radius, and±1 row allowance. Combining the two pure checks per staff changes evaluation order, not their logical conditions. The existing highest-ranked interior shift is retained when it already passes that proof. Only a failed proof triggers one-sided endpoint refinement; the final selected shift passes the same helper again. The drift cap permits zero at tiny spacing, preserving the strict half-space limit there. No crop-result union or weakened threshold is introduced.

Parent's755 suite passes. Independent297/336 results exactly equal V4: zero new or worsened target envelopes, four horizontal-break improvements, synthetic whole-neighbor count198→191;96 old297 failures and all336 existing expanded failures remain. These are not a global-preservation pass.

The independently compared actual39 replay now changes **only the two p35/system1 crops**, both exactly equal to the previously reviewed V2 source rectangles. All602 other band records, including previously fixed p24 and p29 rows, are exact. Staff geometry and saved rectifications are unchanged; p35 is the only semantic component-change page. Whole-neighbor occurrences improve7→5.

All thirteen local musical obligations remain contained. The original ten-guard file is still byte-identical, with **nine passing and the p35 Violin I rectangle still failing** at68pt versus66.3824209715pt. The documented source-clearance finding applies unchanged: the excluded strip contains structural lines and neighboring Violin II beams, with no observed Violin I target ink. This explicit finding is separate from, and does not overwrite, the failed rectangle check. Source hash plus exact rectangle equality binds V5 to both completed source-strip visual reviews; no altered source images or new crop oracle are used.

**Verdict:** V5 is a promising bounded candidate for the p35 pair, pending full-corpus comparison, review of any additional component/crop changes, and integration checks. It is not promoted by this audit. The known musical-ownership failures remain explicit and require a separate mechanism; combining another mechanism with V5 requires fresh combined-code results rather than inheriting either candidate's standalone claim.
