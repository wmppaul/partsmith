# Independent Brahms Violin I preservation audit

Reviewer: offline_detection agent, independently rendered source context.

Source: `sample_scores/medium_skewed/05_brahms_string_quartet_no3_op67_imslp_09200.pdf`, PDF pages 1–3, fourteen Violin I systems covering bars 1–98. The user permits retained neighboring notation; that alone is not a failure. Missing or clipped target notation remains a failure.

Status: **pass under preserve-target**. All fourteen final output bands were compared with independent original-source contexts; no omitted or clipped target notation was found. Neighboring notation is intentionally retained.

Original pages were rendered separately in `/tmp/partsmith-brahms-independent/` at 144 dpi, with independent enlarged system context renders at 216 dpi. These source contexts were chosen from the complete score, not from the proposed output crops. The audit compared all note groups and edge-sensitive notation in the output to these original contexts, then compared all three final pages at 216 dpi with the inspected output. Final and inspected renders are pixel-identical; band IDs, source and destination geometry, page assignment, and exclusions also match.

| Band | Bars | Independent target landmarks and edge checks |
| --- | --- | --- |
| p1-s1 | 1–7 | Opening clef/key/meter and Vivace; opening full-bar rests; staccato dots and highest note in the first active figure; complete f/sf/sf below that figure; complete later f before the final staccato group; final noteheads and barline. |
| p1-s2 | 8–16 | Opening dotted/staccato group and rests; all high ledger notes and accents in the central forte passage; both complete f markings below the staff; upper natural/sharp signs at the right; final two rests. |
| p1-s3 | 17–23 | Opening two rest measures; high entry with full f; descending notes into rehearsal A; all four edges of A; both rising seven-note runs and their 7 numerals; complete upper slurs and terminal short slurs/high noteheads. |
| p1-s4 | 24–28 | Opening high ledger note and short slur; full seven-note run and long upper slur; flats/accents over the two sustained figures; every high accidental/ledger line in the final two measures; all four complete sf markings below the staff. |
| p2-s1 | 29–33 | High opening descending groups and their upper slurs; natural signs in the second group; complete rehearsal B box; full fp beneath the repeated notes; both ending sustained beamed pairs with ties/slurs. |
| p2-s2 | 34–38 | Complete continuous beamed figures, accidentals, and upper slurs in all five measures; complete long diminuendo hairpin below the middle of the system; the entire dolce legg. text and its descenders; low note and natural sign near the right edge. |
| p2-s3 | 39–44 | Opening note/rests into the repeated figure; full fp including descenders despite adjacent second-violin flag; two sustained figures with flat signs and slurs; full subsequent rising/falling runs, low flats, ledger notes, and final upper slur. |
| p2-s4 | 45–49 | Both first descending/rising runs and their lower slurs; all low accidentals and noteheads; upper peak/slur in the third measure; the complete dim. including initial d; final two falling runs and low ledger notes. |
| p2-s5 | 50–57 | Entire rehearsal C box; opening flat note/rests and full-bar rest; pp at the high entry; full long slur across the subsequent phrases; second pp before repeated low notes; all lower ties/slurs and the printed meter change at the right edge. |
| p3-s1 | 58–65 | Opening printed meter, key/clef, articulation dots, and short slurs; central meter change and all sustained tied notes; the later meter change; complete ties beneath the central notes and final short slurs/notes at the right edge. |
| p3-s2 | 66–74 | Opening low articulated figures and lower ties; crescendo wedge before the entry; complete poco cresc. text and continuation dashes; all high accidental/ledger notes under the long final slur; full final f and long diminuendo hairpin. |
| p3-s3 | 75–84 | Opening pp, accidentals, and upper short slurs; both paired hairpins below the central notes; low note/rest/slur into D; entire rehearsal D box and p beneath it; final high sharp/ledger notes and full upper slur. |
| p3-s4 | 85–91 | Every rapidly beamed note group, especially all upper ledger-note peaks, small upper slurs, and naturals; first clef/key and final notes/barline. No target dynamic is assumed from neighboring staves. |
| p3-s5 | 92–98 | All descending beamed groups, upper slurs, ledger notes, and naturals/flats; full final p cresc. text including descenders; complete low final groups with dots and lower slurs through the last note/barline. |

This is an extraction-integrity audit, not a re-transcription or pitch-by-pitch edition proof. A final pass requires source-to-output comparison of every system, not just counting staves or accepting the presence of neighboring fragments.

## Final output and limitations

Final output: `output/pdf/brahms-preservation/Violin I.pdf`.

SHA-256: `40c3e53cd8ec54edc03a5053ad33d55952d88aec9b9444e7ba052b8ca76bfa71`. The hash-bound v2 review is recorded in `output/pdf/brahms-preservation/review.json` and `Tests/extraction/brahms-independent-review.json`.

All note groups, accidentals, articulation marks, slurs/ties, dynamics, meter changes and rehearsal frames listed above were visually checked against the original. The five-line target staff stays identifiable in every band despite retained neighboring/previous-system fragments. There are no whiteout masks. A supplementary raster check inside each crop found only 19 isolated raster-phase/antialiasing differences across roughly 735,000 source ink pixels; this check does not establish crop completeness by itself, which was judged from the independent wider source contexts.

The output is a three-page excerpt through bar 98, not the complete quartet. Original source-page breaks are retained before bars 29 and 58. Page-turn pass means order and source-page boundaries are preserved; comfortable performance turns have not been certified. Notation retains about 96.8% of source size. This is an extraction-integrity review, not a new engraving or a pitch-by-pitch edition proof.
