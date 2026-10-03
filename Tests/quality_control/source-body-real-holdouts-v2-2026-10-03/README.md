# Fresh real-source notehead holdouts — 2026-10-03

The frozen V2 helper recognizes **4 of 24 genuine selected noteheads**, all filled heads on the Mozart page, and rejects all 12 misleading associations. It recognizes **none of the 12 hollow heads**. This does not support replacing general musical ownership evidence with this helper. It is a bounded shape/attachment check, not a demonstrated native crop regression or an end-to-end preservation test.

| Original source | Genuine selected heads accepted | Hollow heads accepted | False associations accepted |
| --- | ---: | ---: | ---: |
| Brahms Clarinet Trio 114012, physical page 3 | 0/8 | 0/4 | 0/4 |
| Schumann Piano Quintet 06822, physical page 3 | 0/8 | 0/4 | 0/4 |
| Mozart Piano Quartet 86903, physical page 4 | 4/8 | 0/4 | 0/4 |
| Total | 4/24 | 0/12 | 0/12 |

T-H04 is a genuine interior chord head on a continuing stem, not a terminal-head recall obligation. Excluding it gives **4/23 terminal selected heads**, including **0/11 terminal hollow heads**. Every accepted fitted ellipse lies wholly inside its predeclared selected body ROI. All four accepts were also checked visually against their original source; there are no accepted different-body or sibling-head substitutions.

## Independent source freeze

All 36 source cases were frozen before inspecting the V2 prototype source or design. The source hashes were sent to the parent before that inspection. The original two frozen JSON files remain byte-identical:

- `source-cases.json`: `f15934008b238a8e76a284216f3b99084b92de0aa57eae4dca6e965f30ce4d7e`
- `local-line-measurements.json`: `c6b46b3da5ead57cfe0c1a0d3df7afb83a3d05a8d56f14d59650d19434013b65`

Original PDF hashes, untouched native-size source rasters, exact body/spine review rectangles, independently measured staff fragments and raw column measurements are retained. The source-only manifest was assembled after sending the frozen hashes and before running the helper. The adapter uses the frozen spine columns, local staff spacing, measured fragment slope and explicit at-spine interpolation. No input was changed after seeing candidate behavior.

All three pages are outside the previous 12-page development replay; `page-independence.json` verifies the PDF hash/page pairs. The cases are intentionally chosen, not random or statistically independent. Two genuine heads share one chord stem; two filled heads share a beamed phrase. Six false associations reuse positive heads with unrelated structural spines. Three pairs of negative cases reuse the same physical barline with different body/intersection obligations, giving nine distinct negative spine sites.

The source set covers faint/broken and thick staff lines, ties and slurs, hollow chord heads, beamed notes, accidentals, structural endpoints and false head/spine proximity. Positive body-ROI centers are -0.16 to 1.42 local staff spaces inward of an outer line. The rectangles are review/preservation envelopes, not semantic masks that separate head pixels from crossing staff ink. Line centers beneath occluding notes are not directly observable; explicit adjacent-fragment interpolation and its caveat remain in every source record.

## Observed rejection patterns

A separate logging-only copy produces exactly the same 36 results, including identical four witness values. Its counted guards are proposal/loop diagnostics, not independent failed-case counts. No threshold or branch outcome was changed.

Seven genuine-head misses occur before body proposals: T-H02, T-F03, S-H01, S-H04, S-F01, S-F03 and S-F04. The helper remeasures its horizontal flanks, then rejects the resulting staff spacing. The frozen source input for T-H02 places the top line at y=294.123; the helper remeasures it at y=287.255, coinciding with the nearby tie. For S-F01 the independently measured third line is y=1039.853; the helper substitutes y=1032.745 near the beam/adjacent staff-line region. The source remains unchanged; these are internal line-identity failures, not an adapter adjustment made to gain acceptance. Three negative cases also fail this preliminary spacing check, so their rejection does not by itself prove successful body discrimination.

The remaining genuine terminal misses reach proposal fitting and fail combinations of contour coverage, fitted size/residual, outline support or filled/hollow evidence. T-H01 reaches the filled-or-hollow decision and is rejected; the source has a clear hollow head crossed by a staff line. The Mozart hollow examples include weak or interrupted contours that remain musically unambiguous in the source. They stay positive obligations even though a strictly closed cavity is difficult to establish in the raster. T-H04 produces no body proposals and remains separately labeled interior/nonterminal.

All 36 source cases were visually reviewed. All four accepted ellipses and representative missed hollow, tied, chord and beamed heads were reviewed again with result overlays. See [result contact sheet](review/v2-result-contact.png), the six original source contact sheets, `evaluation.json` and `rejection-diagnostics.json`. No false case permits deletion of its neighboring genuine note, tie, slur or dynamic.

## Scope and next evidence needed

The real hollow chord stem spans one complete staff core; no genuine musical spine crossing two complete cores was found. Ordinary own-stem recognition validates a shape hypothesis only. This experiment does not establish whether the native structural-erasure path tests these stems, whether other preservation paths retain the notes, or whether actual exported crops improve. The old fixed synthetic musical envelopes and corpus source obligations remain unchanged.

The next useful work is to preserve staff-line identity while measuring its thickness around occlusions, and to understand the genuine hollow-head contour failures without treating every enclosed staff/tie pocket as a note. Any revised detector needs new source holdouts: these 36 are now development evidence. No production source was edited, no corpus worker or exporter was run, and no tuning was performed against these cases.

## Reproduction and bindings

`candidate-Core/Detection/` contains the exact six source files compiled for the helper. The candidate analyzer is `2a76c26e292b1ba4baeb74d7388cb2172a5be41025d58de04efbef986da607db`. `verification.json` binds the candidate, binary, original PDFs/rasters, adapter, diagnostic copy and results. `hashes.json` binds the complete report.

From the repository root, build with `bash Tests/quality_control/source-body-real-holdouts-v2-2026-10-03/build-helper.sh Tests/quality_control/source-body-real-holdouts-v2-2026-10-03/candidate-Core .build/source-body-real-holdouts-v2-2026-10-03/helper-v2`, then invoke that binary with `helper-inputs.json` and an output JSON path. The probe verifies each source raster hash before use. The recorded adapter paths refer to this workspace; relocating the repository requires changing paths only, retaining the same source-image hashes and geometry.
