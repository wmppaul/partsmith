# Schumann 06822 — fresh native app-workflow validation

Draft reviewed output, 2026-10-03. The app’s complete native Auto workflow preserves the previously verified local-ending result on the actual scanned full score. All five parts export successfully. Existing heading and neighboring-notation limitations remain; this is not a print-ready approval or a whole-score recall claim.

## What ran

The final production `PartsmithDocument.detectScore(profile:copySharedDirections:true)` worker performed fresh staff detection, shared headings/navigation/endings, and recipient-local ending detection over the original 56-page Schumann score. The empty first physical page was automatically skipped; 55 music pages yield 165 systems for each of five parts. No hand-authored direction metadata was injected. The resulting plan can apply, reports no assignment issues, leaves the project untouched during detection, and clears progress on completion.

The exporter was compiled against the same frozen Core snapshot as the worker. All 23 Core source hashes still match production at report finalization. `provenance.json` binds the source, profile, worker/config, inventory/plan, exporter, all PDFs, source-embedded project and prior baseline. Original source SHA-256: `b8b9f6431438a6bd4c9593fffb46278418fbb211b7d81b6953d920faf8cf744e`.

Output: `.build/ending-local-app-native-2026-10-03/schumann-parts/`. It contains five full PDFs, manifest and an editable project whose embedded source PDF matches the original hash.

| Part | Systems | Pages | Pages changed versus ending-only candidate |
| --- | ---: | ---: | --- |
| Violin I | 165 | 12 | None |
| Violin II | 165 | 12 | 1–12 |
| Viola | 165 | 12 | 1–12 |
| Violoncello | 165 | 12 | 1–12 |
| Piano | 165 | 26 | 1, 9, 12, 18 |

Total: 825 main crops, 74 pages. Every main crop, staff identity, source page, system and order matches the prior ending-only local-counterpart candidate. All 15 ending source copies are unchanged. The complete workflow adds 20 source copies, all headings: five each to Violin II, Viola, Cello and Piano. They correspond to physical p2s1 Allegro brillante, p19s3 Agitato, p26s1 SCHERZO, p38s2 Coda, and p39s3 Allegro ma non troppo. No navigation copies were added. Output has 35 source copies overall.

There are 501 moved band placements as headings are fitted, 40 changed page rasters and 34 pixel-identical page rasters. The page count remains 74. Geometric checks find no page overflow or adjacent band-plus-copy envelope overlap. These checks describe layout only and do not prove recognition recall.

## Local-ending result

Five Piano rows retain their own printed paired endings without a duplicate global copy: p6s1, p6s2, p16s3, p18s2 and p20s3 (physical page/system numbering). They are output Piano pages 3, 3, 8, 8 and 9. The four complete locally matched pairs retain original printed numerals and brackets. The Cello p18s2 crop still includes a neighboring Piano ending below its staff; it is not treated as a Cello-owned counterpart.

## Visual review and limits

The author inspected each of the five distinct original source contexts before its exact copied box, all 20 newly copied recipient rows, all 40 changed output pages on ten full-page contact sheets, and all five corrected Piano ending rows. All 74 pages were rendered at 108 dpi. Individual new rows are rendered at 144 dpi and source contexts/exact boxes at 216 dpi. `new-copy-rows.json`, `changed-page-index.json`, `comparison.json` and the image folders preserve the evidence. A separate independent reviewer is examining the same export; its result is recorded separately.

The complete-workflow export exposes existing heading behavior that was absent from the ending-only baseline:

- The four SCHERZO copies include clipped top fragments of the adjacent Molto vivace line. The top-staff full Molto vivace and metronome marking is not copied. Piano retains its own Molto vivace text; Cello also contains that neighboring Piano text below its staff. Violin II and Viola lack the full wording.
- Piano p2s1 repeats Allegro brillante: the newly copied version includes a metronome missing from the local wording. Piano p19s3 repeats Agitato exactly. An ending-specific counterpart rule does not remove headings.
- Dense source crops continue to retain neighboring notation, including extra staff fragments. Small neighboring accents also appear in some copied heading boxes. These are pre-existing crop/heading scope, with unchanged main crops.
- The previously observed Schumann p29s3 missed ending pair remains. Unsupported/global ending recall has not been established. The wider-numeral OCR experiment and alternate Schumann tempo candidate are not in this production run.

These findings are frozen in `known-limitations.json`; no production changes were made for this report. The result validates local-ending deduplication end to end while retaining a draft label for the broader output.

Runtime was 133.97 seconds wall time and 131.30 seconds awake time. Maximum main-thread heartbeat interval was 1.157 seconds wall / 0.218 seconds awake. These are measurements of this run under concurrent checks, not responsiveness guarantees.

Reproduce the export with `bash .build/ending-local-app-native-2026-10-03/export-schumann.sh` only into a new output location if preserving this frozen export. The archived `compare.py` expects the fixed current and prior paths; it does not run OCR. Recognition input and binary hashes are in provenance.

## Delivered copy

The complete reviewed payload is also preserved at [`output/pdf/auto-qc-2026-09-21/schumann-quintet-06822-native-auto/`](../../../output/pdf/auto-qc-2026-09-21/schumann-quintet-06822-native-auto/). Every PDF, project payload and manifest was hash-checked before and after copying. `delivery.json` records the exact delivery hashes. The concise output README retains the known draft limitations. Older output sets are unchanged.

After copying, the author re-rendered and inspected delivered Piano page 9 and Violin II page 2 directly from the delivered PDFs (`delivered-piano-page-9.png`, `delivered-violin2-page-2.png`). They match the reviewed draft: the Piano local ending is single; its Agitato duplication remains explicitly documented.
