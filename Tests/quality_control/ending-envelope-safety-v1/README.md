# Ending safety-envelope investigation

Keep the current ending copies for now. A uniform one-staff-space allowance can contain all frozen guards in the actual source-copy rows, but it adds detached neighboring music without recovering any missing ending ink. The experiment remains scratch-only; no production crop, guard, or delivered PDF was changed.

Source-first inspection explains the six failed Brahms guard envelopes:

| Source | What lies beyond the current copy inside the frozen guard |
| --- | --- |
| p6, system 3, first ending | Part of the separate one-bar-rest count `1`, below the complete ending numeral and hook |
| p6, system 4, second ending | The top of the first violin's beamed notes |
| p32, system 4, first ending | Blank upper margin |
| p32, system 4, second ending | Blank upper margin |
| p37, system 2, first ending | Blank lower margin |
| p37, system 2, second ending | Blank upper margin and part of a first-violin slur below |

The original ending numerals, lines, and hooks are complete. The red pixels in `source-contexts/*-guard-only-ink.png` show dark source ink inside the fixed guard but outside the old copy. Pixel measurement uses a fixed 170 gray threshold at 576 dpi; each result was also visually checked against the unmarked original source image. The three blank cases contain no dark source pixels in the overhang. The other three contain unrelated musical ink, so a raw rectangular crop containing those entire guards necessarily includes that ink.

The candidate applies one local staff space on all four sides of the measured bracket geometry, taking the lower of the geometry bottom and measured descending right-hook bottom before adding the allowance. Its rule has no score IDs, guard coordinates, or per-case tuning. It is a generic alternative to the existing smaller top/side and bottom allowances.

The complete 68-page frozen recognition rosters were replayed, covering all 13 numeral-like candidates and all five accepted first/second pairs. Pair identities and literal OCR evidence remain identical; a new OCR sweep was unnecessary because only the post-recognition copy allowance changed. Thirty-two native controls passed, including old-copy containment, page bounds, invalid geometry, unchanged pairing, and every immutable guard in its actual paired source row.

At the individual-bracket level, the p37 first-ending candidate still falls 0.215246 points short of its frozen lower guard. The required same-system union with the second ending extends to 181.317278 points and contains both guards. This individual failure remains in the evidence. The experiment does not redefine the frozen rectangles or raise a tolerance to hide it. Mozart's combined guard also becomes contained; its earlier delivered crop was 0.293060 points short in a blank margin.

Both complete scores were exported with the existing frozen native exporter and compared with the delivered drafts. All 1,009 main crops, staff identities, score order, and output-page assignments remain unchanged. All 52 source-copy rows remain: 35 unrelated copies are unchanged and 17 ending rows have expanded rectangles. Page counts stay 64 for Brahms and 39 for Mozart. There is no intersystem overlap or output-page overflow. Ninety of 103 pages are pixel-identical at 108 dpi; 13 pages change and 71 unchanged music rows shift vertically to accommodate the extra copy height.

All 17 changed copied rows were visually checked at 216 dpi; all 13 changed pages were checked in contact sheets. Intended endings remain complete and aligned. However, the larger margins copy more of the unrelated rest-count `1`, a detached beam at Brahms p6, a slur fragment at p37, and notehead/staff-line fragments at p36. They also add tiny clarinet stem/slur fragments to the Mozart viola and piano rows. Those are readability regressions, despite the improved envelope-containment result.

The recommended next step is to keep geometric envelope failures and visible-ink findings separate in the evidence while integrating the already reviewed ending recognition with explicit provenance. A later ink-aware copy rule could improve safety without copying unrelated components, but this blanket expansion should not be promoted merely to make the guard checks pass. The original wider envelopes remain available and unchanged for future comparisons.

`review.json` binds the immutable sources, guards, recognition reports, current detector, frozen exporter, baseline/candidate PDFs, all manifests, and visual evidence. `prototype/ScoreSharedEndingDetector.swift` contains the scratch margin variant. Scratch complete outputs are in `.build/qc-ending-envelope-safety/brahms-parts/` and `.build/qc-ending-envelope-safety/kv498-parts-matched-title/`.
