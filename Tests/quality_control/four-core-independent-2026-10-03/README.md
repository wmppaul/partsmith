# Four-core continuation fallback: independent rejection

The frozen p28 fallback candidate is **rejected for promotion**. Four independently authored, damaged musical examples lose previously retained source pixels. The candidate's source-supported continuation through three other staff cores proves that the physical stroke continues, but does not prove that the shared stroke is exclusively structural. Existing body-preservation evidence does not prevent these losses. Production is unchanged.

This is a bounded synthetic source-ownership counterexample, not a claim that the actual Brahms p28 crop loses a note. The actual p28 source cleanup was reviewed separately by the candidate author. Passing that positive and the existing 765 controls cannot override new source loss.

## Frozen setup

- Baseline Native SHA256: `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`.
- Candidate Native SHA256: `769776e41d5908f1c4bbdff8700493327f93f34bfc6ea9cb8df0cb28051f19ab`.
- Both snapshots use the same current planner, SHA256 `c2db1d31e5c8e2384f42180fa65f0a21e0ca21b3b7fd0ce2ba1234e643669d45`. All 23 Core files per snapshot are bound in `frozen-sources.json` and retained in `frozen-core.zip`. Only Native differs.
- The unchanged 36-case fixture and `frozen-protocol.json` were saved before either baseline or candidate was run. Fixture SHA256: `5dbf6b01298373601a6fdb07f0802486a4c26f67ef377f4c24dd931030ba080d`.
- Six shapes (filled/hollow outer-line heads, their tied variants, filled/hollow first-space heads), intact or damaged, at 0.5×/1×/1.5× raster scale.

The source defines four staff cores and one physical two-pixel spine. The upper two physical-staff views share a musical cross-staff chord: both heads and its long connecting stem are explicitly source-owned before analysis. Below that chord the same spine continues structurally through two further cores, whose targets are only their own local notes. This deliberately tests mixed musical and structural ownership on one physical corridor; it does not assert four instruments share one musical stem. The source damage removes rows 113, 114, 115, 116, and 122 from the two spine columns, matching the five-row interruption motivating the candidate. The identical removal is made in the source ownership masks when the source is authored.

The source and its masks are never reconstructed from detected components or crop output. All 60 PNGs are byte-identical between baseline and candidate. All source envelopes and pixel totals are identical. A separate PIL/NumPy recount verifies all 288 owner observations against the actual masks (`independent-mask-check.json`).

## Results

| Measure | Baseline | Candidate |
|---|---:|---:|
| Fully retained whole cases | 0/36 | 0/36 |
| Fully retained owner observations | 76/144 | 72/144 |
| Source pixels lost, all observations | 13,278 | 14,370 |

Preexisting losses are substantial and remain explicit: this study does not declare the fixture passed merely because some upper-owner envelopes survive. Four upper-owner observations were lossless in the baseline and fail in the candidate; four lower-owner observations with preexisting losses get worse. The other 32 cases are completely unchanged, including their component records and preexisting failures.

All changes occur at full resolution with the five missing rows and outer-line heads:

| Source shape | Upper owner loss, before → after | Lower owner loss, before → after |
|---|---:|---:|
| Filled | 0 → 216 | 94 → 166 |
| Hollow | 0 → 186 | 67 → 139 |
| Filled with tie | 0 → 216 | 228 → 300 |
| Hollow with tie | 0 → 186 | 201 → 273 |

For all four the upper crop shrinks from `76.625…219.125` to `76.625…145.125`; the lower crop starts at 152 instead of 111. In the filled example the previously shared component `[489,123,502,215]`, owners `[0,1]`, becomes `[500,123,502,141]` owned by 0 and `[489,173,502,215]` owned by 1. This is an analyzer separation followed by the expected planner consequence, not a changed planner or source oracle.

`filledOuter-counterexample.png` and `hollowTiedOuter-counterexample.png` show the original pixels, baseline/candidate upper crop edges, and newly excluded musical pixels in red. Both were visually reviewed: the lower head and connecting stem fall outside the candidate upper crop. The pictures are diagnostic source comparisons, not simulated exports.

## Mechanism and scope

The candidate adds a fallback only when normal proof fails after local staff geometry is available. It requires one undilated corridor, the failed core's outer junctions and five sustained flanks, three consecutive fully proved other cores in one direction, and source ink in every intervening gap row. These restrictions establish physical continuity. They do not exclude a genuine musical branch attached to that continuing corridor. The old terminal-body veto is insufficient for these source-defined damaged, hollow, and tied cases; the candidate does not supply new musical-ownership proof.

No further parameter tuning or broad native corpus run was performed after this independent rejection. A future proposal needs musical ownership preservation before discarding the connecting source pixels. Neither a larger number of donor cores nor successful structural positives alone can settle this ambiguity.

## Reproduction

The original run is `.build/brahms-remaining-2026-10-03/four-core-independent`. `scratch-bindings.json` records both exact executable and result hashes. To rebuild elsewhere, unzip `frozen-core.zip`, then run `build.sh CORE controls.swift BINARY` from the repository root and invoke each binary with `OUTPUT_JSON SOURCE_PNG_DIRECTORY`. The frozen source fixture produces the source and all four owner masks for each shape/damage variant.

`compare.py` compares the original bound run and checks identity before recording changes. `render.py` independently recounts source pixels and generates the two panels. Durable baseline/candidate JSON, source PNGs, the candidate patch, the frozen Core archive, and all hash bindings are included here. No existing fixture, report, or production file was modified.
