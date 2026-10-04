# Higher-resolution corrected-page analysis: held

The standalone setting is **not promoted**. It reduces the net complete-neighbor count from seven to six, but introduces two new whole-staff overlaps and clips the initial V of the printed `Vivace` on page 2.

The parent measurement freshly analyzed only the nine saved corrected pages (2, 7, 17, 19, 23, 28, 34, 38, 39) at a directly rendered maximum 1800×2600 raster, with unchanged production detector/planner. The other thirty analyses were retained exactly. This is not a fresh 39-page run, full output review or corpus pass. Production remains unchanged.

## Independent checks

Before reading the candidate, this reviewer bound 56 existing source checks in `requirements-before-candidate.json`; no guard was changed. Both baseline and candidate pass 53/56, with zero new failures. The existing failures are the p35 Violin I broad rectangle and the p22 Cello lower rectangle plus its nested landmark, all on unchanged pages. Check families overlap; 56 is not a count of distinct notes.

All 604 band identities, part/staff assignments and coverage remain exact; every observed staff is assigned once, there are no new unresolved pages, and all thirty retained analyses are byte-equivalent as decoded data. Source hash, normalized correction geometry and physical page dimensions match. Staff counts remain 12 on p2 and 16 on each other freshly analyzed page. Individual detected line positions move by up to 1.536pt, so exact candidate line geometry is not claimed unchanged.

All 140 fresh-page bands change crop geometry; 105 contract at one or both edges. This reviewer inspected the full-width source context of all **28 contractions exceeding 2pt**, plus enlarged close cases. No target-note or local-mark omission was seen in 27 of those contexts. The remaining case loses actual heading ink. The 77 smaller contractions and expanding-only changes were not fully source-certified; the setting was held after the bounded findings.

## Actual heading clipping

`p2-s1-violin1` moves its top from 125.2pt to **131.788335pt**. The direct source raster's first dark `Vivace` pixels begin at 131.385091pt, above the new edge. In the initial V, 28 dark pixel cells lie wholly above the cut and another 28 dark pixel centers occupy the partly intersected next row. Do not describe all 56 cells as wholly removed. The separately published corrected-source PDF also confirms the clipping: its word begins at 131.25pt.

`vivace-loss.json` records the exact regions and measurement. The three `p2-*` images show the full source context and enlarged word. The candidate band has no source-marking copies. A separate complete heading copy might preserve the word elsewhere in a merged output, but no such output was evaluated here.

The nearby p7 system 4 Violin II hairpins were explicitly enlarged and remain fully inside the new edge (`p7-hairpins-detail.png`). This close source check is distinct from the heading failure.

## Two new whole-neighbor crops

Both p28 system 2 violin crops newly retain the other complete staff, visibly confirmed in the included source panels:

| Band | Before top…bottom, pt | Candidate top…bottom, pt | Newly retained staff |
|---|---:|---:|---|
| Violin I | 151.548765…206.733420 | 164.530274…236.330891 | Violin II, native ID 5 |
| Violin II | 201.932380…241.522107 | 168.087929…241.311608 | Violin I, native ID 4 |

Conversely, the p38 system 1 Viola/Cello crops remove complete foreign cores while preserving all frozen target envelopes and inspected tenutos, dynamics, low slurs and high Viola notes/arcs. The net seven-to-six count therefore conceals real regressions elsewhere.

## Coordinates and evidence

Every independent overlay uses its page's actual physical width and height. Page 2 is **427×614pt**, not 615pt high; its candidate image is 1800×2589px. Raw-only guards were not transferred to corrected pages. The independent panels use blue for old edges and green for candidate edges; the copied parent p28 Violin II panel uses red/blue instead.

`review.json` contains all 28 per-band findings; `comparison.json` contains staff identity, geometry and all 56 guard checks. `edge-contexts.zip` retains every inspected contraction context, including the detailed word/hairpin images. `source-bindings.json` binds the parent's frozen protocol, candidate, nine source images and prior source guards. Parent replay artifacts are referenced rather than duplicated here. No additional detector run, PDF export, production edit or guard modification was performed for this report.
