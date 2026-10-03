# Auto review crop-edit correction — 3 October 2026

The new preview fixes a repeat-ending omission caused by editing a crop in Auto review. It changes only `Partsmith/Core/DocumentModel/PartsmithDocument.swift`: new crop overrides now use `ScoreSystemAssignment.pageOverride`, which preserves the identity of automatically suppressed local endings. Existing explicit overrides keep their original data and review reason.

When both endings already appear above a recipient's own staff, Partsmith omits the redundant shared copy. Previously, the first crop edit materialized that empty list without its automatic identity. If the crop then excluded the local ending, the planner treated the empty list as a deliberate removal and could not restore the required copy. The corrected public `setCropEdges` and `resetCropEdges` paths preserve that identity. Reversing the crop suppresses the redundant copy again; explicit **Remove Copy** remains authoritative.

## Verification

- The [independent public-API reproduction](../crop-edit-ending-provenance-2026-10-03/README.md) freezes production and a candidate differing in exactly one of 23 Core files. The baseline has nine failed or blocked records; the candidate passes all 30 checks. Both pass the old 62 local-ending checks, demonstrating the previous test gap.
- The focused checks cover clipping, reversing, reset, a first no-op/reset, intentional removal, initial explicit empty/nonempty lists, unrelated directions, invalid-edit atomicity and generated-rest/omission preservation. Existing recognition and source geometry remain intact.
- The production document suite passes 139 assertions, including background Auto, review, all-part application, Undo, persistence, export and cancellation. The permanent local-ending suite passes 70 checks, including eight added actual crop-API checks, with a standalone runner: `bash tools/test_local_ending_counterparts.sh`.
- A fresh universal Release build succeeds for arm64 and x86_64. All 34 source/configuration files match the compiled snapshot. A separate agent verifies those hashes, the absence of experimental heading changes, both Mach-O architectures, ZIP integrity and all three bundled files against the compiled app.

The current local download is [Partsmith-extraction-preview-macos.zip](../../../artifacts/macos/Partsmith-extraction-preview-macos.zip), SHA-256 `b47fe4e23505bc1ce649b0f85919232b2181b940c90f0d66e3f0f9ba99c7d48a`. Its executable SHA-256 is `a3a46fa1889d2251436c0211122b6f7c09c87f5106d18b8f5aa06e1410396899`. This is a universal macOS 14+ preview without Developer ID signing or notarization. The running app and user documents were not replaced or relaunched. No live SwiftUI interaction is claimed; the exact methods invoked by the UI were tested.

`release.json` records final checks and artifact hashes. `independent-package-audit.json` is the agent's unchanged staged-build audit. `build-evidence.zip` retains the build log, test logs, source/configuration snapshot and verification records. The preceding ZIP remains at `.build/crop-review-release-2026-10-03/Partsmith-preview-before-crop-review.zip` and in commit `d2a43e1`; its SHA-256 is `0ba904a3cf91748d0e700bd8ecbbed795e6511f56a4c09fb1ca17b6d16778c8e`. Earlier build records remain historical and unchanged.

## Scope and retained limitations

The analyzer, planner, heading recognizer and exporters are unchanged. Existing complete part PDFs and projects were not regenerated, and this release does not claim improved automatic crop boundaries or new musical coverage. The fix applies when a fresh review materializes automatic choices; it does not reinterpret old explicit lists as automatic choices.

Two parallel studies remain outside production. The [terminal-body cleanup candidate](../terminal-body-continuation-2026-10-03/README.md) was rejected because removing neighboring staff context introduced 21 failures in the unchanged 297-case source suite. The [216 new physical-staff source controls](../terminal-body-independent-2026-10-03/README.md) expose additional hollow/tied-head limitations: 58/180 original cases and 24/36 supplemental cases fail under current production. These are authored conservative geometry obligations, not counts of missing notes in delivered scores.

The [heading deduplication study](../heading-local-ownership-2026-10-03/README.md) passes ten strict whole-block safety fixtures but resolves none of the three reviewed real duplicates. A later mutation check also exposes a stale global-block matching proof. No experimental heading metadata, matcher or planner code is included in this release. Overlapping notation, shared directions, variable instrumentation and page turns still require source review; the wider extraction goal remains unfinished.
