# Brahms 93521: complete manually reviewed parts

**Complete separate manually reviewed four-part draft: 67 pages, with independent source and final-output agreement.** These are explicit manual review choices, not Auto algorithm results. They form a cleaner-output benchmark while automatic crop work continues. The published Auto delivery is untouched.

The input delivery is `output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-preservation`: 604 music bands, 42 copied directions, four parts and 67 output pages. Its seven complete neighboring-staff inclusions are removed by the reviewed horizontal rectangles without excluding any of the source-reviewed target envelopes. Smaller neighboring fragments remain conspicuous elsewhere. The separate output is `output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-reviewed-crops`.

## Source and review sequence

Original source SHA256: `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. Current corrected source SHA256: `1a3ef93cd28c5539a4732b185a6489ea4a93e16382266c387657d64e3400feb8`.

The original full-width systems on physical pages 24, 28, 31 and 38 were rendered and viewed first, including notation above and below the proposed target area. The saved corrected contexts were then viewed. Pages 28 and 38 use two of the project's nine saved rectifications; pages 24 and 31 are unchanged original pixels. The project's nine rectification records exactly equal the delivery manifest. Original and corrected coordinates are kept separate; no approximate point mapping is used.

Full-width source images with external coordinate rulers were inspected before candidate rendering. The five existing target guards relevant to this work remain unchanged. Two new full-width p38 target envelopes supplement them, frozen in `frozen-source-obligations.json` before any proposed strip was rendered. These are conservative source regions, not per-pixel musical ownership masks. They may include adjacent ink.

All seven current/proposed source-strip comparisons were then directly viewed. Candidate images are faithful rectangular crops of the saved corrected source, with labels outside the crop; no ink was erased, moved, repainted or resynthesized.

## Proposed rectangles

Coordinates are top-down corrected PDF points. All retain the full width, x=0–427. Exact unchanged fractional edges and image hashes are in `manual-proposals-v1.json`.

| Target | Current y interval | Proposed y interval | Required target and remaining overlap |
|---|---:|---:|---|
| p24 s2 Viola | 241.138–311.753 | **241.138–283.000** | Retains all staccato/articulations, slurs, beams, accidentals, cresc., forte and final hairpins. Cello's high ending notes/slurs and other upper note fragments share the vertical band of Viola's low markings. Complete Cello staff removed. |
| p24 s2 Cello | 241.138–316.497 | **270.500–316.497** | Retains the low opening ledger note/slur, all notes, upper ending half notes/sharp/slur, low dynamics and hairpins. Viola's low cresc./forte/hairpin fragments remain above the Cello staff. Complete Viola staff removed. |
| p28 s1 Violin I | 17.592–93.570 | **17.592–65.500** | Retains all high ledger notes, clef lower dot, phrase slurs, hairpin and forte. The existing printed source page number stays. Complete Violin II staff removed; only continuing structural strokes and small source specks remain below. |
| p28 s1 Violin II | 21.591–107.566 | **64.500–100.500** | Retains clef, articulation dots, low ledger/flagged notes, accidentals, slurs, hairpin and forte. Viola's high ledger note/slur/beam tips rise into the lower margin, so some fragments remain. Complete Violin I staff removed. |
| p31 s1 Violin II | 41.435–110.864 | **67.500–107.500** | Retains complete clef/key, rests, notes and flags, accidentals, staccato, piano, low slurs and final crescendo. Small neighboring dolce/Viola-beam fragments remain under the conservative padding. Complete Violin I staff removed. |
| p38 s1 Viola | 87.969–159.549 | **87.969–134.500** | Retains both voices/chords, triplet numeral, every beam/accidental, upper/lower slurs, detached tenutos, final high note with two arcs and forte. Violin II's lower beam/tenuto/dynamic fragments share the vertical band of Viola's high final slurs; Cello beam tips remain below. Complete Cello staff removed. |
| p38 s1 Cello | 91.568–165.147 | **131.500–165.147** | Retains opening low accidental/ledger note, all beams and stems, nested and long lower slurs, later low ledger notes/accidentals, every tenuto, final half note and forte. Tiny Viola/structural fragments can remain at the upper margin. Complete Viola staff removed. |

Every case admits a rectangle that removes the complete neighboring staff core. This does **not** mean each admits perfect removal of every neighboring note or marking. In particular, p24's upper Cello notes and lower Viola markings occupy overlapping y ranges, and p38 Viola's high final slurs share y ranges with Violin II's lower notation. A full-width horizontal crop must preserve those target extents even when adjacent fragments remain.

## Frozen preservation evidence

- `immutable-ten-source-guards.json` is byte-identical to the original ten-guard file: SHA256 `e097a2b80032e18b85606f4f02c13e24870162857a02bf95f6b58786f2cdbe0c`. **9/10 pass before and after.** The existing p35 Violin I guard ending at 68 pt still fails; neither its source guard nor its crop is changed. That prior failure/source-clearance distinction remains a separate finding.
- All **13/13** existing local note/mark regions remain contained, including the final expanded p35 lower-ledger region. The original source-oracle JSON is copied byte-for-byte, not reclassified.
- All **7/7** intended full target envelopes remain contained: five unchanged prior guards and the two separately frozen p38 envelopes.
- The old guard source and current corrected PDF rasterize identically on all five guard pages 24/28/29/31/35 at 4 pixels/point, so the earlier corrected-coordinate obligations are not being applied to a different geometry.
- Across all 604 rows, complete neighboring-core inclusions change **7→0** in the separate manual set. This calculation uses the unchanged physical staff-line arrays and checks entire five-line cores; it is a crop-cleanliness measurement, not proof that every music pixel belongs to its target.
- Exactly seven music rectangles change. The other 597 rectangles and all 42 source-copy records are untouched. No saved break, scale, gap, source rectification or instrument assignment changes. The final title-only cleanup is documented below.

`proposal-geometry-checks.json` records each strict guard result, all local obligations and the exact seven removed neighbor cores. Source-first visual review found no new target-note, slur, articulation, dynamic or clef loss in these seven strips. This bounded review does not certify the remaining 597 rows or solve the automatic algorithm's known ownership failures.

## Final complete output and page turns

The native saved-project exporter created all four complete parts: Violin I 18 pages, Violin II 17, Viola 17 and Violoncello 15, for **67 pages**, unchanged from the input. Every part retains 151 systems. All 604 band identities and their source order, all 42 original direction rectangles, the original embedded source PDF, nine rectifications and six explicit page breaks remain exact. The seven changed rows carry explicit `manual-source-reviewed-crop` provenance. The 597 other source rectangles remain exact.

The project was saved, decoded, compared to the intended project, reopened, and only then exported through the production layout/PDF exporter. Project JSON re-encoding and embedded source bytes are exact. The 23 compiled Core files are frozen in `Core-hashes.json` and the native evidence archive. No production implementation was changed by this task.

An unchanged-project reexport through the same frozen Core pixel-matches all 67 published Auto pages. All 67 manual pages were rendered. **42 pages are pixel-identical; 25 change:** Violin I 1/12, Violin II 1/12/13, all 17 Viola pages and Violoncello 1/9/15. The four first pages use the normal musical title “Brahms — String Quartet No. 3, Op. 67”; the old engraved title's “Auto draft” suffix was removed. Header-only comparison against the earlier manual-title fixture confirms all 604 placements exact and all four first-page bodies below 120 pt pixel-identical. Manual provenance belongs in the project filename, manifest and review notes, not the engraved music title.

All 25 changed pages were visually checked in five full-page contact sheets; all seven changed rows were additionally inspected directly from final PDFs at 3 pixels/point. All 604 rows and 42 copy placements fit on their output pages, with no inter-row collision. Native layout changes the output dimensions of two otherwise unchanged Viola rows by at most 0.0000072 pt; these recorded floating-point differences are not presented as byte-exact dimensions or a material scale change. Saved scale/gap settings are unchanged.

Only three rows move to earlier pages, all in Viola: p25/s2 moves 11→10, p27/s3 moves 12→11, and p29/s3 moves 13→12. Other parts' page allocations are exact. Before/after source contexts for all three changed Viola turns were directly inspected. The new 11→12 begins with a printed rest, but 12→13 remains within active music. No rest duration or measure count was inferred. The explicitly saved p32 rest-opening break remains, as do all six saved breaks. The tighter crops add no pages but do not make every performance turn safe.

The parent independently compared the final exports directly to the published Auto set, inspected ten full before/after pages covering all seven corrected rows and all three moved Viola systems, and checked the remaining 15 changed pages in overview. It found no new clipping or overlap. Its unmodified source review, export review, independent check script and results are included. This is bounded changed-output evidence, not a note-by-note certification of the entire score.

The first restricted export could not apply native rectification without Mac graphics access. It left only an incomplete private staging folder; the native run with graphics access succeeded. A later harness comparison initially treated subsecond in-memory dates as identical to the project's whole-second JSON codec. The harness now normalizes the new modified date before saving; the exact project roundtrip passes. Its earlier diagnostic log remains visible. The initial ultra-strict output-size assertion also exposed the two subpixel layout differences above; both exact measurements are retained rather than hidden. None of these harness iterations changed source guards, production or the prior delivery.

## Files and reproducibility

Each `*-comparison.png` shows the current Auto crop above the proposed manual crop. `original-*-full-system.png` and `rectified-*-full-system.png` supply the wider source context. `source-context-binding.json` binds the input manifest, plan, project, PDFs, original contexts and all nine saved rectifications. `report-hashes.json` freezes this report except itself.

Run `python3 Tests/quality_control/brahms-reviewed-cleanup-2026-10-03/verify_proposals.py` from the repository root for read-only input/hash and rectangle checks. It does not edit the project, invoke Auto or generate PDFs.

`output-comparison.json`, `output-visual-review.json`, `normal-title-check.json` and the independent parent results bind the final output checks. The native evidence archive preserves both relevant project JSONs/manifests, the frozen Core/harness, logs, all 25 changed page renders, the seven detailed final strips and the three page-turn source comparisons. Original PDFs and native executables are hash-bound rather than duplicated in that archive. The deliverable itself includes the immutable original PDF inside its editable project.

The downloadable ZIP contains the four complete PDFs, editable project, review notes and supporting manifest/plan/source-review records. Both the ZIP and individual outputs are covered by the delivery hash manifest. Existing fragments, duplicated markings, damaged original print, the unchanged p35 strict guard failure and remaining difficult turns are explicit draft limitations.
