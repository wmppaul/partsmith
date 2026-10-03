# Residual Brahms connections — source and native-mask audit

Read-only diagnostic, baseline commit `e9ef3d1`, 2026-10-03. The nine whole-neighbor crops come from five surviving interstaff connections. **Four are right system boundaries; the p28 connection is an interior barline.** The previous endpoint-only attribution of p28 was incomplete. No threshold, crop algorithm, production source or exported part was changed.

## Inputs and method

Original Brahms 93521 SHA-256: `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. The retained full 39-page native baseline uses exactly the nine saved corrections on physical pages 2, 7, 17, 19, 23, 28, 34, 38 and 39. This audit reuses its original native rasters for physical pages 24, 28, 29, 31 and 35; it does not claim a new 39-page detection run. P28 is the corrected 1068×1538 raster; the other four are 1800×2593.

The ten frozen musical envelopes are copied unchanged from the prior endpoint-ownership report. `source-guards.json` retains SHA-256 `e097a2b80032e18b85606f4f02c13e24870162857a02bf95f6b58786f2cdbe0c`. Their edges were not used to tune any diagnostic or candidate.

A logging-only copy of `NativeScorePageAnalyzer` emits its original threshold mask and final analysis mask after staff-line/connector separation. It evaluates both local staff shifts for diagnosis even where the production boolean would short-circuit. The actual separator decisions and all resulting component signatures are identical to an unmodified analyzer on the same image and to the prior native baseline on all five pages. This comparison treats component ordering ties semantically; an initial strict array-order assertion stopped at p29 despite identical component contents. No incomplete run is used as result evidence.

Eight-connected paths are then measured in the actual post-separator mask, across the unchanged interstaff gap rows used by production. Each region has exactly one surviving connected component spanning that strip. This does not mean a unique pixel path: the p29 repeat pair can provide parallel structural paths. `surviving-paths.json` records its pixels, shortest spanning path, row widths and source context. The bridge component may have attached horizontal branches; its enclosing rectangle is not itself the path. Source views were inspected before the corresponding analysis-mask views. Neither set is a synthesized notation image.

## Actual causal connections

All rows/columns below are native raster coordinates; ranges are half-open. Staff indices are zero-based.

| Source region / affected parts | Surviving connector | Production rejection | Exact limiting evidence |
| --- | --- | --- | --- |
| p24s2 Viola, Cello | Right edge, gap path x1638–1642, y1139–1200 | Translated lower core remains below 88% | Global upper 56/56; lower 48/57. Local shifts −2/−1 produce upper 56/56, lower **49/57 = 85.96%**. Eight missing vertical rows remain at y1246–1253, inside the lower staff. |
| p28s1 Violin I, II | **Interior** barline, gap path x246–248, y142–172 | Translated upper core remains below 88% | Upper **29/34 = 85.29%**, lower 33/33; upper local shift −1 does not repair missing rows y113–116 and122. The right-edge connector x963–970 passes both cores at100% and is removed correctly. |
| p29s1 Violin I, II | Right repeat boundary, connector x1614–1635 | Lower shared-shift tracker fails at its final segment | Upper global49/57; local shift+8 is accepted. Lower global56/56, but its local pattern fails. At x1584, segment33/33, best reachable five-line support is `[1,1,1,40/42,29/42]`; **bottom line69.05%** prevents a result. |
| p31s1 Violin II | Right edge, gap path x1644–1648, y253–308 | Both shared-shift trackers fail | Upper global45/56; lower56/57. Upper fails segment29/34 atx1509: first line **30/42=71.43%**. Lower fails already segment2/34 atx942: first line **19/42=45.24%**. |
| p35s1 Violin I, II | Right edge, connector x1641–1648 | Upper shared-shift tracker fails well before the edge | Upper global44/56; lower57/57. Upper fails segment8/34 atx1067: second line **33/42=78.57%**, other four1.0. Lower local shift+9 succeeds. |

All five actual gap paths are continuous. At least one original physical stroke supports every gap row. Measured physical widths are respectively4,2,17,3,3 pixels; p29's17-pixel span includes its two separate repeat strokes. None is rejected by the width gate. `causal-gate-summary.json` retains exact gap occupancy arrays, physical-stroke bounds, core row counts, local support candidates, tracker failure values and rejection branches. No junction gate is reached for the five rejected causal connectors.

The original source contexts show structural barlines, not actual musical stems crossing between these instruments. In p24 and p28, the rejected vertical core contains a scan break even though the interstaff stroke survives. In p29, p31 and p35, discontinuous/bowed horizontal staff lines defeat a common five-line shift despite a visible structural boundary. P31's complete ambiguous component is unusually narrow and largely isolated; the parent is separately investigating its orientation-aware width. This audit does not certify that proposed filter.

## Implications for a structural graph

The measured cause supports a narrower distinction than a general occupancy adjustment. The interstaff connection must be labeled from its relationship to staff identities and shared measure/system boundaries; a broken core is not evidence that the surviving connection is musical. Conversely, a long musical stem or attached head can satisfy local vertical occupancy, so weakening the existing 88%/80% gates is not justified by these five source examples.

A direct structural repair would need to identify the longitudinal barline path separately from musical branches, establish its shared bar position from other staff intersections in the same system, and separate only that structural connection, including both strokes when it is a repeat pair. Original source pixels remain untouched. Musical branches—noteheads, stems, slurs, dynamics and ledger lines—must keep ownership and cannot be discarded with the broad component's box. P28 requires an interior measure-boundary model; a right-endpoint-only solution cannot fix it.

The parent's independent line-path prototype provides useful diagnostics but currently aliases staff identities. Strong local support is insufficient: p29 upper lines2/3 converge to y226.82/226.88; p31 upper lines1/2 converge to214 and lines3/4/5 to about242.49; p31 lower lines2/3 converge to352.57/353; p35 upper lines3/4 converge to246.02/246.01. `interior-path-review.json` retains these values. The p24 and p28 paths remain distinct, but p28's causal connector is interior. A usable graph needs jointly ordered, separated staff-line identities and explicit missing-evidence spans; independently maximizing each line's support cannot certify endpoints.

These are source-grounded requirements, not an accepted new algorithm. No nine-case repair or broad generalization has been demonstrated. A future candidate still needs the unchanged 755 existing checks, 336 independent musical-envelope controls, ten frozen source guards, original nine-case readability inventory and broader real-score checks. They were not rerun here because no extraction change was made.

## Evidence

`native-probe-evidence.zip` preserves copied analyzer/support sources, logging harness, probe scripts/logs, native original/separated masks, exact prior baseline and source rasters. `provenance.json` binds every member and original input. The complete five-page run exits0 and reproduces all five component signature sets exactly. The scripts and report are isolated from production. The earlier rejected endpoint experiments remain at [residual9-endpoint-ownership](../residual9-endpoint-ownership/README.md), including the unchanged guards and failed crop candidates.
