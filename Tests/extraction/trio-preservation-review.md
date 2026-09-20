# Brahms Clarinet Trio, Op. 114 — extraction author review

**Scope:** Clarinet in A, movement I, PDF pages 1–3 only; all 11 systems, bars 1–62. This is an excerpt, not a complete movement. Source page 4 begins bar 63.

**Status:** Author visual review complete. A separate reviewer subsequently passed all 11 source-to-output comparisons in `Tests/extraction/trio-independent-review.md`; the published `output/pdf/trio-preservation/review.json` verifies against that final generation. No recipe corrections were needed.

- Source SHA256: `db43702c5b9b64069748f90339aeeb6f4e4d5736696b59dd8e14a58780c5e19d`.
- Recipe: `Tests/extraction/trio-preservation-recipe.json`.
- Temp output: `.build/extraction/trio-preservation/Clarinet in A.pdf`.
- Inspected draft PDF SHA256: `a6ac336fe9320053c541f38880695c913af8161e24dd908ae1262928a1a41fd1`.
- Policy: `preserve-target`; zero exclusion/whiteout rectangles. Original source scan and angle remain unchanged. All protected regions use original top-down PDF points.

## Detection and manual correction

The Python analyzer found 12, 16 and 16 staves: all 44 match the source. Each system has Clarinet in A, cello and two piano staves. The target indices are 1/5/9 on page1 and 1/5/9/13 on pages2–3. No staff-count corrections or invented/tacet systems were needed. Exact target identity was checked from the printed opening label and every source system. Detection angles (−0.2°, +0.2°, −0.2°) are analysis aids, not export transforms.

All 11 bounds were reviewed manually. Correct detection did not establish safe crop edges: the most consequential misses were the low p at bar8, the low hairpins at bar15, the sf marks at bar37, and the high arches at bar58. Horizontal whitespace was removed only after checking the entire target line. The page2 opening crop also retains the whole original page number rather than a cut fragment.

| Band / start bar | Suggested top–bottom (pt) | Reviewed [left, top, right, bottom] | Retained neighbor notation |
|---|---:|---|---|
| trio-p1-s1 / 1 | 165.978–201.839 | [8, 157, 564, 206] | none |
| trio-p1-s2 / 8 | 374.374–410.234 | [9, 370, 564, 424] | none |
| trio-p1-s3 / 15 | 590.566–624.328 | [9, 588, 564, 638] | none |
| trio-p2-s1 / 22 | 56.033–90.455 | [35, 40, 589, 97] | present |
| trio-p2-s2 / 28 | 244.239–276.612 | [40, 240, 589, 280] | present |
| trio-p2-s3 / 33 | 422.350–458.211 | [40, 417, 589, 463] | present |
| trio-p2-s4 / 37 | 603.060–636.821 | [39, 600, 589, 651] | present |
| trio-p3-s1 / 42 | 56.333–88.456 | [13, 59, 564, 90] | none |
| trio-p3-s2 / 48 | 237.442–271.864 | [13, 236, 564, 275] | present |
| trio-p3-s3 / 53 | 419.651–452.774 | [13, 420, 564, 456] | none |
| trio-p3-s4 / 58 | 600.561–634.323 | [13, 584, 564, 640] | present |

## Per-band source comparison

- **trio-p1-s1:** Allegro, Klarinette in A, the opening signature, three written rest bars, poco f, and the high triplet arch all survive. The first staff is the clarinet; cello is the second staff and piano uses the lower grand staff.
- **trio-p1-s2:** Compared the low ledger-note descent, dim., low p with full descender, and the tied sustained low notes through the right edge. The detector bottom cut through this low-note/slur/dynamic zone.
- **trio-p1-s3:** Compared the opening low tie, both hairpins, the pp entry, upper ledger note, right-hand slur, and final rest. The original crop suggestion would lose lower hairpin ink.
- **trio-p2-s1:** Two whole-bar rests followed by the f entry, full high triplet arches, long tie and low ascending run. Small cello high-note/slur fragments remain below. Complete source page number 2 (250) retained above instead of a torn page-number fragment.
- **trio-p2-s2:** All five measures and the last chromatic run, accidentals and upper/lower slurs are preserved. A small cello high note remains below the left portion.
- **trio-p2-s3:** Ascending chromatic run, ff with full descenders, the high long tie, and low notes/slurs at the right all compared with source. Cello slur fragments/high note tips remain below; there is one complete target staff, so target identity remains clear.
- **trio-p2-s4:** Both sf markings beneath the very low ledger notes and the low opening slur are complete. The automatic midpoint boundary cut this target ink. Upper cello slurs, clef/line and note fragments remain because their heights overlap target dynamics.
- **trio-p3-s1:** Six complete written whole-bar rests, the clef and key signature survive. Source piano-system label confirms bar42; following system begins48. No fabricated multimeasure rest.
- **trio-p3-s2:** Three whole-bar rests, the next partial rest, complete p, and the high phrase slur all survive. One small cello slur crest remains below toward the middle.
- **trio-p3-s3:** All five measures, high and low slurs, and the complete long final crescendo hairpin compared with source; no target part crosses a crop edge.
- **trio-p3-s4:** High first and second phrase arches, upper ledger notes, the triplet, initial and final f, both hairpins and right-edge slur continuation remain. Cello high slur/ledger-note fragments remain below. The continuing phrase after bar62 is intentionally outside the excerpt; source page4 begins63.

## Coverage, layout and qualifications

All three original source pages, all 11 expanded source-context images, all 11 cropped strips and all three final output pages were inspected in reading order. The source was also checked beyond the crop boundaries, including target protrusions and shared markings. Opening Allegro is inside the first crop. No later tempo changes or rehearsal letters occur in these pages. Source bar numbers printed beside the piano system were independently copied into editorial labels: 1/8/15, 22/28/33/37, 42/48/53/58.

The PDF retains source-page divisions (3/4/4 strips on 3 output pages). Turns lead into two whole-bar rests at bar22 and six whole-bar rests at bar42; these are usable reference divisions, not an optimized engraving or automatic page-turn guarantee. The excerpt ends after62 with a phrase continuing on the excluded next page.

The scan is substantially cleaner than the medium-skew Brahms quartet test. Five strips have no neighboring notation; six keep disclosed cello fragments. The intended part remains identifiable as the one complete staff in each labeled strip. The original small staff size is preserved at approximately 97–98% of source width (about 12–13pt staff height), and detailed previews are readable. A larger-paper or newly engraved performance part would be a separate layout task; this review does not claim a newly enlarged performing edition.

The first build was visually reviewed and then rebuilt once: page2/system1 was expanded upward to keep the whole source page number, and the standalone ff/high-tie protected landmark coordinates for page2/system3 were corrected to the actual source marks. Its broad target envelope and crop already contained both. No target crop was tightened to remove neighboring notes; no cleanup masks were added.

Published independently reviewed PDF SHA256: `33c5887955402accf520cba484449d281a0914d7b7a2585a3aded817fd6132fd`. The temp author-review hash above belongs to a separate build of the same recipe; PDF generation metadata can change bytes without changing the crop geometry.
