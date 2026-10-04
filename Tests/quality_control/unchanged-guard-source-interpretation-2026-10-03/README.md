# Supplementary interpretation of unchanged crop-guard failures

**No intended music was found outside the current p35 system 1 Violin I or p22 system 3 Cello crop.** All three frozen geometric guard failures remain failures. No rectangle, check result, algorithm or production file was changed.

I inspected the original PDF full-width source before the parent’s edge panels, then measured the excluded strips and vulnerable marks at 720dpi. These physical pages are **not rectified**: page 22 is 427×615pt and page 35 is 426×614pt. Coordinates are top-down PDF points. Counts below are rendered dark pixels (`gray < 190`), not unique pixels in an embedded source bitmap; the `<254` check gives the same whole-excluded counts.

| Unchanged crop | Guard deficit | Actual source ink outside |
|---|---:|---|
| p22 system 3 Cello, bottom 447.655611pt | Guard ends 448pt | 348 wholly excluded dark cells plus 84 cells crossed by the edge. All belong to the next system’s Violin I sharp/high note and rehearsal-A apex. |
| p22 Cello right lower beam/hairpin landmark | Guard ends 448pt | **Zero** wholly or partially excluded dark cells. Local ink ends 445.666667pt, about 1.989pt inside the crop. |
| p35 system 1 Violin I, bottom 66.382421pt | Guard ends 68pt | 5,546 wholly excluded dark cells plus 233 cells crossed by the edge. All are connector/barline continuations or the neighboring Violin II’s rising beams. |

The p35 Violin I clef tail is `[45,61.333333,49.5,64.333333]`, over 2.049pt inside the crop; the rightmost first-violin beam ends 62.583333pt. All target heads, ledger lines, upper accents and slurs also remain inside the existing crop in the full-width source.

`review.json` records the unchanged failure outcomes alongside this interpretation. `pixel-measurements.json` lists each excluded column group with point bounds and rendered pixel counts. `local-source-bounds.json` is observational measurement only; none of these smaller ink bounds replaces an original guard. `source-bindings.json` binds the original score, baseline, candidate and immutable guards.

The `*-original-fullwidth-source.png` and isolated-mark images show unmodified source. In `*-excluded-pixels.png`, blue is the unchanged crop bottom, gold is the unchanged guard bottom, and red marks wholly excluded dark source pixels inside the guard. The partially intersected boundary-row counts are reported separately. These overlays are review evidence, not edited score output.
