# Mozart K.488 opening rest audit

Independent visual review of the first eight source systems (pages 1–4, bars 1–39), plus the Piano entrance on pages 7–8. The original PDF has SHA256 `b2e0feed0fc729fe0a755563cd1fc7137f2b0dc063f2b62cd59e96e7ec7b4d10`. This audit establishes the musical expectations for rest compression. It does not certify output crop edges or automatically infer omitted-instrument assignments.

The nine parts, in score order, are Flute, Clarinet in A, Bassoon, French Horn in A, Piano (two staves), Violin I, Violin II, Viola, Cello and Bass. Both wind players share each printed wind staff and must be silent before it can be replaced.

| Page / system | Bars | Entirely silent printed parts | Silent omitted parts |
| --- | --- | --- | --- |
| 1 / 1 | 1–5 | Flute, Clarinet, Bassoon, Horn, Piano (both staves) | None |
| 1 / 2 | 6–10 | None; all four wind parts start playing at 9 | Piano |
| 2 / 1 | 11–16 | None | Piano |
| 2 / 2 | 17–21 | None | Piano |
| 3 / 1 | 22–25 | None | Piano |
| 3 / 2 | 26–29 | None | Piano |
| 4 / 1 | 30–34 | None; winds play in 30 before resting 31–34 | Piano |
| 4 / 2 | 35–39 | Flute, Clarinet, Horn | Piano |

Consequently the Clarinet's opening strip should compress to five bars exactly as the Bassoon's does. The Piano's opening printed five-bar grand staff and the seven following omitted systems can form one **39-bar rest** for this eight-system excerpt. This is five bars plus 5 + 6 + 5 + 4 + 4 + 5 + 5, not two independent five-bar rests for the hands. All 72 part/system identities remain accounted for even if displayed on fewer rows.

Opening clefs, keys, common time, and Allegro/TUTTI belong at the start of the rest. No new shared tempo, meter or rehearsal event interrupts the Piano rest within bars 1–39. Bassoon `a 2.` at19, Cello `Vel.` at33 and `Bassi` at35 are part-specific directions, not Piano rest boundaries. The Bassoon has notes in38–39 and therefore cannot have its entire eighth strip replaced, even though its first three measures are silent.

For the complete opening, Piano is absent through bar65. Page 8's first printed Piano system starts with one whole rest at66, then enters at67 under SOLO. Joining complete silent strips therefore yields **65**, followed by the unchanged mixed system66–71. The total musical silence before the first note is66. The earlier complete-workflow README's “60-bar rest” described the omitted-only span6–65; it must not become an off-by-five expectation after the opening grand staff is also detected.

The JSON companion lists whole silent measures for every part in every audited system, including short rests inside mixed systems. Those short rests are source-reading facts, not a request to split or rewrite mixed crops. Output must stop compressing at sounding music and retain all relevant source directions; source page/system boundaries by themselves need not force separate rest rows.

Reproduce renders and the recorded structured expectations with `.build/extraction-venv/bin/python tools/mozart_rest_source_review.py`. The prior source-reviewed map locates each image, and this review independently reads the notation. Eight system crops and two full entrance pages are retained with hashes.
