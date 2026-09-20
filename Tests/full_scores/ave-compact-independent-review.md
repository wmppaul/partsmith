# Historical rejected Ave compact drafts

Superseded by [ave-compact-final-review.md](ave-compact-final-review.md). The verdicts and PDF hashes below apply only to earlier rejected generations, not the delivered compact set.

---

# Ave compact independent review — current generation

**Targets preserved; context revision still required.** All 64 strips and all 8 one-page parts were independently viewed against raw source. All 64 source guards fit. Shared measure numbers and opening tempo now pass. The current draft removes most vocal lyric duplication, but retains 29 neighboring staff-line centers, including four-line neighboring staffs in three strips. These are not needed to preserve the target.

| Part | Finding |
|---|---|
| Soprano | Target intact; mostly compact. Opening adjacent sotto voce and p4s1 Alto top line/arch are avoidable. |
| Alto | Target intact; six strips remove the duplicated lyric row. p2s2 and p4s1 still retain preceding lyrics; p2s2 also retains a neighboring staff line. |
| Tenore | Target intact, including octave8 and all lyrics. Several lower edges retain Basso heads; p3s2/p4s1/p4s2 still retain complete preceding lyrics, with p4s1 especially cluttered. |
| Basso | Target intact; first six strips much cleaner. Final two retain preceding lyrics. Opening Violino I Adagio genuinely overlaps the target envelope. |
| Violino I | Target intact, including low ledger notes and final trill/grace. Final two strips and opening strip retain avoidable following staff line/arches. |
| Violino II | Target intact. p3s1/p3s2 retain four Viola lines and most Viola notation; other strips retain variable upper/lower fragments. Context fails materially. |
| Viola | Target intact. p2s1 retains four bass lines and most bass notation; several other strips retain substantial neighboring notes. Context fails materially. |
| Basso ed Organo | Target intact, including all figured bass. Upper Viola fragments persist; p1s2/p3s2 retain full publisher copyrights under fixed low padding. |

The strongest failures are Violin II p3s1/p3s2 and Viola p2s1. Their crops contain substantial adjacent music, visibly resembling partial multi-staff systems. Own notation remains readable, but this does not meet the requested tighter extraction.

| Band | Native vertical crop | Reviewed own guard | Tight source reference |
|---|---|---|---|
| p3-s1-violin2 | 278.21–347.16 | 291.98–327.74 | 290.73–328.99 |
| p3-s2-violin2 | 630.17–683.14 | 632.09–666.69 | 630.84–667.94 |
| p2-s1-viola | 309.50–374.37 | 325.73–353.44 | 324.48–354.69 |
| p4-s1-tenore | 155.79–220.32 | 170.69–206.40 | 169.44–207.65 |
| p2-s2-alto | 462.86–511.07 | 468.57–502.24 | 467.32–503.49 |
| p3-s2-tenore | 511.49–563.10 | 519.57–553.57 | 518.32–554.82 |
| p4-s2-tenore | 510.47–555.62 | 517.61–548.90 | 516.36–550.15 |
| p3-s2-bass_organ | 691.04–765.09 | 692.78–740.93 | 691.53–742.18 |

Native strip height totals 3046.94pt, 499.16pt above independently reviewed tight source proposals. No target loss was found; no masks were used. Neighbor-line counts alone understate the visible clutter.

All headings, part labels, source measure numbers, footers, and terminal bars are legible. Grouping braces and barlines are cropped at strip edges. The extra Adagio in the opening Basso strip genuinely shares the own lyric height; other substantial staff regions listed above are avoidable.

The next generic algorithm check should focus on crop expansion crossing into another detected staff core, final-system lyric ownership, and figured-bass ownership before reducing fixed lower padding. These findings are not instructions to hard-code the reviewed rectangles into native output.

Manifest SHA256: `b837623615efc7058b470b38e6cef3b1bf4a2db36e6b79746d0789e6ffab368e`. Source-map SHA256: `57408271c90103e87171de618ad14d19e4e719677f2cfafbfdf3c8bf5a5c925d`. Source SHA256: `2e7f854bed0c1d6baa82aefd3666b0451f8e030c282833b9f167bee456012a95`. Each PDF hash and all 64 individual band observations are in `.build/ave-compact-current-independent/visual-review.json` and the current draft review. PDFs, manifest, comparisons and full-page images are retained in that independent workspace.

The earlier first-generation review follows as historical evidence; its bindings identify a different PDF generation.

---
# Ave compact independent review

**Target preservation passes; compact-context quality needs another native algorithm pass.** This verdict covers the first compact generation below, not later regenerated PDFs.

