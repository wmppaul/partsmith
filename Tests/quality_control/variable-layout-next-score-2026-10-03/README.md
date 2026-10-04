# Next complete variable-layout score

The next bounded workflow should be Mendelssohn’s **Verleih uns Frieden**, CPDL63797, the Benjamin Righetti choir-and-organ arrangement. It is the shortest remaining source: **6 pages, 14 systems, 77 physical staves, bars 1–102, five parts**. All six original pages were viewed for this recommendation. No new analysis or export was run.

The previous three-score audit found complete source-bound drafts for Notte, Erlkönig and the full K488 first movement. They account for four of the 19 raw zero-band profiles because K488’s one-page excerpt is a separate raw profile. It is not another completed score. See [the frozen coverage ledger](../variable-layout-output-audit-2026-10-03/README.md).

A read-only search of 197 loose source-embedded projects under `.build` and `output` found no complete output for the 15 remaining profiles below. The single matching Winterreise project has 70 source pages but zero parts and zero bands. This is an inventory of the searched loose files, not a claim about unopened arbitrary archives or all machine locations. Alternative editions are listed separately and are not counted as distinct musical works.

| Pages | Remaining raw profile |
|---:|---|
| 6 | normal-mendelssohn-verleih-uns-frieden-gnadiglich-cpdl63797-full-score |
| 10 | lightly-skewed-08-mendelssohn-hear-my-prayer-woo15-imslp-40163 |
| 18 | medium-skewed-07-brahms-2-motets-op74-imslp-101580 |
| 18 | lightly-skewed-07-brahms-2-motets-op74-imslp-101579 |
| 27 | medium-skewed-08-brahms-gesang-der-parzen-op89-imslp-109041 |
| 27 | lightly-skewed-09-brahms-gesang-der-parzen-op89-imslp-109040 |
| 35 | rest-detection-beethoven-symphony-no5-op67-mvt2-mutopia1437 |
| 37 | normal-mozart-symphony-no18-kv130-score |
| 50 | normal-beethoven-egmont-overture-op84-score |
| 70 | medium-skewed-10-schubert-winterreise-d911-imslp-00414 |
| 77 | lightly-skewed-04-schumann-concertpiece-4-horns-op86-imslp-291222 |
| 80 | medium-skewed-04-schumann-concertpiece-4-horns-op86-imslp-51506 |
| 86 | lightly-skewed-03-brahms-symphony-no1-op68-imslp-317803 |
| 106 | rest-detection-beethoven-symphony-no5-op67-complete-imslp52624 |
| 277 | lightly-skewed-06-puccini-la-boheme-sc67-imslp-885132 |

The exact source is `sample_scores/normal/04_choir/mendelssohn_verleih_uns_frieden_gnadiglich_cpdl63797_full_score.pdf` (SHA256 `e5d9e40c209ccae77ea2a610e81db5e3435df3a848da47b51bb644a72b710706`). Its printed-instrument profile is `Tests/quality_control/profiles/normal-mendelssohn-verleih-uns-frieden-gnadiglich-cpdl63797-full-score.json` (SHA256 `5bf0f8964e702f65be7ba79a096dac57543193b37b0059f0add942a4dae8d46a`). The copied source map and per-page review bind the existing original render archive by hash; no duplicate raster archive is needed.

Four reviewed seeds plus two existing suggestions cover 6 of 14 systems; the remaining eight need explicit assignments. The current matcher hash is identical to the frozen evaluation. The score has four source rosters: SATB/Organ, Organ alone, Bass/Organ, and Alto/Bass/Organ. Separate choir and organ brackets belong to the same system. Organ always has two manuals and a pedal staff; its two-staff brace is not the full part.

The frozen map yields 49 original music rows and 21 absent-part rows, or 70 original item references before optional rest joining. Soprano and Tenor are absent in bars 8–66, Alto in 8–36, and Bass in 8–15. All voices are printed in bars 1–7 and must keep those source staves. These source-defined counts can support a complete native draft without inventing silent durations or weakening the matcher.

The next acceptance step is native document apply/save/reopen/export of all five parts, followed by full source comparison. Required review targets are the individual lyric lines, the Organ pedal and manual clef changes, low ties, registrations, shared opening tempo, generated-rest meter/timing, and page turns. This recommendation does not assert that native crops will already preserve all of those details.
