# Medium-scan Brahms Trio114012: independent Clarinet and Cello source review

All 262 bands (131 per part) across musical PDF pages1–33 were visually checked against the fresh medium-skewed original. No light114011 review coordinates were reused. The revised native Auto plan contains every nominated target envelope. This is a source review, not approval of the final PDFs.

## Evidence and method

- Source: `sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf`.
- SourceSHA-256: `0f617f77acf2e257973b14a8ce558e88eca877835df6fff4894419e66c871e4b`.
- Machine review: `clarinet-cello-review.json`, SHA-256 `a702637a68f3c52073f5df40cecb5695cee0e2592d9f25c72329a261731a0791`.
- Original Auto planSHA-256: `f7695db4fbe94be5b44486dfb14bdad51678d08314ee7af9e9d275c486d85a09`.
- Revised Auto planSHA-256: `a07ff8c086f00b89926faf91e4963d5ec9181750a80acc34745ea66248482948`.
- All 66 source sheets are in `clarinet-cello/{clarinet,cello}-p01.png` through p33. They show all 262 bands at 3x with original source-point rulers and original Auto crop edges. Seven flagged crop-edge cases were inspected enlarged, including five 9x edge proofs. The JSON records concrete notes/marks for every band.
- Protected envelopes describe observed target notes, stems, beams, slurs/ties, articulations, dynamics, clefs and relevant headings, with conservative stroke allowance. They retain full source width; this review establishes vertical extents. `suggestedRect` adds 1.25 pt top/bottom space. It is a manual reference, not a claim of automatic geometry.
- Source contains 3 systems on p1 and 4 on p2–33. P34 is blank; p35 is publisher material. Movement openings are p1,12,18,26.

## Preservation findings

Seven original Auto top edges cut real Cello ink. All seven are covered by the revised component recovery and extra top clearance; none requires an additional preservation rectangle in the revised plan.

| Band | Original top | Reviewed ink envelope top | Revised top |
|---|---:|---:|---:|
| p17-s1-cello | 90.24 | 85.25 | 80.29 |
| p18-s1-cello | 97.18 | 94.00 | 89.88 |
| p26-s3-cello | 448.96 | 446.00 | 440.00 |
| p27-s3-cello | 466.48 | 463.00 | 457.52 |
| p30-s1-cello | 82.97 | 81.00 | 73.68 |
| p31-s3-cello | 452.92 | 450.50 | 448.92 |
| p32-s1-cello | 79.33 | 79.00 | 71.36 |

The cut elements are respectively the p17 outer phrase arch, p18 opening `pizz.` letters/dot, p26 chromatic phrase arch, p27 `espress.` letters, p30 ledger-note arch crown, p31 final high arch crown, and the very small p32 opening arch crown. The last case is a narrow grazing cut rather than a missing notehead. Enlarged source PNGs preserve the original failing-edge evidence.

## Context and shared markings

131 bands have material context cleanup recommendations (62 Clarinet, 69 Cello): an independently observed avoidable neighboring group and more than 5 pt excess beyond the buffered target envelope. The other 131 bands are marked retain-auto. Root can further screen these recommendations against neighboring staff centers. Do not apply every suggested rectangle merely because it is tighter. Some source slurs, hairpins, dynamics, or very low notes share a vertical range with another part; small unavoidable fragments are acceptable.

Examples of material context include Clarinet p25s1 retaining the Cello staff, Cello p25s1 retaining the Clarinet staff, Clarinet p24s3/p25s4 retaining previous piano ledger-note groups, and numerous Cello strips retaining following piano chord groups. These are context quality defects, distinct from omitted target notation.

Seven freshly measured shared tempo fragments for Cello are in `sharedMarkings`, with all glyphs visually checked in `clarinet-cello/shared-tempo-proofs.png`: p1 Allegro; p11s1 rit.; p11s2 Poco meno Allegro; p12 Adagio; p18 Andante grazioso; p25s3 Un poco sostenuto; p26 Allegro. Clarinet already contains these source headings; Piano has separately printed duplicates. Adagio and Un poco sostenuto fragments carry a small neighboring source slur because the lettering is tightly spaced above it. Complete source bar-number fragments are supplied separately by score_survey in `piano-shared-gutters.json` (127 verified labels); they were not redundantly transcribed here.

## Limitations and next check

These observations and coverage checks do not mechanically discover every musical note. The conclusion relies on visual source comparison of every band. Guard containment proves the nominated source regions fit the crop. It does not replace the final source-to-output pixel comparison, readable PDF page review, or a player's rehearsal/page-turn judgment. No source masks, re-engraving, or production edits were made by this review. Final native output may use an explicitly counted subset of the proposed source-reviewed corrections.
