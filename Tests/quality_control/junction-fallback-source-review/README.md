# Junction fallback candidate: reject for production

This narrower candidate repairs a real omission mechanism but still makes the reviewed Brahms parts worse. Requiring vertical junction evidence on the old `throughBothCores` shortcut preserves 41 of 48 source-defined near-edge musical stems, compared with zero preserved by the current baseline. The same change increases whole-neighbor staff occurrences from **9 to 27** in the exact corrected Brahms score. Production and delivered PDFs were not changed.

## Scope and evidence

- Candidate analyzer SHA-256: `bb05eb3cded5b8bc268ca3d96eda6a70463ceb167ce3cdf4cbbafe53ca745616`.
- The 88% core-support requirement, continuous-line identity tracing, and alias-distance guard are unchanged. The candidate applies the existing vertical-junction check to both routes, attempting the existing local staff fit if the global junction check fails. There is no attachment veto.
- A fresh build using frozen Core sources passes **755 existing crop checks**. The source file hash is `1e9e3bfe5cb655338398aff4c3266a577adcc4c3ba8874179214c110af349296`. `755-build-binding.json` binds the exact source copies and executable. An initial supplemental rebuild accidentally selected the historical 503-check test copy; it is retained in scratch under `existing503`, and is not counted as the 755-check result.
- **85 saved source-envelope checks pass unchanged** across the 93521 and 09200 Brahms editions, including the independently frozen p24 guards, earlier connector guards, all 56 recently reviewed raw crops, and the three corrected-coordinate smaller-edge guards. These are finite source regions, not a proof that every mark in either score survives.
- The candidate was run with the **same nine saved rectifications** as the delivered draft: physical pages 2, 7, 17, 19, 23, 28, 34, 38, and 39. Staff positions, source/raster dimensions, assignments, and rectification values remain identical. No settings were re-estimated.

## Musical preservation remains incomplete

The 48 near-edge controls put real noteheads at both ends of a cross-staff stem, 2–5 source pixels inside the outer staff boundaries. The oracle requires both planned crops to include the whole independently defined source envelope.

| Raster scale | Staff spacing in analysis pixels | Preserved | Failed |
| --- | ---: | ---: | ---: |
| 0.5 | 6 | 8 | 4 |
| 0.6 | 7.2 | 9 | 3 |
| 1.0 | 12 | 12 | 0 |
| 1.5 | 18 | 12 | 0 |

All three tilts fail for inset 2 at scales 0.5 and 0.6; inset 3 also fails at scale 0.5, tilt −1.5°. The failed crops omit remote noteheads and substantial stem length, not merely the safety margin of an envelope. Twelve broken-barline controls remain correctly separated, but those fixtures do not reproduce every real interrupted barline in Brahms.

`adversarial-summary.json` and the complete 60-case result retain the seven failures.

The existing expanded **336-case** grid is a necessary counterexample to describing all remaining failures as low-resolution ambiguity. It includes insets 0–6 and four notehead styles: both rectangular heads, upper only, lower only, and elliptical heads. **122 of 336 cases fail**, including **48 failures at normal 12/18-pixel staff spacing**. All 96 cases with inset 0 or 1 fail across the four resolutions. These fixtures contain musical stems with noteheads even when their endpoints happen to align with the outer staff lines; barline-like endpoint geometry is not sufficient evidence to cut them.

| Raster scale | Preserved in expanded grid | Failed in expanded grid |
| --- | ---: | ---: |
| 0.5 | 46 | 38 |
| 0.6 | 48 | 36 |
| 1.0 | 60 | 24 |
| 1.5 | 60 | 24 |

`expanded-summary.json` and `expanded-junction.json` preserve every failure. The 336-case baseline was not remeasured in this run, so these are absolute candidate failures, not a newly introduced failure count. Passing the narrower 24 normal-resolution near-edge cases does not establish normal-resolution musical safety.

## Actual score output gets wider

The raw 93521 comparison changes **22 of 604** crops, taking whole-neighbor occurrences from **10 to 28**. All 22 changed crops contain their pre-frozen local target guards.

With the exact saved rectifications, **20 of 604** crops change, including four on corrected pages. Whole-neighbor occurrences increase **9 → 27**. Eighteen changed crops each gain a complete neighboring staff; none removes an existing whole neighbor. The other two changes are less than half a PDF point at one crop edge. All five smaller-edge crops are covered by pre-frozen guards and pass them. All 20 corrected source strips were visually reviewed in four contact sheets.

Whole-neighbor occurrence means that all five detected lines of a foreign staff are inside a crop, excluding its assigned target staff IDs. The source strip images confirm that these are visibly unnecessary adjacent parts, not just a counter artifact. Shared headings, endings, and navigation still require their separately reviewed metadata; this experiment does not replace that work or export new final parts.

## Why the real barlines are rejected

A logging-only copy of the exact candidate checks four real source pages. The failed junctions responsible for the reviewed adjacent-pair regressions occur at **outer** staff lines:

- p5, Viola/Cello: Cello bottom line, predicted raster row 612, across six interior barlines.
- p9, Viola/Cello: Cello bottom line, predicted rows 1222…1216 after skew, across six barlines.
- p25, Violin I/II: Violin I top line, predicted rows 177 and 175 at two right-hand barlines.
- p31, system 2, Violin I/II: Violin I top line, predicted row 788 at two right-hand barlines.

These are structural barlines in the original score; there is no musical cross-staff stem joining those paired parts. The current predicted-row vertical-run test fails there. The log establishes which check fails; it does not by itself distinguish local line displacement, raster thinning, and an interrupted endpoint. Simply checking only outer junctions would therefore retain these regressions.

The next bounded diagnostic must combine independently measured per-line geometry with endpoint musical-ownership evidence at these exact connectors, then test that source-based distinction against the existing 48 and 336 musical envelopes. Geometry alone cannot resolve the full-height musical counterexamples. Do not merely tune the row tolerance, relax the 88% gate, or restore a global musical-attachment veto. A new candidate must pass these preservation controls and the actual-score neighbor comparison before a full 36-score corpus run is useful.

The 36-score corpus was not rerun for this rejected candidate. The current production limitations remain recorded in the near-edge-musical-stems report. This experiment is evidence for a real shortcut flaw and a rejected attempted repair, not a complete preservation success.
