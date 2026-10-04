# Automatic system count request and native assignment review

These checks exercise the production request worker and `ScoreExtractionView` in a private, inactive macOS window. No running Partsmith app or user document was opened or changed.

The native test runs real Auto detection on two separately indexed copies of tracked Mozart K.488 source page 17. The duplication permits deterministic page-navigation checks without analyzing the complete concerto. It selects the first six staves and the later piano-only pair, whose expected counts are six and three bars respectively.

`request-results.json` records 21 checks: latest-request publication, cancellation of running and queued work, main-thread result delivery, abstention, owner deallocation, and forty rapid cancellation races. The injected counter deliberately permits an old request to return after cancellation; it must never overwrite the latest result.

`ui-results.json` records 14 native panel checks. These cover automatic suggestions, an explicit edit taking precedence, saving and revisiting an assignment, recalling the last saved system instead of an unsaved next slot, avoiding cross-page count leakage, and restoring saved counts after changing review modes. Direct `NSEvent` mouse-down/drag/up events also select all six staves from an empty selection and repeat the same drag after editing a saved count, verifying that the draft survives. Counts **11, 12, and 9 are deliberately artificial manual-edit probes**, not reviewed musical counts. No output parts are committed by the test.

The PNG files are native `NSHostingView` captures of the actual production panel. Offscreen capture omits some prominent button fills and text; the corresponding controls remain present in the accessibility snapshots and their actions are exercised. This evidence verifies panel content, selection, and state transitions; it is not a full foreground application/window-focus test. Modifier-key, zoomed, and scrolled drag behavior is covered separately by geometry checks and code review, not native event interaction in this harness. Automatically advancing into an already assigned next system was code-reviewed but was not exercised by this panel harness.

Run from the repository root on macOS:

```sh
bash tools/test_system_bar_request.sh
bash tools/test_system_bar_ui.sh
```

The native script first copies its production inputs to a private build snapshot. `source-hashes.json` binds this review to the compiled production files, harnesses, scripts, and tracked PDF fixture. `manifest.json` hashes the durable evidence. Build products remain under `.build/system-bar-request-review`.
