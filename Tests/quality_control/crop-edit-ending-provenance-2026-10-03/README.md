# Actual crop editing and local-ending provenance

**The UI API bug is reproduced, and the isolated document-only fix passes the independent checks.** The old `ScoreDetectionReview.setCropEdges` materializes an empty copied-marking list without `automaticLocalEndingPairIDs`. That loses the distinction between an automatically suppressed duplicate and a user's explicit removal. Cropping through the local ending then leaves the global copy absent.

The baseline document was frozen before production was changed. Its SHA is `97d184b780ce3a2bf75fa1e571cb0408283d425e0c1de55fb791640084938132`. Both compiled snapshots contain the same 23 production Core files except `DocumentModel/PartsmithDocument.swift`. The candidate document SHA is `0365fdccc9e87654d1a98591ad95a33e228973dbffe876cd582405e39e0efcb8`; no unpromoted heading matcher/planner code is included. `frozen-inputs.json` and `document-only.patch` bind this exact comparison.

The test uses an unchanged copy of the existing self-contained local-ending source fixture from `tools/test_local_ending_counterparts.swift`. Printed local/global bracket coordinates, staff geometry, counterpart provenance and source ownership are not modified. Recognition is supplied by that fixture; this is a review-state/API test, not a new OCR or PDF-rendering test.

## Direct API result

The harness invokes the actual public `setCropEdges` and `resetCropEdges` methods. It does not manually construct an override to stand in for those actions.

The frozen baseline records **20 passing checks and nine failure/blocker records**. On the first real crop edit, the copied ending count remains zero and the automatic pair identity is absent. A second clip, a clip after reset, a no-op first edge edit, and reset as the first action reproduce the same lost provenance. The end-to-end restored-copy-removal sequence cannot start on the baseline because its prerequisite copy never returns; that blocker is recorded rather than silently skipped.

The isolated candidate passes **all 30 direct checks**. The check counts differ because the baseline's one removal-prerequisite blocker becomes two exercised removal/persistence checks:

- Clipping the local bracket restores exactly one global ending copy. Reversing the crop suppresses it again. Reset and subsequent clipping retain this behavior.
- An initial no-op crop or initial reset retains automatic pair provenance.
- Intentional Remove Copy stays removed through later reversal, reset and clipping. An ordinary explicit removal and initial explicit empty/nonempty lists remain authoritative.
- Existing override reasons and system/movement labels remain exact. Unrelated heading/navigation copies and metadata remain intact; a later music-to-cue ownership change still invalidates automatic ending evidence.
- Invalid crop requests, unavailable reset targets and attempts to crop/reset a generated rest throw without partially mutating the review.
- Existing generated rests, omission reasons, six-bar count and starting bar 144 remain exact through crop/reset. A separately labeled model-level test materializes an already reviewed omission plan without an existing override: the old constructor throws `incompletePage`, while the helper correctly keeps the silent omission as a generated rest. This does not claim automatic instrument recognition supplies omitted rests.

Both binaries also pass **all 62 unchanged local-ending controls**, including category-specific linked cleanup and recognition cancellation. That confirms why the existing suite missed this bug: its earlier crop test called the helper directly. Public crop editing is synchronous and has no cancellation callback; rejected-action atomicity is tested directly, while the existing recognition cancellation controls remain unchanged.

## Minimal change and durable regression

The fix routes crop materialization through `ScoreSystemAssignment.pageOverride`, passing the existing override when present. The default crop-review reason is assigned only when no override existed. Existing review validation, proposal replanning and atomic commit behavior remain unchanged.

After the baseline-failure/candidate-pass evidence was captured, eight compact public-API regressions were added to `tools/test_local_ending_counterparts.swift`, as authorized by the root. They cover clip/provenance, reversal, reset/reclip, deliberate removal, initial no-op and initial reset. A conditional `LOCAL_ENDING_STANDALONE` entry point lets the root-owned standalone runner execute the suite without interfering with its existing embedded application test runner. The frozen 62-control fixture in this report remains unchanged. The root-built standalone binary was also executed independently and passes all 70 controls with the new eight regressions. Its hash, runner/source hashes and exact output are recorded in `comparison.json`.

Production document promotion, full document-suite results and application build identity are owned by the root. This report establishes readiness only for the exact document-only correction and its crop-edit provenance behavior; it does not approve the separate heading-recipient matcher or terminal-body experiments.
