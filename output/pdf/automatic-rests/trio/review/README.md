# Brahms Trio automatic-rest export review

**Pass for the automatic-rest changes and complete-output layout.** All 48 output pages were visually reviewed in contact sheets. The parts remain 12 Clarinet, 12 Cello and 24 Piano pages, with 131 original source bands per instrument and no added page turns.

Two source-only rest lines were replaced automatically:

| Part | Source | Verified bars | Output | Following music |
| --- | --- | --- | --- | --- |
| Clarinet in A | PDF page 3, system 1 | Six rests, 42–47 | Page 1 | The band beginning 48 retains the partial rests, sounding entry and `p` at 51, then its slurred phrase. |
| Cello | PDF page 4, system 4 | Seven rests, 76–82 | Page 2 | Bar 83's `mf` entry and the full subsequent phrase match source PDF page 5, including slurs, accidental, hairpins and `f`. |

The rendered multi-bar counts are 6 and 7. Original scanned clefs, the Clarinet key signature, source ending barlines, and copied bar labels 42/76 remain visible. The enlarged comparisons are `clarinet-rest-and-entry.png` and `cello-rest-and-entry.png`; source pages 3–5 are alongside them.

The editable project has exactly the same 393 band IDs, order, crop geometry, shared markings, parts and settings as the previously reviewed project. Only these two `restReplacement` fields and the modification timestamp changed. Embedded source bytes are unchanged.

PDF drawing streams are identical to the baseline on all 46 unaffected pages; only Clarinet page 1 and Cello page 2 changed. All 24 Piano page drawing streams are identical, and their 100-dpi rendered pixels match exactly. PDF container hashes differ, so byte-for-byte PDF identity is not claimed. Exact artifact hashes and test details are in `review.json`.

This is automatic rest detection on the earlier reviewed extraction, which already contains score-specific crop and shared-marking corrections. Those existing corrections and its small study-score staff size remain; this is not a new untouched Auto extraction. The review establishes preserved music and unchanged pagination for this delta, not rehearsal-tested page turns.

The final detector release rerun produced the same two replacement counts and source contexts. All 48 page drawing streams and 72-dpi page pixels are identical to the reviewed run. This copied review records the release artifact hashes; previous reviewed hashes remain in `priorReviewedHashes`.