All 64 actual output strips were compared with original source context beyond crop edges. All eight complete output pages were viewed at 150dpi. The fresh source guards fit 64/64 native crops, and no native crop includes a neighboring staff line. Own notes, lyrics, slurs, directions, ledger notes, figured bass, terminal bars, headings and footers were retained and readable.

However, the middle voices retain duplicate lyric lines and the lower strings retain substantial neighboring note fragments. Those are avoidable according to the independently reviewed tight source envelopes. Pixel fidelity and target containment alone must not turn this into a clean-isolation pass.

| Part | Review result |
|---|---|
| Soprano | All target lyrics, rests and long high arches remain readable. Small neighboring clef tips and slur fragments persist; opening strip also retains the following Alto sotto voce. No neighboring staff line remains. |
| Alto | All target music and lyrics preserved, including the unusually low p3s2 lyrics/extender. Every strip retains a complete unnecessary Soprano lyric line above the Alto staff, with associated clef/slur fragments. Context cleanup needs revision. |
| Tenore | Octave-clef 8, all lyrics and high arches preserved. Every strip retains the preceding Alto lyric line; several lower edges also retain following Basso noteheads/slurs, notably p3s2. Context cleanup needs revision. |
| Basso | All own lyrics and high arcs preserved. Seven strips retain a full or nearly full preceding Tenore lyric line; p4s1 retains only fragments because its own high arch genuinely needs the upper region. Opening Violin I Adagio overlaps the own lyric range. Context cleanup needs revision. |
| Violino I | All own Adagio, sotto voce, printed measure numbers, low ledger notes/slurs and final trill/grace figure preserved. Small adjacent clef/slur fragments and opening Basso lyric fragments remain; the opening Adagio shares their vertical range. |
| Violino II | All own notes and low slurs preserved, including the two low p1s2 slurs. All eight strips retain substantial unnecessary Violin I lower notation above; some Viola upper arcs genuinely overlap the own lower envelope. Context cleanup needs revision. |
| Viola | All own clefs, accidentals, slurs and low ledger notes preserved. Seven strips retain substantial unnecessary Violin II lower notation; p3s2 also includes avoidable following bass noteheads/slurs. p4s1 is substantially cleaner. Context cleanup needs revision. |
| Basso ed Organo | All own tasto solo/sotto voce directions and figured-bass rows preserved. Upper Viola fragments remain. Fixed low padding retains the whole publisher copyright at p1s2 and a clipped copyright at p3s2. Excess lower space can be reduced after detached figured-bass ownership is preserved. |

Native strips total 3153.45pt versus 2547.09pt for source-reviewed tight proposals: 606.36pt of additional height. Some context is required by actual overlap; whole duplicated lyric lines and many preceding-part noteheads are not.

## Concrete algorithm regressions

| Band | Native vertical crop | Own guard | Tight reference crop |
|---|---|---|
| p1-s2-alto | 477.14–527.73 | 488.97–525.67 | 487.72–526.92 |
| p2-s1-tenore | 160.21–209.65 | 173.09–206.91 | 171.84–208.16 |
| p1-s2-basso | 551.96–603.23 | 561.79–598.35 | 560.54–599.60 |
| p3-s1-violin2 | 280.59–329.48 | 291.98–327.74 | 290.73–328.99 |
| p2-s1-viola | 309.50–356.94 | 325.73–353.44 | 324.48–354.69 |
| p3-s2-viola | 656.02–703.54 | 663.56–692.84 | 662.31–694.09 |
| p1-s2-bass_organ | 697.16–765.09 | 705.52–754.47 | 704.27–755.72 |
| p3-s2-bass_organ | 691.04–757.61 | 692.78–740.93 | 691.53–742.18 |

Suggested generic fixes are in `visual-review.json`: own lyric-baseline assignment, target-owned component reach rather than unconditional broad floors, correct ownership of low string material, and detached figured-bass detection before reducing fixed organ padding. These are algorithm targets, not proposals to encode hand rectangles into production.

All opening instrument labels remain legible. Grouping braces/brackets are clipped at crop edges. Shared source measure numbers are preserved for Soprano and Violin I but not copied to the other six parts; optional source-number fragments are already identified in the tight source map. The editorial opening Adagio appears for every part.

Manifest SHA256: `4e8874fbb35d8a7c512a957e9abb7dd70e07d6905b7a2f3d11f6c188ce83520c`. Source-map SHA256: `e8c0e8d415c2a425195a6d92709bf095c3830fe69b26cad0e1884e8fbb5e96af`. Source SHA256: `2e7f854bed0c1d6baa82aefd3666b0451f8e030c282833b9f167bee456012a95`. Individual PDF bindings and every-band observations are in `.build/compact-drafts/ave/visual-review.json`, with an immutable local review copy under `.build/ave-compact-independent/`. No PDF, profile or production file was changed.
