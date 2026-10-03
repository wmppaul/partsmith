# Independent additive-ownership code review

**Hold promotion of the untagged additive model.** A small native-raster control demonstrates that retaining every old component does not guarantee retaining the prior crop: adding a lower-staff ownership hypothesis shrinks the upper crop and excludes a detached mark that it previously included. The performance-only changes are sound and resolve the measured redundant-work problem. Root has held production promotion and is preparing separately typed, outward-only ownership alternatives; that repair is not part of this frozen review.

This review does not rerun the existing 633 synthetic controls, 755 crop checks or 39-page native corpus. It examines source code and runs bounded independent controls. The synthetic rectangles below are annotation surrogates, not semantic recognition of a named musical glyph and not a newly discovered missing note in an actual corpus score.

## Actionable model finding

The second analysis pass retains local components, but the union exposes new ownership hypotheses as ordinary `ScoreInkComponent` values. In `ScoreExtractionPlanner.cropBounds`, components owned by the following system populate `followingSystemInk` (line 940 in the frozen planner). Nearby detached marks then switch from all selected supporters to `targetOwned` supporters (lines 1023–1029). Consequently, an added hypothesis can suppress a previously accepted detached relay even though every original component remains present.

The initial constructed API control preserves all original components and adds a lower-only box. Its upper crop bottom moves from normalized **0.329 to 0.280**; both plans remain applicable. This illustrates the mechanism but is not itself native recognition evidence.

The stronger `raster-relay-v2/` control executes the actual native component analyzer twice on the same 720×760 source image, with the same correctly initialized staff geometry and profile. A three-row source interruption crosses the upper staff's final line. The lower terminal attachment veto adds a merged source box **[593,230,609,377]**, attributed only to the lower staff. All eight original local components are still present. The planner's upper crop bottom moves from **287 to 264 pixels**, excluding the second detached source mark at y272–281 that the local interpretation retained. No component was manually injected in this test.

`source-evidence.json` freezes the image pixels, three detached rectangles and source interruption before either analysis runs. `local-page.json`, `candidate-page.json` and their plans preserve the complete evidence. `source.png` is the immutable source; `crop-boundary-diagram.png` is a separate explanatory overlay. The third mark at y295–304 was already outside the local crop, so it is not counted as a new loss. Source and diagram were directly viewed.

The first raster attempt, retained under `raster-relay/`, is a useful negative control: its one-row interruption leaves the merged box touching the upper final staff line, so it has two owners and widens the upper crop to383 rather than shrinking it. `raster_relay_probe_v1.swift` is preserved. The final three-row fixture is `raster_relay_probe.swift`; neither changes any existing test or source guard.

**Recommended repair:** keep uncertain merged groups distinguishable from ordinary local components. Preserve the existing ordinary affinity, lyric and suppression decisions; let a new ownership alternative expand only the crop of a staff it touches. It must not create competing following-system ownership or otherwise revoke ordinary evidence. Add the native raster regression and an explicitly tagged API control. Keeping the old untagged API behavior for legacy data is compatible with this design. No production code was edited by this reviewer.

## Performance and cancellation

Unoptimized V3 recursively performs a complete local analysis even when no terminal witness vetoes a separator. It then tests each local component using linear `result.contains`, making union work quadratic. A deliberately noisy one-staff image cannot trigger the musical veto and therefore supplies an exact no-op case.

| Frozen implementation | 26,460 components | Time after last cancellation check |
| --- | ---: | ---: |
| V3 local hypothesis only | 0.0202 s | 0.00519 s |
| V3 unconditionally additive | 0.4489 s | 0.43477 s |
| Optimized combined, additive | 0.0134 s | 0.00390 s |
| Final cancellation-polished combined | 0.0104 s | 0.000056 s |

All produce the identical ordered component hash on this fixture. These are individual measurements under concurrent machine load, not timing guarantees. In unoptimized V3, a cancellation deadline ten milliseconds after its last callback expires while union work continues, and the analyzer returns a non-nil result. The optimized/final variants finish before that deadline. The final variant also checks cancellation before union, every 4096 union inputs and after sorting. Raw results and exact probe code are retained; the phase-cancellation behavior is not inferred from a full-corpus timeout.

