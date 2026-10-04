# System selection and assignment recall — 2026-10-04

The focused native harness compiles the actual Core and Features sources and exercises the production selection and assignment-recall helpers.

Run `bash tools/test_system_selection.sh` from the repository root. The recorded run passed **96 checks**. See `test.log`, `results.json` and `source-hashes.json`; all compiled source inputs were unchanged during that run.

Coverage includes five zoom scales, upward/downward and additive drags, numbered-gutter and page-edge geometry, and matching assignments whose staff IDs restart on each page. Reviewed roster and first-bar/count values are checked after JSON persistence. Navigation checks cover exact saved targets, automatically advanced empty slots, empty placeholders created by assigning a later system first, the first available saved assignment, page isolation, invalidated assignments and empty reviews.

The sparse-assignment checks use `ScoreSystemAssignment.assign`, which creates the actual empty placeholder records. They ensure those placeholders do not prevent reopening the first or preceding assigned system.

These are geometry and saved-data recall checks, not live mouse gesture or window-navigation automation. They use synthetic staff geometry and make no claim of recognition accuracy or musical completeness. The separate bar-counter review covers source-score counting.
