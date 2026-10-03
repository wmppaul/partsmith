# Paired ending Auto regression coverage

The permanent test is `tools/test_shared_ending_app.swift`, run by `bash tools/test_shared_ending_app.sh`. It builds the current production Core and creates its small source PDFs and staff fixtures in memory. It does not read the earlier scratch integration directory, sample scores, or frozen corpus in the default mode. Recognition services are injected for deterministic failure, pairing and cancellation tests; the document's actual background staff-analysis worker and source rendering still run.

The default suite contains **54 coordinator/planner/review assertions plus 27 worker/lifecycle assertions**. The earlier scratch total of 65 included 11 full-corpus assertions; those now live behind `--corpus`. No assertions or guard tolerances were weakened during the split.

The default controls cover:

- Separate optional ending metadata, literal OCR evidence and Codable compatibility.
- Complete selected-page collection before atomic pairing, cross-page pair identity, sparse pages, unresolved pages, failed rendering/OCR, affirmative white blanks, unknown staffless-page barriers, and detection independent of navigation references.
- Cancellation during recognition and after pairing, plus actual worker cancel/replacement during the ending phase. Source/correction changes cannot publish stale results.
- Preservation of headings, navigation, destination symbols and reference provenance.
- Rejection of the whole pair when either member's source page is missing.
- Rejection of a stale ending when an initial valid override places its anchor in a different system; an optional warning does not block ordinary crop acceptance.
- Original-owner crop retention, source-pixel copies for recipients, explicit removal across reset/replan/serialization/apply/undo/redo, authoritative manual markings, crop-only edits, invalidation from either source page, and preservation of an unrelated pair sharing the partner page.

Run `bash tools/test_shared_ending_app.sh --corpus` for **65 assertions plus the same 27 lifecycle assertions**. This adds a replay of all 68 recorded Brahms/Mozart pages without new Vision calls. Every input is checked against `corpus-inputs.json` before replay. The optional mode deliberately requires the generated inventories and local original PDFs listed there; a missing or changed input fails instead of silently skipping or updating a baseline.

Corpus requirements retain all 604 approved Brahms bands and 42 source copies exactly, including staff identities, ordering and crop geometry. Mozart retains 405 bands and 10 copies. All five paired endings are represented in their original source geometry. Successful replay writes expected plans under `.build/shared-ending-app-tests/expected-plans/`. It does not alter delivery PDFs, source images, correction settings, or the six frozen Brahms ending-envelope containment failures.

`verification.json` binds the actual promoted test source, current Core snapshot, logs and inspected UI/model/review files for this run. `ui-review.md` records the independent code review. These checks do not replace a fresh native 68-page workflow run or a visible packaged-app test of labels, highlighting, removal, cancellation and acceptance; root owns those separate checks.
