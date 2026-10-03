# Independent ending export review

**The added ending copies preserve the checked markings and their horizontal placement, but these exports are not a clean final result.** All five Schumann Piano rows duplicate endings already printed above the Piano. A sixth visually doubled set appears in the Schumann Cello crop because it retains a neighboring Piano bracket. No new music clipping, overlapping systems, or off-page content was found in this bounded comparison. Production and export inputs were not edited.

## What was independently checked

The review covers all **13 parts** from Brahms quartet editions IMSLP242312 and IMSLP09200 and Schumann quintet IMSLP06822. It compares complete PDFs and placement manifests from `before-endings/` and `with-endings/` under `.build/ending-corpus-2026-10-03/`.

The controls contain **155 pages**, and the ending exports contain **157**. Schumann Cello grows from 11 to 12 pages and Piano from 26 to 27; the other 11 page counts remain unchanged. **78 page images change**. All 78 candidate pages were visually checked at page-layout scale in five contact sheets; all **26 added copied rows** were checked as separate close-ups against original source contexts and no-ending controls. The three Violin I parts retain their original source endings and receive no new copy.

The original source was rendered independently with Poppler at 216 dpi. Seven full-width source contexts, representing 12 individual ending marks, were reviewed with rulers. Numbered source-pixel components isolated complete bracket lines, hooks, numerals, and dots, excluding nearby note, slur, staff-line, accent, and triplet components. Those measurements were frozen before inspecting export placement manifests. They are independent source measurements; this was not fully blinded because detector metadata had been visible when locating the source systems. Preliminary exploratory ROIs that included nearby music or truncated an endpoint were discarded before freezing the final component-based guards.

## Preservation and placement result

- All 26 copied rows contain the corresponding independently measured source-mark guard. All seven original Violin I owner rows also contain their guards.
- Every copied mark uses the target strip's exact source-to-output horizontal transform: maximum horizontal offset error is 0 points; maximum scale error is below `4.5e-16`.
- Every added copy ends 4 points above its music strip. No copied row overlaps its target music or the preceding system.
- Every music band ID, source page, source crop, staff assignment, and staff-line position is unchanged. Eight destination rectangles differ by less than `0.000014` PDF point through existing page-fit floating-point rounding; these are not meaningful changes in scale or crop.
- Full-page review shows changed system spacing and pagination without new clipping or collisions. This does not certify that pre-existing crop choices preserve every note throughout all three scores. Wide crops, neighboring music, and pre-existing source fragments remain visible.

## Duplicates and extra ink

The five true Piano duplicates are independently visible in both the original source and the no-ending controls:

| Schumann source row | New Piano output page |
| --- | ---: |
| p6, system 1 | 3 |
| p6, system 2 | 3 |
| p16, system 3 | 8 |
| p18, system 2 | 9 |
| p20, system 3 | 10 |

At **Schumann Cello p18, system 2 / output p4**, the unchanged music crop extends to source y406.13. Its own staff lies around y371–381, while a Piano ending printed above the next staff around y405 remains inside the bottom of that crop. The new top copy therefore creates two visible sets. This is a neighboring-instrument mark retained by a wide crop, not evidence that the Cello itself has a separately printed local ending. A local-counterpart rule must preserve that distinction.

At **Schumann p20, system 3**, the source rectangle containing the top-staff first-ending numeral and bracket also contains portions of the Violin I slur, notes, triplet and dynamic area. These fragments appear in the added row in Violin II, Viola, Cello, and Piano. They do not overlap target music, but are visibly extraneous. Source-faithful rectangular copying cannot remove them merely by tightening the rectangle without risking the required marking.

No new incorrect part/system assignment or horizontal bar alignment was found in the 26 added rows. The broader detector audit's seven missed pairs remain a separate known limitation; this output review is not an independent whole-score recall audit.

## Evidence and next step

`independent-comparison.json` records all 13 part hashes, 26 copy placements and 78 changed pages. `frozen-source-mark-guards.json` and `owner-source-checks.json` retain the independent completeness checks. `review-verdicts.json` maps every copied row and changed page to the visual review. Source and representative duplicate images accompany this report; all close-ups and contact sheets remain in `.build/ending-corpus-output-independent/`.

Before accepting these exports as finished, suppress copies where a complete corresponding ending is already printed above the target instrument. Keep the neighboring-Piano-in-Cello case separate, and retain the existing source guards and full-page comparisons when testing a fix. The extra p20 source fragments and the broader missed pairs must remain explicit limitations.
