# Quartet compact output review

The complete 25-page source yields four parts, 120 systems each, on 47 output pages (Violin I 13, Violin II 11, Viola 11, Violoncello 12). All 47 final pages were inspected in 13 rendered contact sheets, with eight 216 dpi close-ups for high rehearsal boxes/slurs, low dynamics, detached articulation and beam endpoints. Movement starts, tempo and rehearsal cues, printed gutter numbers, repeats/endings, Trio/Coda/DaCapo navigation, headers and page footers are present. No collisions or blank trailing pages were found.

This is automatic extraction followed by substantial explicit review correction. Of 480 crop rectangles, 159 remain exactly automatic and 321 are reviewed corrections: 279 address protected-envelope containment, complete neighboring staves or excess vertical context greater than 8 pt; 42 additional crops only complete an intersecting verified source cue box to avoid duplicate copied glyphs. The 121 conservative envelope failures are not 121 proven missing-note failures. Frozen source guards were never shrunk to fit output. No masks were applied.

The latest automatic baseline had 470 neighboring staff-line centers and 38 complete neighboring staves. The reviewed output has 148 centers and 0 complete neighboring staves (68.5% fewer centers). This center-based metric excludes copied cue fragments and does not prove clean isolation. Small neighboring notes, dynamics, slur fragments, occasional pieces of next-system cues and catalog text remain where their height overlaps intended notation.

Every one of 480 independent target envelopes is contained. All 624 required cue/part obligations are met: 355 original source fragments copied and 269 retained completely in main crops. Exact pixel review passes 835 regions and 77,806,936 grayscale pixels at 216 dpi with 0 final differences. The 817 directly matching regions need no normalization; 18 use an independently rebuilt original-source reference with the identical reviewed crop extent to match raster sampling phase. The untrimmed oracle’s 495,448 differing pixels remain in the report. This changes reference serialization/sampling only, not source ink or crop geometry.

The separate all-manual comparison reference also spans 47 pages and has 42 neighboring line centers, 0 complete neighboring staves, and 835/835 exact pixel matches. Its 480 rectangles are explicit reference bounds; it must not be described as an Auto result.

High-risk final close-ups checked: p5-s3-Violin I G; p9-s1-Violin I M; p12-s2-Violin I D/ritard/in-tempo; p10-s3-Violin II long upper slur; p22-s5-Viola low f; p15-s5-Cello detached low dot; p16-s5-Cello low f; p25-s2-Cello downward beam. All are complete.

Reproduction and audit evidence: `quartet-compact-auto-baseline.json` preserves the exact frozen Auto manifest; `quartet-compact-correction-report.json` records every correction and reason; `quartet-compact-overrides.json` and `quartet-compact-profile.json` are native exporter inputs. `.build/final-tight/quartet-input/inventory.json` is the native inventory snapshot. `.build/final-tight/quartet` contains the four PDFs, editable native project, manifest, hash-bound `visual-review.json`, context metrics, geometry/pixel reports and renders. The native exporter reproduced all 480 planned rectangles exactly.

Validation command:

```sh
.build/extraction-venv/bin/python tools/review_score_output.py .build/final-tight/quartet --map Tests/full_scores/brahms-quartet-tight-map.json --pixels
```

Source map SHA256: `8dbea51d4b20edc38a29e710d0a1ff64e334d7961acebc90da10af4639483dbb`
Source SHA256: `ff883e06db2bc69c5de0c45fa447795201805ecf7210b76c50168b64f0570689`
Reviewed generation manifest SHA256: `b8baf380e0b54e4f1712bbfe1aa97acb848452616461b5ba6b2d0c13a10cbf59`
Normalized manifest SHA256: `3b8f307c5fda28c400de048c083a14fcedc3ff3ae70d65c23e5ec158312b2388`

| PDF | Pages | SHA256 |
| --- | ---: | --- |
| Violin I.pdf | 13 | `b2b316edfca8094ab3b9756cf524150d5ca6e3f04d0e3baeb259dc96f6b3eeae` |
| Violin II.pdf | 11 | `9705bb6aa0b65c1d8eec93d63354278587924510e3f81fbb97eaaad3eb662fe9` |
| Viola.pdf | 11 | `a52a7e56b914a7eeb5ecad5b97ef09d1c29bab55cbd3dfe47b70751f9783ac8d` |
| Violoncello.pdf | 12 | `482fc16afd4795e2ab7b466ce4bb0c8ce91089b7a3e41e44de0fe556f5a940ec` |

## Root cross-review

The root reviewer inspected all 13 final Violin I pages in complete-page contact sheets and page 7 at full render size. Movement coverage, repeat endings, return/coda directions, final bars, page numbering and system layout were consistent. Neighboring fragments remain disclosed; no complete additional staff or output-strip collision was observed. This check did not change any PDF, crop or source guard.