The optimization is equivalent: without a terminal veto, `retainMusicalEvidence` has caused no mutation difference, so the local second pass cannot add evidence. With a veto, a `Hashable` key containing the exact ordered staff IDs and exact normalized bounds has the same identity semantics as the former equality search. The Set is used only for membership; append order is preserved. No coordinate rounding, tolerance or symbol threshold was introduced.

The additional pass still costs work on a page with a genuine veto and creates temporary component arrays and a membership set. The raster is bounded by 1800×2600. No memory leak, unbounded recursion or retained cross-run cache was found: recursion depth is at most two because the recursive call disables musical evidence. Peak memory was not instrumented, so no measured memory claim is made. One possible later optimization is to share immutable raster preparation between the two hypotheses, but it must preserve independent analysis masks and is unnecessary for this reviewed correctness repair.

The document worker checks both operation identity and cancellation before delivering progress/completion. Thus the unoptimized late-return defect wastes worker time and may delay a subsequent Auto, but does not establish a stale project-apply bug. Final cancellation polishing closes the newly expensive union tail without changing classification.

## Determinism, repeated Auto and ownership limits

The analyzer derives both hypotheses from the supplied source image on each run. It has no persistent accumulation of earlier alternatives. Exact duplicate membership prevents same-run duplicate evidence, and repeated Auto does not recursively feed prior components back into image analysis.

The existing final sort compares only top then left. The already-produced 39-page V3 inventory contains 26 ties on those keys across 19 pages (`sort-key-ties.json`). Dictionary iteration can therefore affect order for geometrically distinct tied components; the owner separately observed pre-existing array-order differences while component multisets and planned assignments stayed equal. This review does not claim that every analysis array is byte-deterministic. The Set optimization does not introduce hash iteration into output. A future full tie-break over all bounds and owners would make serialization reproducible, but should be tested separately against order-sensitive lyric grouping rather than silently bundled into this performance change.

The complete off-spine branch guard is conservative: long attached material can fail its compact-body criteria even if musical. It is not a proof of notehead identity. A retained connector box can overlap several staff cores; source geometry alone cannot establish an instrument's semantic ownership. The native regression above is precisely why uncertainty must not become exclusion authority. Existing failed synthetic envelopes remain failed; this review does not relabel them as a musical-preservation pass.

The earlier study's prose mistakenly associated V2/V3's two actual widenings with p26. Root and the owner corrected that mapping: current V2/V3 widenings are **p38 system1 Viola and Cello**; combined geometry additionally changes a p35 pair. This code review makes no source-quality verdict based on p26 and does not re-review those real-score images. The stored corpus comparisons, owner erratum and independent source review remain authoritative.

## Exact frozen source bindings

| Snapshot | NativeScorePageAnalyzer.swift SHA-256 |
| --- | --- |
| Standalone V3 | `6dd0b7eff723b5cd0d34d7c1510d826284cc8d537efb1f407e7d3d5c358e33df` |
| Unoptimized combined | `f96182e55566d298bb4a6abda2d57a9d3b7921aa6f7913164338b306b993a281` |
| Performance-only combined | `cbb4033fd92c7f3f24628ae99e7c6e7b6ef42cacf0cc2f5938aac4af30c7df0b` |
| Final cancellation-polished combined | `aa985ca21cb2d07f1ea013d179277922929ff4091107d364bc2619a1e52ba83a` |

Standalone V3 supplied the initial noise/API probe and one-row raster control. Optimized and final supplied their named noise/API results; final supplied the three-row native regression. `evidence.zip` preserves the exact six compilation inputs for each tested snapshot, build logs and commands. No binaries, existing corpus outputs or unrelated production files are included. `initial-review-hashes.json` binds this frozen report, fixture images, raw outcomes and archive. Any repaired candidate must have a separately recorded hash and result; these failing results must remain visible.
