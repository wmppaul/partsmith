# Partsmith macOS builds

[Download Partsmith v0.1.0-alpha.4](https://github.com/wmppaul/partsmith/releases/tag/v0.1.0-alpha.4) for the Mac ZIP, checksum and release notes. The repository's [Partsmith-extraction-preview-macos.zip](Partsmith-extraction-preview-macos.zip) contains the same reviewed app. Unzip and open `Partsmith.app`.

Requires macOS 14 or later, on Apple Silicon or Intel. The app is ad hoc signed and not notarized. If macOS blocks opening it, attempt to launch it and then use **System Settings → Privacy & Security → Open Anyway**.

## Start with Auto Extract

Follow the [Getting Started guide](../../README.md#getting-started-with-auto-extract). Import a PDF, open the magic wand, select the input pages, optionally deskew, and select the printed instrument names. **Done — Back to Auto Extract** returns to setup. Check the instrumentation, run **Auto**, then choose **Add Parts**. Blank pages are skipped without requiring an acknowledgement.

For changing instrumentation, enable **Instrument layout changes between systems** before Auto. In the enlarged assignment view, drag across one system's staves and check the printed instruments. Click to adjust; Shift-click or Shift-drag adds staves. **Page N · System N** identifies the current assignment. **Bars in system** suggests an editable count from corroborating printed barlines where possible. Single-staff, disconnected or ambiguous systems remain manual. Verify pickups, split measures and silence before assigning counted rests to omitted instruments. Revisiting a saved system or page restores its count, first bar, instruments and selected staves.

In **Preview**, click a system and drag its top or bottom handle to trim the crop. The same crop is used in Source, saved projects and PDF export. **Scale**, **System Gap** and **Side Margins** are synchronized across parts unless **Customize This Part** is enabled. New projects start with 18-point side margins. Gaps stay at the selected 4–200 pt even when balancing is on; requested enlargement is applied with an overflow warning instead of a silent width cap.

Eligible full-bar rest strips can be counted and compressed locally. Original crops are retained for restoration. Confirmed omitted instruments use editable inserted rests tied to their source system. Detection and layout reuse assist review; they do not establish every instrument identity, rest duration or shared musical marking.

## Review and build provenance

- [Current assignment release review](../../Tests/quality_control/system-assignment-release-2026-10-04/README.md)
- [Shared layout release review](../../Tests/quality_control/shared-layout-release-2026-10-04/README.md)
- [Extraction workflow and test commands](../../EXTRACTION_WORKFLOW.md)
- [Known limitations](../../KNOWN_LIMITATIONS.md)
- [Quality-control records](../../Tests/quality_control/README.md)
- [Release packaging procedure](../../docs/RELEASING.md)

Review intended notes, lyrics, shared markings, rest counts and page turns before performance. Dense overlapping notation can still include neighboring staves, and difficult scans or changing instrumentation can need correction. Historical quality-control records describe the exact build and scope tested at that time; their behavior and timings are not promises for the current app or every score.

The older `Partsmith.app` and `Partsmith-v0.1.0-alpha.2-macos.zip` in this directory are historical builds. Use the tagged download or current preview ZIP above. Source and rebuild instructions are in the repository root.
