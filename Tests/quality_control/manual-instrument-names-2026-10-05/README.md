# Manual instrument name regression review

All **87 checks passed** using the real asynchronous document recognition path and the editable instrument list used by Auto Extract. Run `bash tools/test_manual_instrument_names.sh`. Native macOS Vision access is required for the final real-score OCR check.

The fixture is an otherwise blank two-page PDF, so manual naming does not depend on a particular OCR failure. Checks cover blank clicks and boxes, exact source geometry, empty-name/staff-count validation, custom text, whitespace normalization, repeated and resized selections, distinct same-name parts, green highlight naming, cancellation, navigation during OCR, source replacement, rectification changes, session ending, newer selections replacing older ones, and invalid geometry. Naming never changes the saved project or source PDF.

A real Brahms quartet label still recognizes `1. Violine` immediately; selecting its blank margin offers manual naming while retaining the prior highlight. Canceling an in-flight read prevents a late result.

The initial sandbox execution passed manual state checks but macOS Vision abstained on the real printed label. The identical executable passed every check when run with native graphics access. This is a test-environment constraint, not a fallback claim that OCR succeeds without Vision access.

This suite validates model/list behavior. UI layout, drag delivery, focus and window navigation need the separate application review. `source-hashes.json` records the tested core and test source files; `verification.json` records the executable hash.
