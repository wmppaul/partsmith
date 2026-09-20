# Brahms Violin I preservation review

Reviewed 2026-09-19 by the score-survey agent against the unmodified source scan. This is a fresh review under the user's explicit requirement to retain every intended-staff note while allowing neighboring notation. The earlier failed clean-isolation review remains valid for its different output and criterion.

Result: all 14 Violin I systems on PDF pages 1–3 (bars 1–98) are retained in reading order. I found no target note, rest, accidental, articulation, beam, slur, dynamic, meter signature or required rehearsal/tempo marking omitted by these crops. All 14 strips retain neighboring notation. No exclusions or other whiteouts are used. This is a preservation excerpt with visible context, not a cleanly isolated engraved part.

## Artifacts and method

- Recipe: `Tests/extraction/brahms-preservation-recipe.json`; SHA256 `bf5549c7761c915f57541bf3c00a44fa044f9180a0288954d0ace59873cd45c5`.
- Source: `sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf`; SHA256 `ff883e06db2bc69c5de0c45fa447795201805ecf7210b76c50168b64f0570689`.
- Built PDF: `output/pdf/brahms-preservation/Violin I.pdf`; SHA256 `40c3e53cd8ec54edc03a5053ad33d55952d88aec9b9444e7ba052b8ca76bfa71`.
- Native project and portable recipe are alongside the PDF. The source scan is embedded unmodified.
- Freshly inspected every full source page and all 14 source contexts, including ink beyond all four crop edges; inspected all three final rendered output pages. Source crop images at 288 dpi are available in `.build/extraction/brahms-preservation/`; maintained CLI context images are in `output/review/`.
- Violin I is the first staff of each four-staff quartet system. Source page 1 has four systems; pages 2 and 3 have five each. The excerpt ends before bar 99 on source PDF page 4. Source page numbers and editorial output page numbers differ.

## Per-band source comparison

All rectangles are top-down original PDF points. The horizontal crop is 20–578 throughout. Full envelopes and the named vulnerable landmarks are recorded as independently reviewed `protectedRegions`, so shrinking a crop past them must fail validation.

| Band; bars | Crop y | Target landmarks checked against source and output | Tolerated neighboring material |
|---|---:|---|---|
| p1-s1; 1–7 | 150–208 | Violin I label, clef/key, Vivace, 6/8, initial rests, high staccato dots, f/sf and final f, last beamed group and right barline | Violin II clef/stems/beams below; partial publication text above right |
| p1-s2; 8–16 | 298–356 | Initial dotted articulation, high repeated accented notes and ledger lines, both low f, high accidentals at right and final rests | Violin II clef, accents, notes, stems and staff fragments below |
| p1-s3; 17–23 | 443–507 | Initial rests, low entry f, complete rehearsal A frame, all rising runs and their high slurs through final group | Previous system's cello f/accents above; Violin II notes/stems below |
| p1-s4; 24–28 | 590–658 | High opening run and its complete slur; dotted figures; every high right-side staccato dot, ledger line and accidental; four low sf | Previous cello markings above; Violin II slurs/notes/beams below |
| p2-s1; 29–33 | 36–106 | High opening ledger notes/slur, complete descending triple-beam run, complete rehearsal B frame, long phrase arc, full fp, final tremolo/ties | Violin II up-stems/beams/notes below; printed folio above right |
| p2-s2; 34–38 | 188–248 | Every slurred running group, long hairpin and full dolce legg., low right-side note/slur, far-right accidentals and barline | Violin II high slurs/accents/notes below; tiny previous-system residue above |
| p2-s3; 39–44 | 323–386 | Entry note and full fp descenders, flat signs, tied/tremolo figures, all arcing slurs and high/final descending runs | Violin II flag adjacent to fp and notes/staff below; previous-system text residue above |
| p2-s4; 45–49 | 462–521 | Low slurs under first two measures, all runs/accidentals, complete dim. including initial d, low ledger notes, final barline | Violin II clef/staff below; previous cello sf fragments above |
| p2-s5; 50–57 | 590–660 | Complete rehearsal C frame, initial rests, both pp, high phrase slur, tied final low notes and change to 2/4 | Previous cello hairpins/dim. above; Violin II beams/notes/rests and meter below |
| p3-s1; 58–65 | 46–96 | Initial 2/4, all beams/under-note slurs, switch to 6/8 and long ties, return to 2/4, rightmost high beams/short slurs and last low notes | Violin II beams/notes below; source folio at upper left |
| p3-s2; 66–74 | 174–245 | All opening low notes and short slurs, hairpin, complete poco cresc. with continuation marks, high-right slur and all ledger notes, f and long diminuendo hairpin | Previous cello notes/ties above; Violin II stems/high slur/notes below |
| p3-s3; 75–84 | 325–393 | pp, low hairpins/slurs, whole rehearsal D frame and entry p, right-side high accidental/ledger notes/slur, final note | Previous cello notes, poco cresc./f/hairpin above; Violin II notes/beams below |
| p3-s4; 85–91 | 465–525 | All high repeated notes, accidentals, short slurs, beams, full opening clef/key, final note/barline | Previous cello pp/hairpins/slurs above; Violin II clef/high slur and partial staff below |
| p3-s5; 92–98 | 618–682 | All opening high notes/slurs, alternating runs and accidentals, full p cresc., low right-hand notes/short slurs and final barline | Previous cello p/hairpin above; Violin II meter/staff/notes below |

## Layout and limitations

The output has three pages, with complete strips and source page divisions preserved before bars 29 and 58. Titles, strip labels, staff ends and footers fit. The scan angle and source engraving are preserved without stretching. These breaks are deliberate source-page correspondence; this review does not claim an optimized performance edition or a convenient rest at every turn.

Each strip has one complete intended Violin I staff. Partial material above and below is visible context from adjacent source staves/systems, and should not be interpreted as additional Violin I directions. The part title and source/bar labels identify the intended sequence. The original scan is available in the editable project when context is needed.

## Regression targets

1. Reject a crop that raises p3-s2's top boundary through the reviewed high-right slur at `[456,180,558,210]`; the old 189-point top is unsafe. Check that these source pixels remain in the output after placement transforms.
2. Reject masks or a raised bottom crossing p2-s3's full fp `[92,359,111,379]`, p2-s4's dim./low-note region `[365,496,560,514]`, or p3-s3's D frame `[310,331,339,357]`. These are known losses from the prior cleanup experiment.
3. Reject tightening that clips p1-s4's high-right articulation/ledger region `[411,594,567,634]`, or p3-s1's rightmost stems/beams/slurs `[454,51,558,85]`.
4. Every final band must have an empty exclusions list and contain its independent main target envelope and all landmark regions. Geometry checks supplement, and do not replace, the fresh source comparisons above.

Independent second review is recorded separately. Any later recipe or PDF change invalidates these output hashes and requires the affected source/output comparisons again.
