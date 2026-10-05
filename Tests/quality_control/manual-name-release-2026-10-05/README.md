# Unnamed instruments on the score — Alpha 6

An empty or unreadable name selection now opens a focused text field and staff count in the score's persistent selection bar. Its box stays orange until the user adds a name; accepted names become green and join the editable Auto setup list. Separate occurrences with the same name become distinct parts. Cancel/Escape discards a pending entry; Done waits for it to be added or canceled. Naming does not alter crop geometry, saved parts or the source PDF.

The implementation changes five existing files: the name selection types, document selection lifecycle, Source canvas, Auto setup instructions, and document-owned window completion guard. Recognition algorithms and extraction/export logic are unchanged from Alpha 5.

## Independent checks

- [87 document/list checks](../manual-instrument-names-2026-10-05/README.md): real asynchronous blank selections, name/count validation, repeated/disjoint occurrences, stale-result cancellation, source/page/rectification changes, and unchanged real Brahms label recognition.
- [252 existing regression checks](../manual-name-regressions-2026-10-05/README.md): 205 printed-name checks and 47 native picker/window checks. Both existing suites passed without fixture or expectation changes.
- [56 native UI checks](../manual-name-ui-2026-10-05/README.md): actual drag events and field/button actions on the Beethoven movement 2 opening's unlabeled margin, with pending and accepted-state screenshots. Covers Add/Return, Cancel/Escape, separate same-name parts, staff count, window return, and the pending-name Auto guard. See that review for the exact interaction checks and limits of offscreen captures.

Tests use isolated processes, immutable source fixtures and private windows. They do not replace the running Partsmith app or open a user's editable document. The one-page Beethoven UI fixture is packaged with provenance so the test does not depend on an untracked sample directory. Native Vision/graphics access is required for these macOS tests.

Independent review caught an Auto-button path that could discard an unfinished name. Both the visible control and detection action now wait for name entry to be added or canceled; the Auto footer explains the next step. The new UI suite and existing picker suite ran again against that final change. The recognition suite's compiled inputs were unchanged. Root inspected the pending narrow-layout and accepted-name screenshots.

## Release provenance

The frozen snapshot contains 47 source/build inputs, including all 37 Swift files. The universal Release build and extracted app are checked for arm64/x86_64 support, macOS 14 minimum, valid ad hoc signatures, ZIP integrity and exact bundle-file/mode preservation. `source-hashes.json` binds the current implementation to the package; `build-evidence.tar.gz` preserves the build inputs and evidence.

`publish.py` verifies source and independent review manifests before replacing the local public ZIP. `publication.json` records the verified package hash and tests; `manifest.json` covers this review directory. GitHub publication uses the version-tag workflow. This is a name-entry UI release, not a new musical extraction quality review.
