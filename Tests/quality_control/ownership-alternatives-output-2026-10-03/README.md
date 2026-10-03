# Complete Brahms native Auto output with typed ownership alternatives

**Complete scratch output: four parts, 67 pages, 604 music strips and 42 copied directions.** The fresh document-worker run and native export pass structural/persistence checks. All six changed output pages and all four changed source rows were visually reviewed; no new target-notation clipping or layout collision was found at that scope. The new set remains a draft in scratch pending root's broader corpus and independent review. It has not replaced or been published over any existing delivery.

The complete set and embedded-source editable project are in `.build/ownership-alternatives-output-2026-10-03/parts/`. Counts are First Violin 18, Second Violin 17, Viola 17 and Cello 15, each 151 strips. The comparison is the existing `output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-page-turns/` set, with its same six source-reviewed page-break choices and unchanged layout settings.

## Fresh app workflow

The harness invokes `PartsmithDocument.detectScore` on the entire original 39-page source with the saved instrument profile and exact nine rectifications. It does fresh staff detection and every normal shared-direction phase, including native ending recognition and recipient-local counterpart checks. It does not replay frozen components or inject saved direction boxes.

The worker completed in 69.420 seconds under concurrent checks, with 604 bands, 42 source copies, zero direction issues, applicable plan, cover page 0 automatically skipped, main-thread progress/completion and unchanged document state. Maximum observed main-thread heartbeat interval was 0.0574 seconds. These are measured values for this run, not performance guarantees. Raw progress, phase logs and all summary fields are retained.

The worker comparison confirms exact source and rectifications, staff observations, heading/navigation/ending recognition metadata and every source-copy field against the prior actual-worker inventory. Only the four expected main crop rectangles and their corresponding ambiguity warnings differ. All 604 assignments, kinds, labels, order and source identities remain unchanged.

The native exporter applies the review through `addScoreParts`, applies the six existing explicit breaks, saves the original source in the project, verifies byte-exact JSON codec roundtrip and embedded source equality, reopens the package, and then exports all four PDFs from that reopened document. Profile, rectifications and all 604 stored bands survive reopening. No output is fabricated by a separate layout engine.

## Source and output findings

Original source SHA-256: `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. Original physical source pages35 and38, including enlarged first systems, were rendered and viewed before inspecting the changed PDF rows.

| Source row | Before vertical crop, pt | After, pt | Source/output judgment |
| --- | --- | --- | --- |
| p35 s1 First Violin |22.8774–107.3315|22.8774–66.3824|Whole Second Violin staff removed. Intended clef including its lower dot/tail, ledger notes, accents, articulation, slurs and beams remain; small neighboring beam tips remain. |
| p35 s1 Second Violin |30.9252–113.7224|57.1989–113.9591|Whole First Violin staff removed. Intended high beams, low ledger notes, accidentals and all three large slurs remain. Upper/lower neighboring fragments are still visible. |
| p38 s1 Viola |87.9694–134.3570|87.9694–159.5488|Conservative new ownership alternative retains the complete adjacent Cello staff. Existing Viola notation remains; this is an acknowledged crop-cleanliness regression. |
| p38 s1 Cello |119.9590–165.1469|91.5683–165.1469|The same ambiguity retains the complete adjacent Viola staff. Existing Cello notation remains; this is an acknowledged crop-cleanliness regression. |

The four row images are crops of actual exported PDF placements, with a small output-context margin; they are not independently rebuilt source strips. All 42 copied directions retain their exact source rectangles and above/below roles. The copied endings and headings appearing on changed pages were viewed in their final row context and remain unclipped.

**The original conservative guard failure is retained:** the p35 First Violin source envelope ends at68pt, while the candidate crop ends at66.3824pt, so only9/10 frozen rectangular guards pass. Source review of this lower interval found extra lower space/neighboring beam tips rather than a lost First Violin symbol. The guard was not shortened, moved, waived or converted into a geometric pass. This visual classification is distinct from the strict failed containment result. Other inherited ending-envelope limitations are unchanged because no direction-source box changed.

## Pagination and readability

All 67 pages were rendered. At 108 dpi, **61 pages are pixel-identical** to the previously reviewed 67-page set. The only changed pages are First Violin 16, Second Violin 15–17, Viola 17 and Cello 15. Every changed page was viewed both in the contact sheet and individually at the full saved page-render size. The61 unchanged pages inherit the prior review by exact raster equality rather than a claim of newly re-audited source notes.

Page counts and the six saved hard breaks remain unchanged. First Violin's reviewed p31 rapid passage and p32 ending group remain together. The Second Violin and Viola p32 rest-entry turns remain in place. Two later Second Violin strips move as a result of the smaller p35 crop: source p35 s4 moves from output 16 to 15, and p37 s4 from17 to 16. Source p35 s4 is still rapid continuous music. These later turns remain performance limitations; moving a complete strip did not create a rest or a guaranteed turning opportunity. No additional editorial breaks or rests were added.

Root independently viewed all six changed full pages, the contact sheet, original p38/system 1 and both exported p38 rows; the two p35 rows/source were independently viewed during root's raw-corpus review. That second review also found no new crop/layout collision and confirmed the target clefs, dots, slurs and beams in the changed rows. Root's fresh document test against the exact 23-file Core passed 139 assertions; its log is archived separately from this output review's own checks.

Source ordering, staff-line geometry, scale settings and all unchanged-strip destination dimensions remain exact. All 604 music placements and 42 direction placements fit inside their pages without inter-row collision. No staff overlaps a title or footer. The larger p38 Viola/Cello context fits without adding a page. Seven whole-neighbor cases remain overall: two p35 cases improve while two p38 cases widen. Smaller neighboring fragments and previous musical-recognition limits remain; this is not a clean-isolation or whole-score performance certification.

## Bindings and evidence

The private23-file Core snapshot was copied and verified before compile, worker start and review. Native analyzer SHA-256 is `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`; planner is `0cfd6f6fdb1b926a16c4984f63a6d0a4fdf0261878875508916c646a739784b2`. The separately frozen independent model review is `../additive-ownership-code-review-2026-10-03/OUTWARD-ONLY-REVIEW.md`.

`worker-comparison.json` binds the fresh native run; `output-comparison.json` binds every source crop, copied direction, page mapping, changed-page list and frozen guard result. `evidence.zip` contains the exact Core/harness/config/build sources, fresh worker inventory/plan/summary/logs and final export metadata, excluding binaries and duplicate PDFs. `report-hashes.json` binds the report and images, while `scratch-output-hashes.json` binds every complete scratch delivery file. The project/source and four complete PDFs remain in scratch until root authorizes a new delivery folder.

| PDF | Pages | SHA-256 |
| --- | ---: | --- |
| Violin I.pdf |18|`ec911d959f338f813c42cb6a59abc32dda9ef5b8077156b3c6cd5f2c7aa66fdb`|
| Violin II.pdf |17|`7c99d647b35e3bfb51d9b2e177363e03dd608b0501eae725814baec75e6ca67c`|
| Viola.pdf |17|`17f7dfa6f030fcaf2ff7f0c7499eba6a03e109d244ac90ddb6497b9cffcc65a0`|
| Violoncello.pdf |15|`daf629cc007c25038d8942d6e6134cfe0bd45ba37a8ecae5290dfcb0f18b84f7`|
