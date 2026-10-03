# Complete Schumann Frauenliebe und Leben review, IMSLP270922

2026-10-03. Independent source-to-output visual review of the complete lightly scanned score. **The existing exports remain drafts: target notes and lyrics were retained in the inspected output, but shared directions, song identification, neighboring notation and page turns need work.** Production code, source PDFs, exports and earlier reports were not changed during this review.

## Reviewed scope and currency

- All 16 original source pages, including all eight songs.
- All 77 printed systems. Each has one vocal staff and a two-staff piano group, including the final postlude's printed silent voice staff.
- All 154 exported bands, each present once and in source order.
- Every page of both complete outputs: Voice 7 pages; Piano 12 pages.

The corpus's previous `visualReviewStatus` was `not_reviewed`. This review uses the authoritative existing `connector8-harmonic` exports, not newly generated easier crops. All 154 old assignment records compare **exactly equal** to a fresh full-source inventory/plan from the current analyzer, including the promoted alias and low-resolution erasure fixes. Thus this review concerns current crop behavior. It does not establish instrument-name OCR accuracy: the saved voice/piano profile was already initialized correctly.

`provenance.json` records original PDF, manifest and output hashes. `plan-currency.json` records both plan/inventory hashes and exact equality. Source SHA-256: `d13fc3f4299dda634845b218222add8884ab9fd5257a9abb7cb2f9bcad4b9975`. Voice PDF: `d787011350a481d401da0df5ba59a288656c79bc2263c1c9654704cda3a3d8f4`. Piano PDF: `ab561c889cd8d904f33501a24b4e4da3d0473a0d47e34bd4bee144116b52834f`.

## Method and target notation

Every full source page was rendered with the actual crop edges, including the source notation outside those edges. I checked identities, printed system counts, local notes/rests, clefs, signatures, accidentals, articulations, slurs, lyrics/continuations, piano ledger notes and pedal marks. Every full output page was then compared in source order. Three decisive clipped/omitted landmarks were also inspected at six-times PDF scale.

No missing target note, rest, clef, signature, articulation, piano pedal sign or vocal lyric syllable was observed in these comparisons. The source's high/low ledger passages, repeated clef changes, and the final piano postlude and fermatas survive. This is a visual musical review over the stated scope, not a proof derived from detector geometry, component bounds, a pixel threshold or staff counts. No claim of clean isolation follows from target preservation. The damaged left clef/staff area in source page 7's last piano system is already damaged in the original scan.

`review.json` records all 16 source-page observations, every band, every output-page comparison and turn, and 30 separate direction/index issues. Its review version 2 entries separate target notation from shared directions and neighboring ink.

## Shared directions and song numbers

These baseline exports contain no automatic shared-direction recognition or copies. The new experimental direction workflow was not run here, so it must not be credited with fixing these findings without a new extraction and comparison.

| Finding | Source | Affected output |
| --- | --- | --- |
| All eight opening tempo headings absent from piano | Song starts on source pages 1, 2, 5, 7, 9, 11, 13, 15 | Piano pages 1, 2, 4, 5, 7, 8, 10, 11 |
| `Etwas langsamer.` absent | Page 5, system 4 | Piano page 4 |
| `Adagio.` above voice absent from piano | Page 6, system 2 | Piano page 4 |
| `Nach und nach rascher.` absent | Page 8, system 1 | Piano page 6 |
| Top of `Lebhafter.` clipped | Page 12, system 1 | Piano page 9 |
| `Schneller. / a tempo` absent after a retained `ritard.` | Page 14, system 1 | Piano page 10 |
| Postlude `Adagio.` and `Tempo wie das erste Lied.` absent from the retained silent voice bars | Page 16, system 2 | Voice page 7 |

The `Lebhafter.` piano crop starts at y=94.384615 source points through the printed letters. This is a real vertically truncated musical direction, not an OCR spelling error or a tiny boundary tolerance. `lebhafter-comparison.png` shows original source and actual retained output pixels. `schneller-comparison.png` shows the omitted tempo transition.

All eight song numbers are missing from Piano. Voice retains number 1; number 3 is cut roughly in half, and numbers 2, 4, 5, 6, 7 and 8 are absent. `song-index-3-comparison.png` records the truncation. These are 15 separate part-specific index defects, in addition to the 15 tempo/direction records above.

Some marks survive incidentally with neighboring context: Voice retains the complete `Lebhafter.`, the later `Adagio.` on source page 12, and `Langsamer.` on page 14. At page 14 system 3, Voice's `Noch schneller.` and Piano's `Presto.` both survive where printed; I did not classify the differing but corresponding local directions as a missing required duplicate. The clipped neighboring `Presto.` fragment below Voice is instead a cleanliness defect.

## Neighboring ink and layout

Voice repeatedly includes piano noteheads, stems, beams, slur fragments and staff remnants. Large fragments from the preceding piano bass appear above later voice strips, especially source pages 2, 4, 10, 11 and 12. These can look like extra voice notes or underlines. Piano frequently includes sliced or complete vocal lyrics and sometimes part of the vocal staff. They are recorded as readability/contamination defects, even where every intended note survives. The comparatively clear song-8 systems show that this is not necessary everywhere.

All 19 pages have complete, correctly ordered source strips; no page-edge clipping or renderer crop displacement was observed. The median five-line staff height is about 14.6–14.7 PDF points (approximately 5.2 mm), retaining the source score's small notation size. These pages are packed reasonably densely, but several six-system piano pages have visibly more bottom whitespace than adjacent seven-system pages. I have not claimed a lower feasible total page count without recomputing layout. Both first pages still use diagnostic `Auto QC` titles and the source filename as a subtitle rather than polished performance headings.

Page-turn suitability is not established by compact packing. Five of Voice's six turns interrupt continuous sung text without an intervening rest: `meinem`/`Himmel`, `wie so`/`gut!`, `an das`/`Herze mein`, `scheuen`/`eine`, and `was`/`lieben`. The remaining turn has only a short printed quarter rest. Piano has useful song-end turns after pages 1, 6 and 9, but other turns continue accompaniment. The page 7 turn crosses active two-hand arpeggios; page 10 crosses continuous two-hand sixteenth notes. Sustained-harmony turns on pages 8 and 11 need a player's review rather than an automatic pass.

The next useful extraction iteration is to run the new shared-direction workflow against the complete score, compare it to these independent source landmarks, preserve/recover all song numbers, and choose song/phrase-aware page breaks. Neighbor cleanup must continue to preserve the reviewed vocal lyrics, extreme piano ledger notes, pedal marks and complete slurs.

## Files and reproduction

`render.py` reproduces the complete source, crop-edge and output images from the authoritative PDFs. Full-resolution review images remain under `.build/qc-schumann270922-review`; `rendered-image-hashes.json` identifies all of them. `write-review.py` retains the manually entered source observations, independent landmark regions and page-turn findings used to produce `review.json`. Landmark comparison images contain actual PDF pixels intersected with the particular band's retained rectangle, never neighboring output strips or a reconstructed score.
