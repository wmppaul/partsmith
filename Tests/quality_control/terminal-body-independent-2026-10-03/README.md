# Independent terminal-body source controls

Status: the original 180 source controls and their baseline are frozen before receiving a runnable continuation candidate. Production is not edited. A separately identified tied-head supplement is described below.

This bounded harness adds hollow noteheads and independent musical-versus-structural source ownership to the existing rectangular/filled-body regressions. It does not replace or weaken any existing 297/336 case or source guard. The fixtures are synthetic examples of musical geometry, not transcriptions of a real score or a test of instrument recognition.

There are 20 authored geometries, three explicit source transforms and three analysis resolutions (180 cases). Source staff spacing is 14 pixels. Slanted elliptical heads have a real inner white cavity for hollow heads; the staff remains visible through that cavity. Musical stems have heads at an outer staff line, first space or second line. Scan interruptions remove explicitly stated source rows, rather than changing the oracle after analysis.

Every black musical source pixel has an independently assigned physical-staff owner mask. A long cross-staff chord is shared between its two physical-staff views; both must retain the complete authored chord. This is a conservative source-preservation obligation and does not claim the chord belongs to two distinct instruments. Other notes, slurs and ties have exactly one authored physical-staff owner. Their envelopes and out-of-crop source-pixel counts are computed from those masks before native components are considered.

Separate structural cases contain an otherwise clean continuing barline, a long owned tie or slur arriving at it, a curve continuing across it, and source interruptions. The full curve must remain in its source owner's crop; retaining a whole neighboring staff is separately recorded as a failure to separate the structural boundary. A local filled or hollow note sharing barline pixels is deliberately classified as mixed: its entire local music must remain, but structural separation is not a hard requirement because those pixels support both interpretations.

The transformations are (1) unchanged source, (2) a 2-degree column shear, and (3) a -1-degree shear plus a smooth seven-pixel bow applied toward the right. Exactly the same transform is applied to source pixels and source-owner masks. Native candidates keep their source-interior staff identities. The raster scales are 0.5, 1 and 1.5; the native planner always returns coordinates in the original 720×600 source space.

`controls.swift` writes the source PNG and both independent owner masks for every geometry/transform. The results record exact source envelopes, every planned crop, missing owned source-pixel counts, alternative/shared components at the tested stroke, and whole-neighbor counts. Source preservation and structural cleanliness are reported separately. No detector-generated component bound is used as a preservation oracle.

The six compiled production source files are frozen under `.build/terminal-body-independent-2026-10-03/baseline/Core`, from historical commit `d2a43e1`. Baseline and candidate runs use the same controls and independent source masks. Candidate implementations must not modify the fixture or expected source obligations to make their result pass.

## Baseline findings

The historical production baseline preserves 122 of the 180 complete authored musical envelopes. All **58 failures are among the 90 long musical-stem cases**. All 72 pure structural-boundary cases retain their owned notes/curves and separate the neighbor staff cores; all 18 mixed local-note/barline cases retain their local musical content.

Hollow heads at the outer staff lines and first spaces fail all nine transform/resolution variants in each family, including normal resolution. Hollow heads with staff-line interruptions likewise fail all nine; hollow interrupted stems fail all nine. The second-line hollow family has two failures, including one half-resolution case that loses only ten source pixels. The filled and mixed families also expose failures under some transforms, so this is not exclusively a hollow-head or low-resolution limitation. Filled interrupted stems fail all nine complete-envelope obligations, often because the lower physical-staff crop loses the detached upper portion.

These are strict failures of the original source masks, not just width or component-label diagnostics. `baseline-summary.json` lists every failing case and exact per-owner source pixels outside the crop; `baseline-results.json` retains all crops/components and source envelopes. No expected envelope has been reduced or reclassified because it fails. Existing success on the earlier 336 rectangular filled-body controls must not be reported as general preservation of all filled or hollow heads.

Both source contact sheets were viewed: the 20 straight geometries have distinct filled/hollow heads, expected head/staff intersections, explicit short scan gaps and long structural curves. Original source examples for filled outer heads, hollow outer heads and a curve crossing a barline were also viewed at their full 720×600 dimensions. The transformed masks use the identical source transformation and remain bound in `source-hashes.json`.

## Separately frozen tied-head supplement

After the algorithm author described a possible two-sided body traversal, a further positive was identified: a genuine notehead can itself have a long tie attached on the opposite side of its stem. Global continuation cannot by itself prove that its head is structural. The original 180 controls remain byte-identical.

`tied-controls.swift` adds four source geometries with the same three transforms and three resolutions (36 cases): incoming and outgoing ties on a filled upper head, a tie on the lower filled head, and an incoming tie on a hollow head. These are frozen in `tied-frozen-protocol.json` **after the mechanism description but before a runnable candidate was received or inspected**. The entire chord and attached tie have explicit source masks. This timing is intentionally distinguished from the original blind source controls. The supplement is a new obligation, not a parameter request or an alteration of a failed original fixture.

The supplement baseline retains 12 complete envelopes and fails 24: the incoming/outgoing filled upper-head families each fail three transformed cases; the lower tied-head family and hollow incoming-tie family each fail all nine. Source examples of the incoming filled tie, lower filled tie and incoming hollow tie were viewed at full source dimensions. These failures remain separate from the original 58/180.

`independent-mask-check.json` independently rereads all saved source and mask PNGs using NumPy/Pillow. Across all 432 per-owner observations in the 216 cases, every owned pixel is actual black source ink and the measured mask extents, pixel counts and crop-edge losses exactly match the frozen native-harness records. `baseline-hollow-loss-example.png` shows the straight, full-resolution hollow case; its visual crops round outward only for display, while the numeric oracle retains the exact planned bounds.

## One reviewed continuation candidate: rejected

The independently compiled candidate analyzer is `bee4d523d415d9182eac6da4df7f608b7f637718ef48b8fce146f6301a969f95`. Only that analyzer differs among the six compiled files. The exact source change is retained in `candidate-v1.patch`; `candidate-v1-binding.json` and `candidate-v1-review.json` bind source and binaries.

The candidate reproduces every original-180 and supplemental-36 crop and missing-source count exactly. It neither worsens nor repairs those sets: **58/180 and 24/36 failures remain**. All candidate source PNGs and owner masks are byte-identical to their independently frozen counterparts. Both comparisons are retained, with per-owner loss checks rather than only an aggregate pass count.

This subset's nonregression result does **not** approve the candidate. The algorithm author's unchanged 297 controls fall from **238 to 217 complete source envelopes**, with **21 new failing cases and 103 worsened owner envelopes**, including already-failing cases. Those results were independently read and are copied/bound as `external-v1-297-comparison.json`; this reviewer did not rerun that native suite or represent it as an independent execution.

Code review agrees with rejecting the mechanism. The new source-row seed range includes all directly connected ink on both sides of the spine. At a staff/head or ledger/head intersection, that can introduce source staff-line pixels into the later analysis-ink flood. Its compact-body limit then rejects a real head because of attached line remnants. The code does not establish whether the continuation is a staff line, a musical curve, or part of the notehead. A real note can also carry a tie; an extended attached path cannot alone invalidate its musical ownership.

The next mechanism must preserve source-defined filled and hollow heads at line intersections while independently identifying a structural curve or staff continuation. No new dimensions or threshold values are recommended by these controls. No production code or prior oracle was changed, and the rejected candidate is not a proposed promotion.
