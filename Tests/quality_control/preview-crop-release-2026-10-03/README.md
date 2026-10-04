# Preview crop editing release

The downloadable macOS app now edits source crops directly in the part Preview. Select a system, drag either blue edge, and release to apply one Undo operation. Pending removed ink is shaded, and Escape cancels. Page layout stays unchanged during the drag. After rendering, the selected system stays in view and manual zoom is retained. The selected source page and the same saved band geometry are used by score view and PDF export. Existing whiteouts are clipped to the resized source rectangle in the same Undo operation.

The exact PDF render plan is published with its PDF and snapshot. Stale previews, changed sources and scrolling or zooming during a drag cancel or disable the edit. Generated and compressed rests are not treated as ordinary source strips. The user can restore a compressed rest before cropping it.

Validation: 110 Core checks; 34 isolated native AppKit interaction checks; 5,389 layout assertions; 169 native export checks; and 24 full-part preview checks. The complete 131-band Brahms Trio fixture renders ten pages and enqueues in 0.23 ms. First, middle and final checked pages match ordinary export pixels. See [interaction evidence](../preview-crop-interaction-2026-10-03/README.md), [Core tests](../preview-crop-core-2026-10-03/README.md), and [independent review](../preview-crop-ui-independent-2026-10-03/README.md). Native tests use a hidden isolated window; the user's running app and documents were not opened or changed.

Release source was frozen before building. All 44 build input hashes match production; the app includes arm64 and x86_64 for macOS 14. The ad hoc signature passes strict verification; the build is not notarized. Every ZIP app entry matches the verified bundle and executable permissions are retained. Publication atomically replaced only the downloadable ZIP, after backing up the previous archive. The current app bundle was not replaced.

The shipped detector remains unchanged. The private monotone crop candidate has separate encouraging results but incomplete broad visual review, so it is not included in this release. This feature gives the user direct control of overlap; it does not certify automatic note ownership or prevent an intentional crop through notation.

`release.json` records artifact/source/bundle hashes, validation, scope and the previous ZIP backup. The public artifact SHA-256 is `817373ec3f6652144e3092bbdc93800f49b6bc4a6b6ff5b10b542d3226555fa9`. `verify_and_publish.py` verifies the frozen build and publication. `build-log.zip` preserves the complete Release build log.
