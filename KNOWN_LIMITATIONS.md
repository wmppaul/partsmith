# Known Limitations

- The MVP is manual-first only. There is no auto-detection, OMR, OCR, or scan-rescue processing yet.
- Source mode currently works on one page at a time and does not include page thumbnails.
- Bands only expose top/bottom editing in the canvas. Left/right trims are stored but not yet editable in the UI.
- The preview renderer stacks systems vertically but does not support manual page breaks, reordering, or per-band preview nudging yet.
- Part-level edits in the inspector currently register undo steps as values change; there is no coalescing for long slider drags.
- The project bundle embeds a copy of the source PDF for portability instead of using security-scoped external file bookmarks.
- There are no automated tests yet. Verification in this pass was a successful local `xcodebuild` of the `Partsmith` scheme.
