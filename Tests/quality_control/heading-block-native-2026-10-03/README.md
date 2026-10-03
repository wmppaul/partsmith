# Native heading-block evidence — 2026-10-03

The bounded heading repair preserves all **6,324 music crops across 16 configured inputs and 449 pages**, changes exactly **four Schumann copied-heading rows**, and retains every original heading envelope. A separate fresh full Auto run on the 56-page Schumann score reproduces the same result. The reviewed complete output contains five parts, 825 bands and 74 pages.

This record packages completed runs only. No OCR, detection, production changes or app packaging was performed while assembling it.

## Two distinct native checks

**Broad heading replay.** Baseline and final frozen Core versions re-rendered the original PDFs and ran native heading recognition across all 449 pages, using identical retained staff inventories, original instrument profiles, saved rectifications and existing non-heading direction metadata. This is fresh heading recognition with frozen staff geometry, not 449 pages of fresh staff detection or automatic instrument-name initialization. The configured inputs include a two-page Beethoven excerpt and a five-page Mozart flute part; it is not a collection of 16 newly extracted complete full scores.

All 16 comparisons completed with no render/recognition errors. The raw OCR observations are identical between versions. Sixty-three accepted heading fragments become 62 blocks through the one intended Schumann p26 merge. No original heading envelope is lost; no main crop, assignment, band identity/order or other band data changes. Only four source-copy rows change: Schumann p26s1 Violin II, Viola, Violoncello and Piano. The original instrument-order/staff-count profiles are supplied inputs; these results do not validate automatic instrument identification. Empty-staff pages are listed per case and filtered from planning by this replay harness.

`comparison.json` is the parent's complete comparison, and `corpus-summary.json` lists every input, page/band count, original source/profile hash, empty-page indices and final result. All 16 initialized plans can apply. `config.json` and each variant's execution configuration bind the exact retained inventory inputs.

**Fresh app Auto.** The actual `PartsmithDocument.detectScore(profile:copySharedDirections:true)` worker separately ran fresh staff detection and all shared-direction phases on the original 56-page Schumann score. The profile remains initialized. It automatically skipped the blank first page and produced 825 bands/35 source copies, with no direction issues, a usable plan, main-thread completion, unchanged project during detection, and cleared progress. Its full band plan equals the final heading replay's result. `fresh-auto-summary.json` and `fresh-auto-comparison.json` retain the outcomes. The worker configuration includes other available cases, but this archived execution/log contains Schumann only; it is not evidence of fresh full Auto on the other 15 corpus inputs.

The immutable Core sources for baseline, intermediate v1 and final are inside `evidence.zip`, alongside all raw observations, inventories, plans, summaries, source/config hashes, execution logs, run harnesses and build scripts. The exact retained input inventories and profiles are also included. Original PDFs and compiled binaries are intentionally excluded; their hashes are recorded. `data-manifest.json` lists every archive member and its original repository path, byte count and SHA-256.

## Full output and independent review

The delivered set is [Schumann quintet — heading blocks](../../../output/pdf/auto-qc-2026-09-21/schumann-quintet-06822-heading-blocks/): all five PDFs and the source-embedded editable Partsmith project. All nine delivered payload hashes match the reviewed scratch export. Older output sets are preserved.

The [full export/source review](../schumann-heading-block-output/README.md) confirms all 825 music crops and 15 ending copies are unchanged, 70 of 74 page rasters are pixel-identical, and the four affected output pages retain complete SCHERZO, Molto vivace and the original dotted-quarter metronome marking. Thirty-one placements move within the same pages; no page break changes or new clipping/overlap are observed. Both reviewers directly inspected all four copied rows and changed pages. The [independent review](../heading-block-independent/README.md) separately passes 75 controls, the complete native corpus comparison, and actual-worker override replay.

The strict source guard extending to y60 still fails for the four copies, whose lower edge is about y59.57. Independent examination of the original embedded scan identifies the extra mark as one isolated scan pixel below Molto, separate from text/metronome punctuation. Complete required text and musical-mark guards pass. The conservative failure remains recorded; no source guard was moved to obtain a pass.

## Preserved failures and limits

- The first corpus attempt failed before recognition because the retained `{pages, plan}` wrapper lacked the expected `source` field. [The original error](input-format-error.log) and `original-config.json` remain. Thirteen wrappers were normalized by retaining their `pages` exactly and adding bound source/hash/rectification fields. `normalization-verification.json` rechecks that equality and the original/normalized hashes. This is an input-format repair, not a detection improvement.
- The first overlapping-block implementation failed repeated grouping: a union rectangle could bridge a third disjoint fragment. The [independent v1 evidence](../heading-block-independent/v1-idempotence-results.json) and [original-fragment repair account](../heading-initial-override-repair/README.md) preserve the failures. Final source stores original fragment geometry and passes repeated-call/serialization controls; the historical v1 Core and native output remain separately archived.
- All profiles are initialized. Variable/omitted instruments, missing-part rests, instrument-name initialization and rest compression are outside this evidence. Retained crop identity does not establish that every pre-existing crop contains every intended note.
- Schumann Piano p19 Agitato duplication, local Molto wording repeated under the complete shared block, dense neighboring staff/notation, and known ending misses remain documented in the output review. Broader recognition recall is not established. The Brahms neighbor-crop limitations are unchanged.
- Headings separated by a real vertical gap still encounter the existing single-copy-row limitation. This fix groups overlapping accepted source rectangles; it does not broaden vocabulary or prove that all global directions were found.

## Regression and release records

`planner-final.log` records 83 passing planner checks and `shared-direction-app-final.log` records 113 passing app-direction checks. Their exact test sources/scripts are included in the archive. Additional 57 override controls, four category controls and their historical failures are preserved in the [override repair report](../heading-initial-override-repair/README.md), with the independent 75 controls in its separate report.

`release-build.log` records the successful universal release build. `release-source-hashes.json` binds the compiled source set, and `archive-validation.json` records x86_64/arm64, archive SHA-256 and executable SHA-256. Assembly independently rechecked the saved app archive's CRC and embedded executable identity. The app binary/archive itself is not duplicated here; deployment/package promotion is owned by the parent task.

The fresh Schumann worker took 218.23 seconds wall / 212.86 seconds awake, with maximum main-thread heartbeat intervals of 1.430 seconds wall / 0.154 seconds awake. These are measurements under concurrent checks, not responsiveness guarantees.

## Audit and reproduction

`archive-verification.json` records a complete CRC, byte-count and SHA-256 reread of every ZIP member. `package-manifest.json` additionally binds the readable record and ZIP. `assemble.py` documents the completed-data assembly and validation; it refuses to overwrite an existing archive.

Archive paths preserve original repository-relative locations. Extract into a separate scratch checkout to inspect them. The harness/configurations retain their recorded workspace paths; rebase those paths and supply the exact original score PDFs before reproducing recognition on another machine. A macOS Swift/Vision toolchain is required. The existing comparison can be rerun against the archived completed JSON without running OCR. Do not overwrite the frozen baseline/final directories when running a new experiment.
