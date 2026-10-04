# Deskewed-page analysis resolution: held outside production

Matching the corrected-page analysis resolution to the ordinary native renderer does **not** safely solve the Brahms cropping problem by itself. It removes three existing whole-neighbor inclusions but creates two others, and clips the upper serif of the printed `Vivace` heading. The change remains private; the app and published parts are unchanged.

## Bounded measurement

Whole-score Auto currently renders corrected pages at a fixed scale of 2.5. On this score that produces roughly 1068×1538 pixels. Ordinary page analysis and the rest-detection workflow instead use a maximum of 1800×2600. The private measurement renders directly from the immutable source PDF at that latter scale, retaining all nine saved rectifications and the unchanged production detector/planner. It does not upscale the previous small raster.

The protocol was frozen before execution. Exactly nine corrected pages—2, 7, 17, 19, 23, 28, 34, 38 and 39—are freshly rendered and analyzed. The other thirty previous page analyses are retained unchanged for the complete plan comparison. This is **not a fresh 39-page run** or a PDF export.

Staff counts, ordered assignments and all 604 band identities remain unchanged. All 140 corrected-page crops change to some degree with the new raster geometry. Twenty-eight contract by more than two source points. The independent reviewer inspected each of those source contexts and compared 56 frozen guard/landmark checks: the same 53 pass; three existing failures on unchanged pages remain failures.

## Actual gains and regressions

| Region | Result |
|---|---|
| p28 system 1, Violin II | Removes the complete neighboring Violin I core. |
| p38 system 1, Viola and Cello | Removes the complete neighboring core from both crops while retaining the frozen target envelopes. |
| p28 system 2, both Violins | Introduces two oversized crops containing each other's complete staff. One ordinary component bridges both owners; this is not caused by the private musical-span experiment. |
| p2 system 1, Violin I | The raised upper edge clips the top serif of the printed `Vivace`. Independent comparison confirms real dark heading pixels above the cut in both the new raster and the existing corrected-source PDF. |

The aggregate whole-neighbor count falls from seven to six, concealing the two new problem crops. No other target-note or local-mark omission was observed in the 28 large contractions, but this bounded inspection does not certify every smaller change or the entire musical output. The unchanged native inventory used here contains no shared-marking copies; a separately reviewed heading copy cannot be assumed to repair the clipped word automatically.

See the [independent source review](../consistent-resolution-independent-2026-10-03/README.md) for exact heading pixels, fixed source obligations and the magnified edge comparisons. [comparison.json](comparison.json) records all changed bands. `source-and-results.zip` contains the frozen native sources, measurement and comparison programs, original inventory with its corrections, exact profile, logs and source-review panels. Source raster hashes permit verification after rerendering; rebuildable binaries and full-page rasters are omitted.

A future resolution change needs to address the real source-ownership and heading-boundary regressions as well as improving pixel detail. No broad margin, weakened source guard or selective per-page use of the favorable result is introduced here.
