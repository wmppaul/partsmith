# Source-reviewed page-turn alternative, 2026-10-03

The complete Brahms 93521 alternative has **67 pages rather than the compact draft's 64**: First Violin 18, Second Violin 17, Viola 17, Cello 15. It uses six existing `pageBreakBefore` choices, identical music/copy source rectangles and unchanged scale settings. The compact set remains available. This is a bounded improvement around the fourth movement, not a claim that every turn in the quartet is now suitable for unaided performance.

Delivery: `output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-page-turns/`. The source-embedded editable project, four complete PDFs, native manifest/plan, explicit-break inventory and `REVIEW.md` are included. No production source was edited for this study.

## Evidence and preservation

The source is the original 39-page `sample_scores/medium_skewed/06_brahms_string_quartet_no3_op67_imslp_93521.pdf`, SHA-256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. The same nine saved page corrections and frozen Core from `.build/brahms-continuation-release-2026-10-03/candidate/Core/` were used. The compact comparison is `brahms-quartet-93521-continuation`, not an older export lacking current directions.

`layout-review.json` and `review_layout.py` establish all 604 source strips, 42 copied directions, source ordering, staff-line coordinates, crop bounds and layout settings unchanged. All six requested breaks are persisted and begin output pages. All placements remain inside the page, without inter-row collision. Destination y positions and page numbers intentionally change. Eight fitted destination dimensions differ only by existing floating-point layout arithmetic, maximum width 0.000007620 pt and height 0.000000897 pt; the raw differences are retained. This numerical tolerance is not applied to source rectangles or guards.

`reexport-verification.json` verifies byte-exact project JSON codec roundtrip, six persisted breaks, reopening the actual embedded-source package, all 604 music and 42 copied-direction placements exactly equal, and all **67 pages pixel-identical at 144 dpi** on native reexport. Native PDF byte hashes differ because PDF metadata is regenerated. `final-pixel-equivalence.json` additionally shows that the three upper-part PDFs match the already reviewed fourth variant at 108 dpi, and all 15 final Cello pages match the compact baseline. All final pages were rendered and visually viewed; the targeted turns were also viewed as individual larger pages against original source pages. This is a layout review, not a fresh note-by-note certification of every inherited crop.

Root independently viewed contact sheets covering the revised sections, full First Violin page 14, Second Violin page 14 and Viola page 13 against source page 32. That review confirmed the intended lower-part whole-bar rest symbols and found no new collisions. Existing neighboring notation remains visible.

## Why these six breaks

Source page/system labels below are physical PDF page numbers and top-to-bottom systems, not invented bar counts.

| Part | Break before | Source-supported purpose |
| --- | --- | --- |
| First Violin | p29 s1 | Begin the printed fourth-movement heading on a fresh page; this remains the compact draft's movement-page alignment. |
| First Violin | p31 s1 | Begin the new rapid variation after the preceding closing repeat. All four p31 systems and all four p32 systems now share output page 14. |
| First Violin | p33 s1 | Keep p32's first/second endings together before the next section/key transition. |
| First Violin | p34 s3 | Begin the printed Doppio Movimento/time-change section after the preceding repeated section. |
| Second Violin | p32 s1 | Begin output page 14 with genuine printed whole-bar rests before its entrance. |
| Viola | p32 s1 | The corresponding printed rest opportunity begins output page 14. |

First Violin page 13 contains p29 s1 through p30 s4; page 14 contains p31 s1 through p32 s4; page 15 contains p33 s1 through p34 s2; page 16 begins p34 s3. The former page-13/14 turn inside rapid continuous notes is therefore removed. Repeat/section boundaries are structural opportunities, **not guaranteed silence or permission to insert a pause**. Later continuous-playing turns still exist, including in the last pages.

Second Violin and Viola output page 13 ends at p31 s4. Their next page begins with the visible rests on source p32. No rest duration or bar count was inferred or inserted. At enlarged resolution, the fermata at the end of source p31 is printed only above First Violin. Earlier provisional wording suggesting a fermata in the lower parts was corrected; their repeat signs alone do not establish a pause. Cello's p31 opening rest is short, not a whole-bar or multibar rest, and its p32 opening has immediate playing. The proposed extra Cello page was withdrawn. Cello remains 15 pages and its turns are not claimed improved.

