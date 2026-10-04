# System assignment release — October 4, 2026

This package adds drag selection, editable printed-barline count suggestions, page/system labels, and restored assignments when navigating. The selected staff geometry, manual count drafts and saved assignments are kept separate from background suggestions.

The review found and fixed three concrete issues: page return selecting the next empty slot after assignment; empty placeholder systems being mistaken for saved assignments; and a repeat drag over unchanged staves restoring an old saved count over a manual draft.

## Evidence

- [Selection and recall](../system-selection-2026-10-04/README.md): 96 checks of production geometry and saved-system recall, including page isolation and planner-created empty placeholders. This is not mouse-event coverage.
- [Printed bar counts](../system-bar-count-2026-10-04/README.md): 22 checks; Mozart source page 17 yields 6, 3 and 4 bars, and the scanned Beethoven opening yields 13. Includes ambiguity, double bars, skew and cancellation.
- [Background requests and native panel](../system-bar-ui-2026-10-04/README.md): independent lifecycle and production-view checks, with precise interaction scope in that report.
- `existing-assignment-test.log`: all 46 existing batch-assignment checks pass.
- `private-package-audit.json`: frozen source hashes, build inputs, architectures, minimum OS, signatures and exact ZIP extraction verification.
- `build-evidence.tar.gz` and `archive-members.json`: 47 source/build inputs plus build logs and audit scripts, all hashed.
- `publication.json`: final publication receipt and independent evidence references.

The app contains 37 compiled Swift files per architecture, supports arm64 and x86_64, requires macOS 14, and is ad hoc signed. Every existing Core source is unchanged from alpha.3; the new counter and background request worker are added alongside them. The other production changes are the assignment view and build-file registration. No user document or running app was modified for testing.

Automatic bar counting is a suggestion, not rhythmic recognition. It requires multiple corroborating staves and connecting barlines, and abstains on single-staff/disconnected/uncertain patterns. Pickups and split measures need musical review. This release does not claim improved crop quality or general instrument identification.
