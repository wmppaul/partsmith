# Manual instrument names: existing regressions

Both existing regression suites passed against the manual-name implementation:

- `tools/test_instrument_names.sh`: **205 checks** covering real printed and scanned labels, ordinals, raw/rectified coordinates, boxes, occurrence identity, uniquing, cancellation, source changes, and Undo.
- `tools/test_instrument_pick_flow.sh`: **47 checks** covering native accessibility actions, real Brahms recognition, immediate Done, selected input pages, covered Auto setup updates, document-owned window return, and closure cleanup.

No existing test scripts or expectations changed. Source hashes matched before and after each execution. Tests ran in separate native macOS processes with graphics access; they did not launch the Partsmith app or open any user document. The flow fixture uses offscreen test windows and immutable score fixtures.

## Final selective rerun

Read-only UI review found that the Auto action could cancel a pending typed name. The root agent guarded both the button and `runAuto()` while a draft or OCR is pending, and added an explanatory footer. Only `ScoreExtractionView.swift` changed. The native picker-flow **47 checks passed again against the final source**, and its final logs and screenshots are here. The 205 recognition checks compile Core sources and their test only; every one of those inputs is unchanged, so that suite was not repeated.

`source-hashes-before.json` and `source-hashes-before-auto-guard.json` record the initial run. `picker-rerun-source-hashes-before.json` and `source-hashes.json` match the final source. The first picker log is retained as `instrument-pick-flow-before-auto-guard.log`.

The attached screenshots are regression captures of the established printed-label flow. New typed-name behavior and visual review have separate evidence directories. Static review of the final UI found no remaining blocker in automatic field focus, resetting the entry for a new selection, explicit Cancel/Escape, pending-entry Done and Auto guards, or the common manual/OCR pick-list path.
