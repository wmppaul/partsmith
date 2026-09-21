# Connector separation at native and corrected resolutions

Candidate 3 fixes a structural-analysis bug that could turn an extracted Quartet part into several neighboring staves. Parallel bracket strokes protected each other as supposed notation branches. On the smaller raster used after deskew, the detector's ±2-pixel continuity search also merged separate strokes and made their apparent width too large.

The analyzer now groups nearby thin structural strokes, excludes the search halo from width checks, and uses two distinct peaks in the original vertical-support profile to recognize a pair whose search halos already overlap. The existing 80% inter-staff continuity and 88% support through both staff cores remain unchanged, as does preservation of horizontal notation branches. All operations affect analysis only; source PDF pixels are never cleaned, masked or replaced, and crop boundaries are not capped at geometric staff midpoints.

## Controlled results

The user's source is the 39-page `06_brahms_string_quartet_no3_op67_imslp_93521.pdf`. All 604 assigned bands remain present. Tests use the original frozen staff detector to isolate this change; staff geometry is exactly unchanged on all 39 pages. Nine corrected pages use their exact previously saved transformations at the app's 2.5 raster scale, without new estimation.

| Case | Earlier candidate | Candidate 3 |
| --- | ---: | ---: |
| Raw source: whole neighboring staves | 29 | 23 |
| Raw source: neighboring line centers | 732 | 708 |
| App deskew path: whole neighboring staves | 430 | 20 |
| App deskew path: neighboring line centers | 2,617 | 688 |
| App deskew path: multi-staff components | 72 | 11 |

The originally reported corrected page 2 now has zero whole neighboring staves across all 12 bands. Across the nine corrected pages alone, whole neighboring staves fall from 408 in candidate 2 to 2 in candidate 3. These counts measure extraneous context; they do not establish complete musical fidelity.

The historical 25-page Quartet retains all 480 bands. Whole neighboring staves decrease from 38 to 36. Its independently frozen protected-envelope failures remain 44, with no new or worsened failure. The 39-page raw source's 28 independently selected bands and 39 protected regions have unchanged containment: the sole mismatch is the previously reviewed 0.207-point empty lower safety margin at p37s2 Cello. Raw guards are not used to certify corrected-coordinate output.

## Regression checks

`bash tools/test_crop_quality.sh` passes 82 assertions. It covers original and wider paired brackets at raster scales 1.0, 0.6 and 0.5, each flat and tilted ±1.5°. High target stems/beams and horizontal notation branches survive. Genuine wide and comparable-width cross-staff musical figures remain complete and ambiguous. Candidate 1 fails the wider-bracket fixture; candidate 2 fails the reduced-resolution fixture. The existing native planner suite adds 83 passing assertions.

The implementation and fixture hashes, exact run conditions and compact metrics are recorded in `connector-separation-v3.json`. Full inventories and plans are in `.build/qc-algorithm-audit/`. An initial concurrent staff-detector experiment introduced title-page false positives; those results were superseded by the controlled run using the frozen original detector.

## Remaining work

All 20 remaining whole-neighbor bands, representing ten system pairs, were inspected in the original source. None requires an entire neighboring staff for target notation. Some slurs, dynamics and high/low notes overlap vertical ranges, so small neighboring fragments remain appropriate. The case-by-case observations and source-image hashes are in `connector-residual-source-review.json`.

At p28s1, a magnified original source confirms missing barline ink inside a correctly located staff core: 46 of 56 sampled rows are supported (82.1%), below the unchanged 88% rule. A later fix must establish independent evidence that the interrupted ink is a printed connector. Lowering the general threshold or trimming ambiguous components blindly would not be justified. Candidate 3 is a verified improvement, not a claim that unattended extraction is complete.
