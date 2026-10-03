# Combined preservation candidate: independent raw-corpus review

The exact combined candidate completed all **36 scores / 1,477 pages**. All 23 pages with meaningful component changes were reviewed against original source, including the 18 pages whose variable-layout profiles produce no assigned bands. No newly omitted target notation was observed in the inspected changed regions. This is a bounded comparison, not a claim that the corpus is ready for performance or that the Auto workflow has solved instrument assignment.

There is a material preservation tradeoff: **18 of the 20 expanded neutral diagnostic crops newly contain a whole neighboring staff core**. The other two expand only slightly. All 20 contain their complete previous crop. These are deliberately unnamed, one-part-per-observed-staff diagnostics on unresolved pages, not completed instrument parts. Keeping possible target notation can therefore produce substantially dirtier crops on these pages. The resolved-band neighbor count below does not include that tradeoff.

## Exact inputs and candidate

`baseline-binding.json` independently binds the production82 raw corpus at `.build/residual9-boundary-2026-10-03/candidate-v2/corpus`. All 36 original PDF hashes, profile hashes, actual PDF page counts, terminal output hashes and the original native binary hash verify. The roster equals every PDF under `sample_scores` and `Tests/extraction/sources` at the time of the run.

All 23 baseline snapshot Core files match their saved manifest. The six source files compiled into the old inventory harness separately match git commit `82b606e`; its analyzer is `e6541355b65590e66b9f893a12a12f1d66e73f82ebc328436dbb3d52bcd0a353`. The other snapshot files are bound without claiming they were compiled into that six-file harness.

The reviewed candidate outputs are `.build/combined-corpus-2026-10-03/candidate`, bound through the root-owned inputs, terminal statuses and build manifest. The frozen candidate is:

- Analyzer: `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`.
- Planner: `0cfd6f6fdb1b926a16c4984f63a6d0a4fdf0261878875508916c646a739784b2`.
- Native binary: `809088ac1fbb2817cbd797bf2ea8f7cf11d86a85e3d17eff4e4efc16c24b1bf4`.

The historical baseline remains `82b606e` even after production advances; promotion does not change the frozen comparison inputs. These runs use raw original PDFs. The nine saved Brahms rectifications used in the separate actual-document review are not applied here. This reviewer started no duplicate native workers and made no production edits.

## Comparison result

| Measure | Baseline | Candidate |
| --- | ---: | ---: |
| Scores / pages | 36 / 1,477 | 36 / 1,477 |
| Assigned bands | 6,936 | 6,936 |
| Pages with assignments | 490 | 490 |
| Pages with unresolved reasons | 987 | 987 |
| Detected staves | 23,801 | 23,801 |
| Unassigned observed staves | 15,712 | 15,712 |
| Whole-neighbor occurrences in assigned bands | 91 | 87 |

Only four assigned crop rows change: Violin/Viola on Mozart K478 IMSLP86903 physical page 25 and Violin I/II on Brahms Op67 IMSLP93521 physical page 35. All four lose their previous whole neighboring staff core and have corresponding warning changes. No band identity, part assignment, detected staff geometry, unresolved reason, other page field or other plan metadata changes. The remaining 6,932 assigned rows are identical.

Component comparison uses multisets, preserving duplicate counts and all fields, including the new `isOwnershipAlternative` flag. It ignores only the order of whole component records. There are 23 semantic-change pages and 340 additional order-only pages. Eighteen pages add 21 flagged alternatives; five pages contain ordinary component-separation changes. The 18 unresolved semantic pages comprise 15 alternative-only pages and three ordinary separation pages.

Nineteen variable-layout profiles yield zero bands across 976 pages; another 11 pages in fixed-layout scores remain unresolved. All 987 pages and 15,712 unassigned observed staves remain in the comparison scope. A zero-band result cannot be counted as a successful extraction.

`compare.py` verifies the exact source/profile roster, terminal output hashes, binary/Core binding, page counts, staff references, band identities, geometry, warnings and coverage. Its baseline-versus-itself self-check is retained separately under `comparator-selfcheck/`; it is not candidate quality evidence. The generated comparison and queue retain their generation-time pending-review fields; `review-completion.json` records their final review state.

## Source and output review

`source-review/` contains untouched full original pages and full-width contexts around every changed region. The contexts are inspection aids, not crop oracles. `source-coordinate-check.json` independently verifies original PDF page size against native source-coordinate dimensions on all 23 pages.

The root independently reviewed all five resolved pages and all four changed actual crops. Its immutable evidence is linked and hash-bound under [resolved-source-review](resolved-source-review/README.md). The three component-only Schumann pages retain identical crop bounds and warnings; their added evidence lies inside Piano grand-staff parts. Mozart page 25 retains the inspected notes, beams, slurs, accidentals and dynamics, but the original scan itself has notation cut at its right page edge.

Brahms page 35 retains the inspected target ink, with an explicit exception to the old conservative rectangle: the Violin I crop ends at **66.3824 pt**, below the previous guard's required **68 pt**. That original guard remains failed and unchanged. Independent source inspection of the excluded strip finds structural strokes and neighboring Violin II beam tips, not Violin I notes. This source-based clearance is separate from strict rectangle containment; the report does not silently shrink the guard.

`unresolved-source-findings.json` records original-source context review on all 18 unresolved semantic pages. Full original pages were also inspected for all three ordinary-separation cases before considering the proposed neutral crop edges. Their explicit source obligations were frozen in `unresolved-source-obligations.json`.

`neutral-staff-plans.swift` plans both saved analyses with one diagnostic part per observed staff, without inferring names, musical systems or missing rests. It does not rerun native analysis. All 26 changed neutral crops have rendered before/after images and exact bounds in `neutral-review-index.json`:

- **Six tighter crops**, independently reviewed here in `tightened-neutral-review.json`: Schumann IMSLP51506 page 37 retains its high ledger dyads, accidentals, complete upper slurs including the detached final right-edge slur, dolce and clefs. Beethoven IMSLP52624 page 63 retains high dyads, upper slur, ff, final sharps and stems. Page 86 retains both low-staff musical lines, their long slurs, high half notes, beams, p/cresc/f and rests. No new target omission was observed. Neighbor fragments still remain.
- **Twenty expanded crops**, separately reviewed by the preservation agent in `expanded-neutral-review.json`: every crop contains its complete previous source rectangle. Eighteen now contain a whole neighbor staff core; two Brahms IMSLP317803 rows expand by about 1.19 and 2.37 pt. This increase in contamination is explicit and is not included in the assigned-band 91→87 count. Preservation is established from the unchanged original PDF and rectangle containment, not PNG equality: 14 independently rasterized image overlaps differ, so pixel-identical rendered overlaps are not claimed.

The source-first assessment supports the candidate as a bounded preservation change with these limitations disclosed. It does not establish complete musical ownership on unresolved pages, eliminate neighboring notation, supply missing rests, or certify every unchanged source crop. Synthetic controls, actual-document exports and final application build identity are separate evidence owned by the root.
