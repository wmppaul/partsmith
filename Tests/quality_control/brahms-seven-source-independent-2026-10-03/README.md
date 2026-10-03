# Independent source obligations for the seven remaining Brahms overlaps

I found no target-note or marking omission in the seven existing manual benchmark rectangles. Each of the seven current Auto crops can lose its complete foreign staff core while keeping the unchanged source envelopes below. This does not establish that a single full-width rectangle can remove all neighboring ink. Several musical extents overlap vertically, so preserving their target notes and markings necessarily retains foreign fragments.

The source is Brahms String Quartet No. 3, Op. 67, IMSLP93521, original SHA256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. The original full-width systems on physical pages 24, 28, 31 and 38 were directly inspected, followed by their corrected coordinate contexts and all seven Auto/manual comparisons. This review did not inspect the new implementation experiment. It was not blinded to the existing manual benchmark or its prior source notes.

## Per-case obligations

All rectangles below are **existing, unchanged source guards**, in top-down corrected PDF points `[left, top, right, bottom]`. They are conservative regions that can contain foreign ink, not per-pixel ownership masks. Source page size is 427 × 615 pt. Pages 24/31 retain original coordinates; pages 28/38 use the saved rectifications. Staff IDs are zero-based native candidate IDs; page/system names are one-based.

| Band / native staff ID | Unchanged required envelope | Specific target notes and marks that tightening must retain |
|---|---|---|
| `p24-s2-viola` / 6 | `[0,243,427,281.5]` | Clef/key; initial beamed figures and all upper slurs/staccato dots; middle accidentals, beams and cresc.; low penultimate sharp/note and complete forte; final hollow notes, right-edge slur and both hairpins. The local forte at y272–281.5 must not be classified as Cello material. |
| `p24-s2-cello` / 7 | `[0,272.5,427,315.5]` | Low opening ledger note and incoming lower slur; all beamed/flagged notes and articulation dots; cresc. and penultimate low sharp/note/slur/forte; final high half notes with sharp, last high note/slur and both closing hairpins. The high closing Cello phrase reaches into the space used by Viola's lower dynamics. |
| `p28-s1-violin1` / 0 | `[0,24,427,64]` | Complete treble clef including its low dot, accidentals, upper ledger notes, all phrase arcs, flagged notes, low crescendo wedge and following forte. The retained printed page number is nonmusical context and is not a reason to trim target ink. |
| `p28-s1-violin2` / 1 | `[0,66,427,98.5]` | Clef, rests, articulation dots, accidentals, low ledger and flagged notes, all lower slurs, fifth-bar crescendo and following forte. Its bottom overlaps the high Viola phrase, so a neighboring high note/arc fragment remains even in the benchmark. |
| `p31-s1-violin2` / 1 | `[35,69,394,105.5]` | Complete clef and two-flat key; initial rest, beamed entries, sharps and articulation dots; detached piano and low slurs; final flagged pair, complete lower slur and crescendo. The nearby dolce belongs to Violin I. Broken print at the right side is already present in the original. |
| `p38-s1-viola` / 2 | `[0,90,427,133]` | Opening triplet numeral and both voices/chords; every beam, accidental and ledger note; upper and nested lower phrase arcs; all detached lower tenutos; later natural; final high flagged note with both right-edge arcs; complete final forte. Low Violin II beams/tenutos overlap the vertical range needed by the final Viola arcs. |
| `p38-s1-cello` / 3 | `[0,132.5,427,163]` | Opening accidental and low ledger note, nested lower arcs and tenuto; all following beams/stems and long lower slurs; later natural/low notes and detached tenutos; final hollow note and complete forte. These low detached marks remain target material although disconnected from the staff. |

`case-bounds-and-validation.json` gives exact current Auto bounds, stored native bounds, manual bounds, removed neighbor-core identities and every source staff ID. All seven stored native rectangles equal the published Auto plan exactly. This uses the preserved native four-page/64-band result, not a new detector run. The separately published manual plan equals the benchmark to floating-point serialization precision (maximum difference 7.5e-14 pt); these tiny differences are recorded separately from exact native-versus-Auto equality.

## Rectangle limits and benchmark findings

- **p24 Viola/Cello:** Cello's high closing notes and arc share y with Viola's low forte/hairpins. Both target rows can be separated from the other's full five-line core, but every foreign fragment cannot be excluded by a full-width crop.
- **p28 Violin II:** its lower slur, crescendo and forte must remain. The Viola's high ledger note and arc intrude into that same lower margin. Removing those solely by raising the crop bottom would risk the Violin II phrase.
- **p38 Viola:** its high final note and two arcs require an upper boundary that also retains lower Violin II notation. Moving only the lower boundary removes the complete Cello core; it does not clean the unrelated upper fragments.
- **p28 Violin I and p38 Cello:** the manual rows remove the large neighboring core cleanly apart from small structural/edge fragments. Those fragments do not justify an automatic declaration of musical ownership for the connecting stroke.
- **p31 Violin II:** the current benchmark leaves small dolce/Viola-beam fragments. Some are conservative padding; this review does not assert all are mathematically unavoidable. Its intact target clef, low piano/slurs and closing hairpin remain the relevant constraints.

No new global heading, rehearsal mark or repeat-ending obligation was identified in the seven changed edge regions. The visible cresc., piano, forte, hairpins, slurs and tenutos above are local printed target directions. This is a bounded source-region conclusion, not certification of all shared directions elsewhere on these pages or in the score.

The manual benchmark has no newly demonstrated target-preservation defect in this review. It remains a manual benchmark with visible foreign fragments and original damaged print, not an Auto result or a claim of clean engraving.

## Supplemental frozen evidence

The previous ten guards and thirteen local obligations are hash-bound unchanged in `inputs.json`; the separate p35 Violin I 68-pt rectangular-guard failure remains 9/10 and is outside these seven cases. Existing local obligations remain 13/13. All seven relevant broad target envelopes are preserved by current and manual crops.

`additional-local-obligations.json` adds twelve source-reviewed named regions: detached dynamics on p24/p28/p31, and p38's triplet/chords/lower slurs, last high note/arcs, detached tenutos, opening Cello accidental/slurs and final fortes. These are all subsets of the unchanged broad guards. They add explicit musical identity and inspectable source images without shrinking or replacing any prior guard. Their exact PNGs are crops of the hash-bound 4-pixel/point source contexts; no source ink was removed, retouched or resynthesized. The boxes may include neighboring or structural pixels and must not be used as exclusive pixel-ownership labels.

All eight original/corrected full-system images and seven before/after comparisons are retained here, unchanged from the bound source review. `inputs.json` records the original PDFs, nine rectifications, published Auto/manual plans, stored native result and all referenced source-oracle hashes. `report-hashes.json` covers this report and its images. This review changes no production file, output, source guard or expected mask.
