# Brahms 242312 and 09200: complete native glyph-continuation exports

These are complete draft part sets from the two fresh native document-worker runs, with the initial **A** in the copied **Agitato** heading restored. All eight PDFs were rendered and visually reviewed. Relative to the matching actual native baseline, all 960 main source crops and all 960 main output placements are identical; 78 of 84 output pages are pixel-identical. The only six changed pages are output page 6 of Violin II, Viola and Violoncello in each edition.

This is a bounded heading-preservation validation. Existing neighboring notation, duplicate directions and missed repeat endings remain. These drafts are not certified performance-ready parts.

## Delivered sets

| Original edition | Violin I | Violin II | Viola | Violoncello | Total |
| --- | ---: | ---: | ---: | ---: | ---: |
| [IMSLP 242312](../../../output/pdf/auto-qc-2026-09-21/brahms-quartet-242312-glyph-continuation/README.md) | 11 | 11 | 10 | 11 | 43 pages |
| [IMSLP 09200](../../../output/pdf/auto-qc-2026-09-21/brahms-quartet-09200-glyph-continuation/README.md) | 11 | 10 | 10 | 10 | 41 pages |

Every part contains 120 music strips; each edition has 480 strips and 29 copied directions (Violin I: 1; Violin II: 9; Viola: 10; Violoncello: 9). Each folder contains the four PDFs, complete placement manifest and extraction plan, and an editable Partsmith project with its original source PDF embedded. Earlier drafts are preserved. The eight original export files per edition were hashed before copying and verified byte-for-byte afterward. `delivery-hashes.json` covers each delivered file except itself.

242312 has 26 physical pages. The final publisher catalogue page was automatically skipped as nonmusic; it is not blank. All 25 music pages are present. [The skipped source page](source-242312-p26-auto-skipped.png) was rendered and directly inspected. All 25 source pages of 09200 were used.

## Provenance and method

Both runs used their saved four-instrument profiles, typed title `Brahms — String Quartet No. 3, Op. 67`, composer `Johannes Brahms`, and the native shared-direction workflow. No manual crop overrides or rectification were added. This is not an evaluation of discovering the instrument list from scratch.

The comparison uses actual full document-worker baseline inventories generated from frozen e9ef3d1 Core and actual full candidate worker inventories, not restored-box fixtures. The frozen Core trees differ only in `Detection/ScoreSharedHeadingDetector.swift`; layout and export implementation are byte-identical. Candidate detector SHA-256: `9e6ca0f8b208068d0de6219a6d8997cd2038c9b0b43fd888eb41732b6d6a2db9`.

The same frozen exporter rendered both baseline and candidate inventories. It applies the native plan, encodes and decodes the document, verifies byte-identical persisted JSON and unchanged profile/corrections/bands/source, then exports the reopened document. Its persistence validation appears in the four export logs. Both actual candidate worker summaries report no issues, `canApply: true`, and an unchanged input document. Exported plans exactly match their corresponding native worker plans.

Original source SHA-256:

- 242312: `b74b4f3ebf951a78e6b11faf889033d6da3e8bd4759fb5d8197eb0b65e96059e`.
- 09200: `ff883e06db2bc69c5de0c45fa447795201805ecf7210b76c50168b64f0570689`.

[Input bindings](input-bindings.json) record the source/profile, frozen Core and candidate worker/export hashes. [Comparison bindings](comparison.json) also bind the actual baseline inputs and both output manifests. [Native evidence](native-evidence.zip) preserves both frozen Core trees, native harness/config/logs/inventories/plans/summaries, exporter source/build script, profiles, original A guards, and exported project/placement records. [The archive manifest](archive-manifest.json) hashes every archived entry and the ZIP; its contents were re-read and verified. Executables and duplicate source PDFs are excluded. Sources remain in the project bundles and source corpus; baseline PDFs remain scratch outputs reproducible with the preserved inventories and exporter.

## Output verification

[The layout review](output-review.json) covers all 84 candidate pages, all 960 strips and all 58 copied direction rows. Checks found no off-page content, dropped/out-of-order bands, inter-row collisions, source/destination aspect-ratio errors, or mismatches in copied-source horizontal mapping. Every planned target staff's five lines remain inside its source crop; this does not prove that all ledger notes and attachments are present.

All 84 baseline pages and all 84 candidate pages were rendered at 144 dpi for exact pixel comparison. Candidate pages were inspected in the `pages/` contact sheets; all 58 copied rows and original source contexts were inspected in `rows/` and `sources/`, with larger images in `copied-rows/` and `copied-sources/`. All six changed rows were viewed before and after, and all six full changed pages were inspected. `changed-pages/` and `changed-rows/` preserve those images. The copied final delivery PDFs were separately rendered and viewed in `delivered-242312-violin2-p6.png` and `delivered-09200-violin2-p6.png`.

The original frozen A guards were inspected independently before candidate comparison in [the glyph review](../heading-glyph-independent/README.md). Applied to the actual full native outputs, all six copied headings retain every frozen dark pixel: 57 for each 242312 copy and 199 for each 09200 copy, with zero outside the final source boxes. These native raster bounds differ slightly from the earlier fixed-resolution heading replay; the actual native boxes were checked directly.

- 242312's three source boxes expand left by 0.6374746075543385 pt; their destination boxes expand left by 0.5526493573555911 pt.
- 09200's three source boxes expand left by 3.7318448337278483 pt; their destination boxes expand left by 3.167157786518999 pt.
- The other three source edges and both vertical destination edges are identical. 09200's destination right edge differs only by the recorded floating-point rounding of 1.1368683772161603e-13 pt; this is not represented as bit-exact equality.
- [Pixel-change localization](pixel-change-localization.json) confirms all differences lie within the copied heading area, including a one-point raster-edge margin. Main notation positions and pagination remain unchanged.

`render_review.py` and `compare.py` reproduce the layout, source-guard and pixel checks against the hash-bound inputs. `render-review.log` and `compare.log` preserve their successful completion. Initial local script mistakes (using the wrong plan key and asserting exact equality for the 1e-13 pt right-edge roundoff) were corrected before the recorded passing run; source guards and acceptance bounds were not changed.

## Remaining limits

Substantial neighboring notation, sometimes an entire extra staff, remains in these unchanged main crops. Several copied headings include partial clefs, stems, beams, slurs or text fragments. These were visible in the all-row review and are not cleaned by this change. The 242312 Violoncello output page 10 retains a pre-existing doubled “Doppio Movimento” at adjacent row boundaries: the preceding main crop already includes the next system's heading, and a separate heading copy is placed above its intended row.

Known undetected first/second ending pairs in both editions remain on physical source page 21/system 3, page 23/system 4 and page 24/system 2. The current native result recognizes the earlier page-4 pair. See [the earlier source/output review](../ending-corpus-2026-10-03/README.md) for these observed misses; whole-score ending recall is not established. An experimental wider OCR fallback was not included.

This review does not audit every source note, establish complete repeat/navigation coverage, optimize musical page turns, or certify rest compression. It validates preservation of the two previously clipped heading initials and the resulting complete native output against its matching baseline. General geometric-impostor and repeated-helper limits remain documented in [the independent glyph review](../heading-glyph-independent/README.md).
