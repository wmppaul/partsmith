# Complete Mendelssohn native draft

All six original pages of *Verleih uns Frieden gnädiglich*, the Benjamin Righetti choir-and-organ arrangement (CPDL63797), are represented in five editable native parts. The complete source has **14 systems, 77 physical staves and bars 1–102**. Source SHA256: `e5d9e40c209ccae77ea2a610e81db5e3435df3a848da47b51bb644a72b710706`.

This is **assisted initialization and review**, not unattended Auto success. The existing production native inventory was reused without another detector or matcher run. Original labels, braces, aligned measure anchors and the previously frozen full source map establish all identities and bar counts. The Organ always retains both manuals and pedal; separate choir and Organ brackets are one physical system. Current native `ScoreDetectionReview`, `addScoreParts`, generated-rest editing, layout and PDF export produced the result. No production source was changed.

| Part | Original item references | Final rendered rows | Pages | Joined absent passage |
|---|---:|---:|---:|---|
| Soprano | 14 | 7 | 1 | Bars 8–66: 59 bars |
| Alto | 14 | 11 | 1 | Bars 8–36: 29 bars |
| Tenor | 14 | 7 | 1 | Bars 8–66: 59 bars |
| Bass | 14 | 14 | 2 | Bars 8–15: 8 bars |
| Organ | 14 | 14 | 3 | None |

The document retains **49 original music rows and 21 original generated-rest records**, all 70 references exactly once and in source order. Native joining renders those as 49 music rows and four rest groups. Every part’s timeline is continuous from 1 through 102. The printed seven-bar opening staves, their 3/4 meter, later lead-in rests and final printed rests remain original-source crops. No meter or tempo change occurs inside the joined absence spans.

Opening Andante is already printed for Soprano and Organ. Only Alto, Tenor and Bass receive the verified original source word `[126,329,162,342]`; all three copies are complete. Remaining lyrics, vocal dynamics and Organ registrations are kept in their own source strips.

The initial native export had one observed target loss: Organ physical page 4/system 2 (bar 68) clipped the crest of an upper-manual slur. The original filled cubic path establishes its actual top at approximately 582.57 pt including stroke. The reviewed top is 581.4 pt. Two further source-reviewed Bass bottom edges remove the duplicate Organ Andante beneath its first staff and reduce excess Organ material beneath the bar 67 lyrics. `manual-corrections.json` freezes all three changes and independent local source obligations before the final render. All other 46 music rectangles and all three copied source rectangles remain unchanged.

All six full original pages, all 11 initial pages and all 8 final pages were viewed. The final slur is complete; the two Bass cuts retain full target notes and lyric descenders. No remaining target omission was observed. An independent reviewer also inspected the full source and final outputs; the hash-bound `independent-output-review.json` records its separate findings. Neighboring lyrics, slur and beam fragments still remain, especially in Bass and Organ. The Bass bar 67 crop cannot remove every high Organ fragment with a horizontal cut while keeping the Bass lyric line. This is a preservation draft, not a clean extraction or performance-ready edition.

Soprano, Alto and Tenor now need no page turn. Bass still turns at 51→52 across a continuing vocal phrase; Organ turns at 29→30 and 66→67 during continuous playing. Those turns remain unresolved.

Validation verifies all identities, every original reference, all five 102-bar timelines, source embedding, PDF page counts/hashes, the three changed crops, complete tempo copies, page containment and all 25 frozen production Core hashes. The project was encoded with the native ISO-8601 envelope, decoded, initialized as a new `PartsmithDocument`, then re-encoded byte-identically and exported from the reopened document. This tests the model codec and native document/export path, not an app Open-panel click. An initial harness comparison incorrectly compared subsecond in-memory timestamps to the codec’s second-precision saved dates; the final check compares canonical saved bytes without altering score data.

`native-workflow-evidence.tar.gz` contains the frozen Core and private runner, reused inventory, six original page renders, initial/final full output renders, source contexts and the initial PDFs/project JSON. Binaries and duplicate original PDFs are omitted. Its member hashes were verified after creation. The final delivery has its own file hashes and keeps the immutable original PDF embedded in the editable project.
