# Independent curved-harmonic ownership audit

2026-09-27. Production code was read-only. This isolates the structural-connector change; the corpus and positive-barline review belong to the accompanying crop-agent report.

The reported 104 failures in the original 135-case curved-harmonic grid were not 104 lost stems. Instrumenting every connector cut at the musical figure's position found only two actual cuts. The other 102 failures retained a component owned by both staves whose left edge extended into curved staff-line remnants. The old test required `bounds[0] > 0.5`; it therefore conflated crop cleanliness with target preservation. The original logs and strict-width results remain recorded. Wide retained staff fragments remain a quality defect.

The two genuine baseline cuts occur at raster scale 0.5, bow 0, with tilt -1.5 or 0 degrees. Both take the **shifted five-line fallback**, with fitted shifts of +5 and -5 pixels relative to page tilt, at a six-pixel staff space: one-line ledger aliases at +/-0.8333 spaces. Neither uses the unshifted core shortcut. The analyzer deletes 33 consecutive interior stem rows in these cases, and both resulting part crops omit part of the source musical figure.

The 0.65 ratio candidate and the replacement alias-uncertainty candidate both prevent those two cuts. The latter trusts the local fit only when `abs(bestShift) + 2 < staffSpace`, otherwise requiring continuous staff-line evidence. The two pixels represent the existing line-search/raster uncertainty. This audit does not claim that formula is a universal proof; it tests its observed decisions, including fits on both sides of 0.65.

## Direct source and crop evidence

The independent source mask is defined before analysis from the fixture's actual notation: stem x450..<453, y212..<387, plus upper/lower noteheads x443..<459, y212..<220 and y379..<387. Each column receives the fixture's explicit skew and bow transform. Its bounding box comes from those source pixels, not detected components or planned crops.

For each case the probe records:

- Native foreground pixels from that source mask retained or removed during analysis, and fully absent stem rows.
- Source notehead anchors and components that jointly own both anchors.
- Every actual musical-connector cut, its path and fitted pixel/space offsets.
- Both native planned crops and strict containment of the entire independently transformed source musical envelope, without geometric tolerance.

The expanded principal set contains 336 cases: four raster scales (0.5, 0.6, 1, 1.5), three tilts (-1.5, 0, 1.5 degrees), and 28 bows including quarter-pixel increments around the disputed fit region. The complete parameters and source helper are in `direct-fixtures.swift`.

| Principal 336-case result | Baseline | 0.65 ratio guard | Alias uncertainty |
| --- | ---: | ---: | ---: |
| Musical connector cuts | 2 | 0 | 0 |
| Cases with missing interior stem rows | 2 | 0 | 0 |
| Cases with an incomplete source envelope in a target crop | 2 | 0 | 0 |
| Strict-width failures | 266 | 264 | 264 |
| Cases without one component enclosing both notehead anchors | 10 | 8 | 8 |

Thus all 672 planned target crops in the alias candidate contain the full source musical envelope. Only the two genuine baseline failures change crop geometry or target-pixel loss. The eight remaining endpoint-owner diagnostics are pre-existing half-resolution staff-line-removal effects: part of an endpoint becomes detached in analysis, but the original source notehead/stem envelope is still fully inside both output crops. Analysis pixels are not export whiteouts; nevertheless these detached endpoints are recorded as a recognition limitation, not silently declared perfect ownership.

The alias candidate's recorded local fits include accepted ratios 0.611, 0.667, 0.694, 0.722, 0.75 and 0.778, depending on the absolute pixel uncertainty. The musical stems still never qualify for a connector cut. This provides evidence around the former 0.65 boundary instead of tying the conclusion to nominal bow amplitudes.

## Additional low-resolution limit

A further 252 cases use raster scales 0.25, 0.3 and 0.4 (staff spaces 3, 3.6 and 4.8 pixels). All three versions make **zero** musical connector cuts there. However, 103 cases already lose sufficient endpoint evidence during low-resolution analysis that the upper planned crop fails the exact full-envelope check: 61 cases at 0.25, 31 at 0.3, and 11 at 0.4. The maximum source-envelope shortfall is eight source points. Fifty-four of these lower-resolution cases also contain interior stem gaps after analysis.

Those failures, their pixel measurements and exact crop rectangles are retained in the case data. They are identical between baseline, ratio guard and alias candidate. They require separate resolution/line-removal work before claiming robust preservation at those low staff resolutions. They are neither new connector regressions nor clean passes.

Across all 588 cases per version, the alias and 0.65 candidates have identical crop geometry and target-pixel losses. The only crop changes relative to baseline are the two repaired half-resolution ledger aliases.

## Artifacts and reproduction

`summary.json` gives counts and changed cases. The three `*-cases.json` files preserve every measurement, including failed width checks and low-resolution envelope failures. `baseline.log` and `guarded.log` retain the original 135-case connector instrumentation. `all-fixtures.swift` runs all 588 cases; the instrumented analyzer copies record decisions without changing the analyzed behavior. Compile an entry fixture with its instrumented analyzer plus the production `StaffBandDetector.swift` and `ScoreExtractionPlanner.swift`. Scratch binaries and full compile logs remain in `.build/qc-harmonic-independent`. `provenance.json` records tested source and binary hashes.

This independently supports the alias candidate's preservation behavior over the stated ranges. It does not substitute for the separate real-score crop/notation review, positive connector tests, export/pagination checks, or unresolved low-resolution work.