## Iteration and cost

| Variant | First / Second / Viola / Cello | Total | Disposition |
| --- | --- | ---: | --- |
| Compact current draft | 17 / 16 / 16 / 15 | 64 | Preserved default, difficult First Violin fast turn. |
| Movement and repeat starts | 20 / 18 / 17 / 17 | 72 | Too many additional pages for this goal. |
| Targeted movement starts | 18 / 18 / 17 / 16 | 69 | Still more turns than necessary. |
| One nearby break per part | 18 / 17 / 17 / 16 | 68 | Rejected: First Violin next turn split p32's first/second ending group. |
| Reviewed upper parts, extra Cello break | 18 / 17 / 17 / 16 | 68 | Upper parts retained; Cello rationale withdrawn after source enlargement. |
| Final alternative | 18 / 17 / 17 / 15 | 67 | Complete bounded alternative; Cello unchanged. |

All variant configurations, manifests and saved project metadata are preserved in `evidence.zip`; scratch PDFs remain under `.build/page-turn-review-2026-10-03/`. Page-fill checks alone did not choose the final variant: source inspection rejected the superficially smaller break set and the unsupported Cello rest rationale.

## Small-score check

The current Ave Verum set has eight one-page parts, each eight strips. There is no page turn to improve. Original source page 1, Soprano and First Violin output were viewed; the eight output page counts were verified. This is not a fresh full-eight-part musical audit.

Notte e giorno has three Voice and four Piano pages. All four source pages, all three Voice pages and the first two Piano pages were viewed. Source p1 s4 ends with a real fermata/rest before the next phrase at p1 s5 (printed 20); the current Voice first turn falls later within the next phrase. A break before p1 s5 is a possible manual alternative, but **was not exported or validated**, and no changed Notte set is delivered. Other rests inside whole strips cannot become precise page-turn points through `pageBreakBefore` alone. The existing musical cue labels belong to that prior reviewed project.

## App strategy and limits

The Inspector already offers **Start on New Page**, persisted through `BandModel.pageBreakBefore` and the undoable document update. The layout engine minimizes page count and balances spacing; it has no knowledge of rests or repeat structure. A useful immediate UI is a previous/next-page comparison for a selected break with its page-count cost. This needs no new acceptance gate.

A future automatic option should distinguish soft preferred turns, keep-together passages and explicit hard breaks. It must use source-bound musical evidence, keep a bounded extra-page budget, and preserve manual choices. A repeat barline alone is not proof of silence; source-page boundaries are not musical page-turn instructions. This study uses existing whole-strip breaks only. Finding a useful rest inside a strip would additionally require a verified musical boundary and safe strip division, including retained directions and lyrics.

Inherited extraction limits remain: seven previously identified whole-neighbor cases, other neighboring fragments, conservative ending guards and incomplete whole-score musical validation. This layout experiment does not repair or reclassify those cases. Read the preceding `brahms-continuation-output` and native-ending reports for their independent source evidence.

## Reproduction and provenance

`evidence.zip` includes the exact frozen Core, native inventory/profile, original exporter adaptation, native reexport harness, build commands, all variant configurations and metadata, native logs and a per-entry SHA-256 manifest. It excludes binaries, duplicate PDFs and embedded duplicate source PDFs. The source remains both in the delivery project and the repository sample corpus. The first native export attempt failed in the restricted renderer environment (`failedRectification(1)`); an unchanged harness with native macOS graphics access succeeded. This was an environment failure, not silently repaired source geometry.

`plan.json` in the delivery is the original native extraction plan **before editorial pagination**. The saved project's six `pageBreakBefore` flags and `layout-page-breaks.json` describe the layout choices; `manifest.json` records the final PDF placements. `delivery-hashes.json` binds every delivered file, and `report-hashes.json` binds this report and evidence.
