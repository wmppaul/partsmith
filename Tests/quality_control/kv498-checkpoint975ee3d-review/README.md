# Mozart KV498 complete baseline output review

The baseline remains **draft**. The complete ensemble is present structurally, but the viola and piano omit required shared headings and repeat-ending brackets. Neighboring notation remains conspicuous. No crops or output files were edited during this review.

## Scope and binding

Reviewed all 38 final pages: Clarinet in B-flat 11, Viola 10, Piano 17. `review.json` binds the source, inventory, profile, manifest, PDFs and all page renders by SHA256. The immutable source is the 29-page normal Mozart KV498 PDF, SHA256 `f4b64106fa23d408943ec49e86d4bc0177f634c73ce7e146f7ee2f8f5ecbe9c9`. This report applies to `.build/auto-qc/checkpoint975ee3d/corpus/normal-mozart-trio-eb-major-kv498-score/parts` only.

## Findings

- **Identity and structural coverage:** the printed opening labels, keys, clefs and braces agree with the fixed clarinet / viola / piano roster. Movement layouts on source pages 12, 13 and 17 retain that order. Every one of the 135 inventory systems appears exactly once and in order in every part: 405 bands covering 540 physical staves. The piano grand staff stays paired. This is exact inventory coverage, not an independent note-recognition proof of all source pages.
- **Target edges:** all final pages were visually inspected in contact sheets; 30 bands with the closest target staff-to-edge distances were compared to larger source contexts at detailed resolution. No target note, slur, dynamic or ornament was found cut in those cases. Their identifiers and coordinates are in `edge-cases.json`, with six source-context montages. A separate analyzer-component containment check found no flags across 405 bands, but uses analyzer ownership and does not establish completeness of detached or shared marks. The review is not a note-by-note source comparison of all 405 bands.
- **Missing shared headings:** Andante (source p1 system1), Menuetto (p12 system3), Trio (p13 system3), and Rondo / Allegretto (p17 system1) appear only in the clarinet part. Viola and piano lack these directions. Four source/output comparison images show the omissions.
- **Missing repeat endings:** source p25 system3 has first- and second-ending brackets above the clarinet. Clarinet output p10 includes them; Viola p9 and Piano p15 omit them. `repeat-endings-p25.png` shows the source and all three actual output bands. This changes how the repeat can be followed and remains a required correction even if the headings are later repaired.
- **Neighboring notation:** sliced notes, stems, slurs, dynamics and partial staff lines remain in many bands. A particularly misleading fragment is the previous system's piano bass at the top of Clarinet output p10, before the intended p24 system5 clarinet at m141. `clarinet-p24-s5-source.png` and `clarinet-010.png` preserve the source/output evidence. No missing clarinet target was found there. Some source page numbers remain alongside measure numbers.
- **Layout:** no obvious overflow, title collision, intersystem collision, blank page or mostly empty page was seen. Staff heights are approximately 13.76–14.05 pt, which is compact. Movement starts are not consistently placed at page starts; Rondo begins in the last system of Clarinet p6. Musical page turns have not been optimized. The filename-style QC header is intentional test metadata, not polished title/composer extraction.

`source-direction-guards.json` freezes five independently source-derived heading envelopes and the two-ending bracket envelope **before** any experimental heading run. Heading rectangles use visible dark pixels inside independently verified PDF word boxes plus a 0.5 pt guard; they are independent of the extraction crop. The ending envelope is based on printed glyphs and source vector bracket positions. These obligations must not be shrunk or omitted to make a later candidate pass.

Other shared directions, system bar labels and repeat destinations have not been exhaustively inventoried. The absence of a listed defect is not a general musical-completeness pass.

## Experimental heading follow-up

The first sandboxed run was an **OCR execution failure, not a recognizer-recall result**. macOS Vision threw `Foundation._GenericObjCError code 0` before returning text. The original implementation silently caught the errors. That failed run and its baseline-identical output are retained in `headings-experiment.json`; they must not be counted as a valid zero-match analysis.

An exact-render probe outside the sandbox succeeded. The unchanged checkpoint recognizer then found Andante, Trio and Rondo/Allegretto. It read Menuetto correctly at confidence 1.0 in regional and full-page OCR, but rejected it solely because the heading vocabulary did not include that word. Planner validity and spatial gates passed.

The narrowly changed recognizer accepts standalone Menuetto, with all existing position/confidence rules retained. In a complete 29-page comparison against the successful frozen recognizer, only source page 12's metadata changes. The final export is `.build/auto-qc/kv498-headings/menuetto-parts`, bound by `menuetto-experiment.json`. All 405 main crop rectangles and ordered candidate assignments are unchanged. All 39 final pages (11 clarinet, 10 viola, 18 piano) were visually inspected in contact sheets; no obvious overflow or collision was found. The extra piano page and movement-at-bottom turns remain layout tradeoffs.

All 15 frozen heading-word obligations now fit their correct part/system. Including the ending-bracket obligation for each part, 16 of 18 total obligations are met. The two missing obligations remain the viola and piano endings, now on Viola p9 and Piano p16. These remain required. No oracle guard was modified.

A new **duplicate Rondo/Allegretto** appears in Clarinet p6. Its actual source glyphs already fit the main crop, but the padded OCR copy starts 0.3341 pt above that crop, causing a complete second copy. This is a visible quality defect, not a preservation fix. The new lower-part headings also retain small source slur fragments. Neighboring notation and unreviewed shared-mark obligations remain, so this is not a finished musical-completeness pass.

## Runtime diagnostic fix

The heading and navigation detectors now have optional `observedFailure` callbacks for Vision errors. The experimental CLI aborts before its final atomic write on those errors and explicitly reports that the destination was not updated; an old output remains unchanged. Interactive app acceptance is unchanged. This is deliberately not a complete attempted/skipped/cancelled result model: existing planner-validation and cancellation empty results remain unchanged.

Validation: 49 heading checks, 61 navigation checks, and four actual failing-service CLI cases (headings/navigation, existing/absent destination). Each CLI case returned a failure, reported the Vision exception and left the destination unchanged or absent. Hash-bound evidence and source-file hashes are in `ocr-diagnostic-validation.json`.
