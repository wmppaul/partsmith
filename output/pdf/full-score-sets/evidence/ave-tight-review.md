# Ave tight source review

All 64 source bands (four pages, eight parts, eight systems per part) were independently inspected twice: first with wide neighboring context, then at proposed tight boundaries with outside-edge context. This is a source-envelope review; no new compact output receives a preservation or layout pass here. The prior finalized output review is deliberately not inherited.

The new `ave-tight-map.json` contains fresh own-notation guards, detailed observations for every band, proposed source crops, staff geometry, and the exact neighboring objects that overlap each envelope. Original `ave-map.json`, production code, and delivered PDFs are unchanged.

- Proposed total band height: 2547.09pt, versus 4466.85pt before: **42.978% less height**.
- All 64 proposals avoid every neighboring staff line. They retain all source-reviewed own notes, rests, clefs, keys, lyrics, dynamics, slurs, ledger notes, and figured-bass rows.
- 37 proposals have no neighboring ink observed; 16 retain isolated fragments only in the nominal safety margin; 11 have neighboring ink within the conservative own-ink envelope. Those 11 cannot be called clean rectangular isolation.
- Nominal margin is 1.5pt. Guards add 0.25pt for path stroke and edge sampling, leaving at least 1.2pt between the guard and proposed vertical edge after outward rounding.
- Horizontal recommendation is x38–578pt. Complete staff strokes occupy approximately 39.79–576.25pt; opening instrument labels begin beyond x45. Staff-group brackets do not establish individual-part bounds.

The source is a digital PDF. Embedded glyph-outline and Bézier measurements support the visual observations, but are not an automatic musical ownership oracle. Low Violin II slurs on page 1/system 2 and low Violin I note/slur material on page 3/system 1 were explicitly reassigned after source inspection. The native algorithm must retain those targets even when they approach a neighboring staff.

## Important detached or overlapping targets

| Source band | Own notation requiring preservation |
|---|---|
| p1/s1 Violin I | Adagio y274.74–282.72, above staff top291.26; Basso lyrics share this vertical region. |
| p3/s2 Alto | Low Esto nobis lyric/extender reaches y517.13, below staff bottom499.89. |
| p1/s1 Basso ed Organo | Lowest figured-bass row reaches y440.80, below staff bottom410.28. |
| p3/s1 Violin I | Low ledger note x188.54–194.02 reaches y290.948; its slur x192.10–212.07 reaches y293.687. |
| p1/s2 Violin II | Two low own slurs near x335–353 and 374–391 reach y676.28. |
| p4/s1 vocal parts | Long high slurs extend substantially above the staff; complete lyric descenders remain necessary below it. |

The opening Adagio label should remain for every part. Seven subsequent bar numbers are printed on Soprano and Violin I only; the map recommends optional small source fragments for the other six parts instead of retaining broad neighboring context. The combined printed Basso ed Organo staff remains one part.

## Rectangle overlap cases

| Page/system | Target | Adjacent ink in the own envelope |
|---|---|---|
| 1/1 | basso | violin1; see measured object rectangles in the map. |
| 1/1 | violin1 | basso; see measured object rectangles in the map. |
| 2/1 | violin2 | viola; see measured object rectangles in the map. |
| 2/1 | viola | violin2; see measured object rectangles in the map. |
| 2/2 | violin2 | viola; see measured object rectangles in the map. |
| 2/2 | viola | violin2; see measured object rectangles in the map. |
| 3/1 | violin1 | violin2; see measured object rectangles in the map. |
| 3/1 | violin2 | viola, violin1; see measured object rectangles in the map. |
| 3/1 | viola | violin2; see measured object rectangles in the map. |
| 3/2 | violin2 | viola; see measured object rectangles in the map. |
| 3/2 | viola | violin2; see measured object rectangles in the map. |

No whiteout masks are proposed. Where ranges overlap, retain readable target notation and report the remaining fragment; do not shrink own-notation guards to force a clean-looking result.

Source SHA256: `2e7f854bed0c1d6baa82aefd3666b0451f8e030c282833b9f167bee456012a95`. New map SHA256: `e8c0e8d415c2a425195a6d92709bf095c3830fe69b26cad0e1884e8fbb5e96af`. Review images are under `.build/ave-tight-review/fresh/`.
