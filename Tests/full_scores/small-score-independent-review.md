# Independent source preservation review: Ave, Notte and Schumann

Reviewer: `offline_detection`. All 258 extracted bands were inspected against the original PDFs, using paired images showing the proposed crop inside an original-source context extending 18 PDF points beyond both vertical edges, followed by the actual exported strip at the same scale. No masks were used. Neighboring notation is acceptable under the user's preserve-target policy.

The three `*-map.json` files record a preservation verdict and protected source rectangles for every band. These rectangles were added after visual inspection; staff counts and pixel equality cannot discover whether a reviewer missed a target symbol. This review concerns the supplied source editions, not another edition or a transcription.

## Source crop results

| Score / part | Bands checked | Source edge findings |
|---|---:|---|
| Ave: Soprano | 8 / 8 | Opening Adagio and sotto voce, high slurs, every Latin lyric syllable and final rests retained. |
| Ave: Alto | 8 / 8 | Notes, rests, accidentals, ties, complete lyrics including final *examine* retained. |
| Ave: Tenore | 8 / 8 | Treble octave clef, notes, ties and complete lyric line retained. |
| Ave: Basso | 8 / 8 | Bass clef, low notes, accidentals, lyric descenders and final rests retained. |
| Ave: Violino I | 8 / 8 | High phrase slurs, low ledger notes, grace notes, last-system trill, final double bar retained. |
| Ave: Violino II | 8 / 8 | Low ledger notes/ties and long phrase arches retained throughout. |
| Ave: Viola | 8 / 8 | Alto clef, sotto voce, low notes, accidentals, phrase slurs and final whole note retained. |
| Ave: Basso ed Organo | 8 / 8 | Complete figured bass, including third rows, final-system lowest 3 and opening lowest 2 retained with bottom padding 9 staff spaces. Tasto solo and sotto voce retained. |
| Notte: Voice (Leporello) | 20 / 20 | First two systems intentionally carry labelled piano introduction cues. All subsequent vocal notes/rests, two lyric languages, fermatas and stage directions retained through final printed rests. |
| Notte: Piano | 20 / 20 | Both hands, all beams/chords, low ledger notes, orchestral cue text, fp/sf/cresc. and final tutti run retained. |
| Schumann: Voice | 77 / 77 | All eight songs, complete German lyrics, ornaments, grace notes, accidentals, hairpins, tempo words, rests and final fermatas retained. Printed empty vocal postlude staves remain represented. |
| Schumann: Piano | 77 / 77 | Both staves and all clef changes, ledger notes/chords, beams, slurs, dynamics and pedal symbols retained. Especially low slurs/inverted fermatas at source p2s2, p16s2 and p16s4 were checked against source ink outside the boundary. |

No crop corrections were required after these full comparisons. The Ave organ padding correction from 7 to 9 had already been applied to the reviewed draft; this review independently verifies the resulting lowest figures.

All 12 separate Schumann shared-direction rectangles were compared against their original context and actual output: Lebhafter; ritard.; Adagio; Presto; Langsamer; Tempo wie das erste Lied; Etwas langsamer; Adagio; Nach und nach rascher; Schneller / a tempo; and Noch schneller (Adagio occurs in two vocal locations). All words and punctuation are complete. Some adjacent stems or beam fragments remain within these rectangles.

Original oversized Schumann song-number headings sometimes intersect crop edges. The numbered editorial section headings preserve their section identity. Target musical directions themselves are retained in the main band or in a separate shared source rectangle.

## Review binding

The `independentCropReview` object in each source map records the draft PDF hashes actually inspected. The source rectangles, staff assignments and shared-direction rectangles are the reviewed geometry. The final export must retain these values or receive another source crop review. Full final-page layout/readability and final hash binding are recorded below after final export.

Final pagination review: **pass** for all 45 final pages (Ave 8, Notte 7, Schumann 30), each viewed at 120 dpi. All twelve parts have readable target notation, clear strip separation, complete headings and unobstructed 9-point page-number footers. Ave has one page per part; Notte Voice has three pages and Piano four; Schumann Voice has thirteen and Piano seventeen. All eight Schumann song starts begin a new page in both parts. No blank, overfull or duplicate page was observed. Page turns occur at system boundaries but have not been optimized or tested in performance.

The final v7 Schumann geometry moved some boundaries slightly relative to the earlier source-comparison draft. Seven protected envelopes extended outside the final crop by only 0.018–0.287 points. These seven original-source contexts were inspected at 2.4x with both the final crop and previous guard overlaid: p7s1 Voice/Piano, p8s1 Voice, p10s2 Voice, p11s2 Voice, p11s5 Voice, and p15s1 Voice. The affected margins contained blank space, neighboring ink, or nonmusical song/page numbering. Guards were tightened only after this visual confirmation, retaining all target notes and words. The two larger (~3.25 point) piano geometry changes at p2s3 and p5s1 were also reinspected against source; low slurs, ledger notes and dynamics remain complete. No crop or profile change was required.

Final PDFs and all per-band verdicts are bound in each output directory's `visual-review.json`. This visual report does not claim the separate automated pixel-fidelity run has passed; consult that run's own results.

## Final PDF hash bindings

| Score / part | Pages | SHA256 |
|---|---:|---|
| ave / Soprano | 1 | `5369b140addf0add45766224fe684659444e221748f94d6cb973352f7e0cb551` |
| ave / Alto | 1 | `8b70de00c9665b8b496e89619692f31a11ea389443c3c7ada43f3b5d59c345cc` |
| ave / Tenore | 1 | `c18575a3a7e67aa19436b0c9c4dbaa56ec7fc957b1cbb504e5efade0b4e1851c` |
| ave / Basso | 1 | `a0bc4b3f025ebafb9453e2df04ddf8eb1c70764e060fca0d5d6c7aecaee7ddee` |
| ave / Violino I | 1 | `f403db3e3e5a37e9db1d6ed24721eff851b2368bde51f6e2c7e2701326bdafce` |
| ave / Violino II | 1 | `1bb4c2f457f2d474c6cccb7cb205a37a724e03dd7998091517da12ed610059f6` |
| ave / Viola | 1 | `64dfdd3cf32681d1d139b9afb1ae729d681999f31bcc3698b7135423a11c692f` |
| ave / Basso ed Organo | 1 | `d6b3baea434e7299349ba05173f67c3e2c411a8ff0a443341fcf370b2e566489` |
| notte / Voice (Leporello) | 3 | `4bc087fcd659a995b466c64206c83c2f834f3b6f4ca0f3b85cb81b09fb876d93` |
| notte / Piano | 4 | `6f6303975ad5ff5f0a3ef7cfb37061f65a1774f98bd0629c2ace0c05579979ce` |
| schumann / Voice | 13 | `4e58757ef9ee8a2089bc3a529d6954aeff07c251924ec1a0809dbfc3a6da5b21` |
| schumann / Piano | 17 | `dc3febd3a35eb3771e6784f21e16abb331706c19b959cb23f87d14bd0ce192d9` |
