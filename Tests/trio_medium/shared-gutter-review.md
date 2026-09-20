# Independent source-gutter review — medium Brahms Trio 114012

Reviewer: app_audit. Status: all 127 bar-number identities and digit preservation pass; eight source rectangles need a right-edge cleanup before isolated copying. No rectangles were changed by this reviewer.

Source: `sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf`.

Source SHA-256: `0f617f77acf2e257973b14a8ce558e88eca877835df6fff4894419e66c871e4b`.

Reviewed rectangles: `.build/trio-auto-audit/piano-shared-gutters.json`, SHA-256 `5e9c3cb6864b68ef8cb73cadf83d2525b47a162a325a60205adaaae366eeb927`.

## Method and coverage

Freshly rendered all 127 rectangles at 5× and their original source context at 3×, inspecting every digit and edge in six contact sheets. Context extends 12 pt left, 30 pt right and 16 pt above/below each source rectangle, with the proposed crop outlined. All source system starts except the four movement openings (PDF pages 1, 12, 18, 26) are represented. This is an independent visual check of the source scan, not a comparison with prior-edition metadata.

Evidence is under `.build/trio-auto-audit/gutter-review/`: `001-crop.png` through `127-crop.png`, matching `*-context.png` files, `index.json`, six `contact-*.png` sheets, and reproducible `render.py`/`measure.py`. Target-number images and contexts on all six final contact sheets were visually inspected. The final sheets allocate sufficient width for all three-digit numbers.

All 127 labels agree with the printed source, and no digit is visibly clipped. The source's uneven ink (for example p2s4 number 37, p6s3 number 110, p8s4 number 157) is retained faithfully. The other 119 crops contain clean isolated numbers. None of the 127 clips contains a notehead or staff line.

## Eight extraneous brace fragments

These clips also include the tip of the following piano brace. The target digit is separate and complete, but isolated copying would retain an unwanted wedge or speck. The p16s2 wedge is especially visible. Coordinates below are original top-down PDF points; only the right edge needs changing. Target ink and brace onset were measured at 8× after visual source comparison. Proposed edges keep approximately 0.6–0.9 pt after target ink. Re-render after changing the rectangles to verify final rounding and digit preservation.

| Entry (1-based) | PDF page/system | Printed number | Current right | Target ink right | Brace onset | Proposed right |
| --- | --- | --- | --- | --- | --- | --- |
| 28 | 8/2 | 142 | 42.000 | 39.750 | 41.375 | 40.500 |
| 30 | 8/4 | 157 | 43.000 | 41.250 | 42.750 | 42.000 |
| 31 | 9/1 | 165 | 20.667 | 19.500 | 20.500 | 20.100 |
| 37 | 10/3 | 195 | 32.000 | 29.375 | 30.875 | 30.100 |
| 39 | 11/1 | 205 | 21.000 | 18.375 | 19.750 | 19.100 |
| 40 | 11/2 | 212 | 22.000 | 19.500 | 20.875 | 20.250 |
| 59 | 16/2 | 42 | 38.000 | 35.125 | 36.500 | 35.900 |
| 96 | 25/4 | 200 | 28.333 | 27.125 | 28.000 | 27.700 |

## Destination limitation

This review certifies source-fragment identity and complete digits, with the eight stated cleanup issues. It does not certify an as-yet-unreviewed final native placement. The final Clarinet/Cello PDFs must still be checked for annotation-row placement, readability, and duplication only when the same number already survives in the main crop. Native source-marking layout reserves a separate row and rejects overlapping horizontal fragment spans; those structural rules do not replace final visual inspection.
