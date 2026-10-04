# Whole-body filledness: p10 fermatas versus genuine heads

The three false V3 witnesses on Brahms p10 are **open fermata arches touching a barline**. A thick segment of each arch contains the accepted radius-3 disk; that local disk does not make the complete shape a filled notehead. The full footprints occupy approximately half their convex hull, while the measured genuine heads occupy substantially more. This is source-shape evidence, not complete musical-symbol recognition.

No classifier, crop or production code was changed. The measurement protocol was written before computing these statistics. Exact V3 Native SHA is `6f8a9200324702cc6579dba7455e7c6a0e2686cf6ab1e4606309d48e9196010c`. The separately logged p10 replay is analysis/plan-identical to that candidate.

## Exact area convention

For each accepted body, let **S** be the union of its logged residual off-shaft pixels and logged **original** shaft-body pixels. Every pixel is the half-open unit square `[x,x+1) × [y,y+1)`. Compute the convex hull **H** of all square corners. Filledness is `|S| / area(H)`, with unique-pixel count as the numerator and continuous polygon area as the denominator. No dilation, filled scan gap, ellipse or bounding-box area enters this ratio.

| Exact body | Off-shaft pixels | Restored original shaft | Unit-cell hull area | Filledness |
|---|---:|---:|---:|---:|
| p10 arch `[1600,276,1634,293]` | 170 | 27 | 392.5 | 0.501911 |
| p10 arch `[1600,401,1634,419]` | 184 | 27 | 419.5 | 0.502980 |
| p10 arch `[1600,528,1634,545]` | 183 | 27 | 411.5 | 0.510328 |
| Case 176 upper head | 78 | 24 | 110 | 0.927273 |
| Case 176 lower head | 78 | 24 | 110 | 0.927273 |
| Existing `music-filled`, scale 0.5, upper head | 24 | 7 | 37 | 0.837838 |
| Existing `music-filled`, scale 0.5, lower head | 26 | 7 | 38.5 | 0.857143 |

Counting pixel centers inside the hull is a **different convention**: the two half-scale ratios become 0.794872 and 0.825. These definitions must not be interchanged around a cutoff. The table and proposed native calculation use unit-square area throughout. The per-body reported off-shaft box can exclude shaft columns; hull construction uses the complete union, not that box.

All seven shapes have zero enclosed white holes under white-4/black-8 connectivity. Hole count alone therefore does not distinguish them. The p10 hulls contain 199, 210 and 207 exterior-connected white pixel centers: their white interiors are visibly open. Genuine case 176 footprints have no internal row gaps; their smaller hull deficits come from contour/raster geometry. The half-scale heads also have no internal row gaps.

## Source membership and branches

All logged p10 and case 176 union pixels were checked against their exact original source masks at the unchanged black threshold 190. The p10 fermata dots are separate original off-shaft components of 33, 33 and 39 pixels, excluded from the accepted arch footprints. Their dots must not be silently combined with an arch to manufacture filledness.

No p10 arch pixel inside its measured box was removed by the thin-path explanation. Its concavity is present in the source. In case 176, two source pixels per body inside the measured box are excluded as part of the continuing staff-line path. Restoring all original black pixels in that box produces a slightly different hull and filledness, approximately 0.920354; the filled body remains clear. This limited observation does **not** prove that path removal cannot make other damaged or tied heads less convex.

Half-scale metrics use the exact logged native 360×320 footprints. The original fixture is 720×640; no guessed resampling was used to reconstruct native grayscale. Existing independent body-membership verification is separate from this shape calculation.

## Bounded conclusion

An additional whole-body filledness gate can test the entire shape after the existing disk check. It must use the complete residual-plus-original-shaft union and the explicitly fixed hull convention. The measurement did not select a threshold. After receiving these results, the parent authorized a separate V4 experiment carrying the earlier 0.82 filledness requirement onto this complete body; that implementation and its outcomes are outside this report.

Seven measured bodies do not establish semantic completeness or broad tolerance to damage. Hollow heads, uncertain continuing branches, thick glyphs and scan breaks need their existing preservation tests. A failed new-body certificate must not authorize cropping away existing target music. No combined run or production promotion follows from this report.

`measurements.json` contains all seven exact shape records and source comparisons. `witness-inputs.json` preserves their literal logged pixel/run inputs. Source hashes and observer invariance are bound by `source-bindings.json`. The seven overlays show original source or exact logged masks on the left; green residual body, blue original shaft and red hull void on the right. `measure.py` reproduces the descriptive calculation from the hash-bound logs.
