# Ave compact final independent review

**Verdict: pass with disclosed residual source context.** This candidate uses 56 native Auto rectangles and 8 explicit source-reviewed local crop corrections. It is not an all-automatic clean-isolation result. All eight final PDF pages were viewed after the independent 64-band source review. No final files were published by this task.

The duplicate lyric rows and broad adjacent staff regions are gone. All own notes, lyrics, slurs, directions and figured bass remain. There are 12 single neighboring staff-line centers, 0 whole neighboring staves, and several isolated overlapping arcs/glyph tips. Two complete publisher copyright lines remain in Basso ed Organo. These residuals are accepted under the requested preserve-target policy.

All 8 PDFs are one US Letter portrait page, with 8 systems each. Main crops span source x38–578 pt and render 516 pt wide; staff heights are 14.46–14.62 pt. No masks were used. The 64 own-notation guards and 42 copied source-number fragments pass at 216 dpi: 0 differing pixels across 10,667,192 pixels after independent full-source CoreGraphics vector serialization normalization. The report retains the 301 raw vector-serialization differences. These checks verify reviewed regions; they do not discover every note automatically.

| Part | Final observed result |
|---|---|
| Soprano | Eight systems preserve all own notes, high phrase arches, lyrics and printed measure numbers. No whole duplicated lyric row. Opening adjacent sotto voce and a single following line/arch on p4s1 remain disclosed source context. |
| Alto | Eight systems preserve low ledger notes, all lyric syllables/extenders and the final long tie. The p2s2 whole duplicated Soprano lyric row is removed by the native hyphen ownership fix. Tiny preceding glyph bottoms and small clef/slur fragments remain at some edges. |
| Tenore | Eight systems preserve octave-clef 8, complete lyrics and high long arches. Four local crop corrections remove separate lower Basso note groups. The native fix removes the p3s2 duplicated Alto lyric row; all final lyric syllables remain. Single neighboring line/arc fragments and an opening adjacent sotto voce remain. |
| Basso | Eight systems preserve complete own lyrics, slurs, chromatic notes and final rests/bar. No whole duplicated Tenore lyric row. Opening neighboring Adagio and an isolated high arc share the lyric-height envelope; a complete editorial Adagio is also shown. Final strips retain tiny preceding glyph bottoms. |
| Violino I | Eight systems preserve own Adagio/sotto voce, low ledger notes, long slurs and final trill/grace notes. Opening Basso lyric fragments overlap the required own Adagio range. A few following top lines and isolated long arches remain; no large adjacent staff area remains. |
| Violino II | Eight systems preserve low ledger notes, low slurs and final long tie. The p3s1 local correction removes several preceding VlnI low noteheads/bows. Isolated neighboring slur arcs still overlap target height, especially source p3, and some single following line/clef fragments remain. No broad Viola staff region remains. |
| Viola | Eight systems preserve clefs, accidentals, low ledger notes and full phrase slurs. Three local corrections remove substantial neighboring note groups. Isolated neighboring slur arcs and the small overlapping VlnII head/slur fragment at p2s2 remain. Opening adjacent tasto solo and a few single bass top-line fragments remain. No broad bass staff region remains. |
| Basso ed Organo | Eight systems preserve the two-line instrument label, tasto solo/sotto voce, all multi-row figured bass, altered figures and continuation lines. Complete publisher copyright lines remain at p1s2 and p3s2 under the saved 9-staff-space lower-padding setting. There is no large neighboring staff region. The final figures fit above the footer. |

## Explicit local corrections

The original Auto manifest was preserved byte-for-byte before derivation. All eight corrections retain the independently reviewed target guards and latest automatic horizontal edges. The remaining 56 rectangles are exactly unchanged.

| Band | Source top–bottom, pt | Reason |
|---|---|---|
| p1-s2-tenore | 525.65–560.71 | Removed clearly separate following Basso right-side notehead/slur group. |
| p1-s2-viola | 676.42–704.88 | Removed separate neighboring low ledger noteheads/bows and following bass head tips. |
| p2-s2-tenore | 502.38–538.39 | Removed clearly separate following Basso entry-passage noteheads/slurs. |
| p3-s1-viola | 325.08–357.67 | Removed separate upper VlnII low-note fragments and lower bass noteheads/top line. |
| p3-s1-violin2 | 290.73–328.99 | Removed preceding VlnI low ledger noteheads/bows; target chromatic notes and low slurs remain. |
| p3-s2-tenore | 518.32–554.82 | Native lyric fix had removed the duplicated Alto row; local crop additionally removed the separate lower Basso notehead group. |
| p3-s2-viola | 662.31–694.09 | Removed separate neighboring upper/lower notehead groups; own low ledger note and high phrase arches remain. |
| p4-s1-tenore | 169.44–207.65 | Removed following Basso top line and several noteheads/long arch without shortening own long phrase arch or lyric line. |

Manual names/Lyrics settings, horizontal trim, reviewed system association and 42 copied source-number fragments are setup/metadata, separate from the eight explicit rectangular corrections. The native lyric-row fix is responsible for removing the full duplicated Alto/Soprano rows; the Tenore p3s2 local correction then removes the separate lower Basso group. No duplicated bar-number glyph was observed across the 56 numbered strips.

Total source strip height: 2783.42 pt, 235.64 pt above the separate 64-rectangle manual reference. Retained source-overlap fragments are described per part and per band in `visual-review.json`.

Output: `.build/final-tight/ave`. Independent full-page and source/output images: `.build/final-tight/ave-independent`. Frozen native sources and input snapshots: `.build/final-tight/ave-inputs`. Owned reproducible settings: `Tests/full_scores/ave-compact-profile.json` and `Tests/full_scores/ave-compact-overrides.json`.

Final manifest SHA256: `4cb6b2b47b0934e71c2a6c29af551ffcbde920ffdbdc6142cadb357797daf974`.
Original Auto manifest SHA256: `3a261641667617d129296d8d94b43d0deb78eec5e13b28d3bb8a0b6608a79c1b`.
Source-map SHA256: `57408271c90103e87171de618ad14d19e4e719677f2cfafbfdf3c8bf5a5c925d`.

The final visual review binds all eight PDF hashes plus source, source map, manifest, normalized manifest, geometry report and pixel report. Any content/geometry change requires a fresh review. Every part is one page, so performance page-turn choices were not assessed.

## Reviewed PDF hashes

| Part | SHA256 |
|---|---|
| Soprano | `41900e28a8ff3ce14adf2a27db3c6c05388794d7b2627a4de5db1ccea6b25f5e` |
| Alto | `20ed2653d55e5be40d36421e4d0818a19ae59bcf74bbecdf1c7655d2ea83d232` |
| Tenore | `c991300d2d69558c7cd6bbeee715428d3aa498460d70bdd74d857e8af0dc75d2` |
| Basso | `e77608d4bf85712754bc9a3d5230c7c6c9cf8a4e2c95f5aa42745ef32c542d5a` |
| Violino I | `b736f220baef31fa27852a88aab57b21412e5b1fa7bfe9ef68a22b6e23979e06` |
| Violino II | `58ea4a93a81d5df0f78ef58003905cb214bbea9ac625dc8f9c8e0aed2331e52f` |
| Viola | `23305e4ecf90abb13e8cfdbec7d702bcd0f9682a2a9c6525a0cf168c00a470cb` |
| Basso ed Organo | `1282b2d6b542282fcd5fdddcd5ca472b45bece7c535736b81af7323f9979a8aa` |
