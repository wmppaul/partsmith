# Known Limitations

This repo currently delivers a usable manual-first alpha, not the full product described in [score-part-extractor-spec.md](/Users/will/Documents/git/partsmith/score-part-extractor-spec.md).

## What The Alpha Already Covers

- native macOS document-based project workflow
- immutable embedded source PDF
- parts sidebar with color coding
- source vs preview modes
- manual band creation, moving, and top/bottom crop editing
- shared source-header selection or typed header text
- per-part preview/export settings like scale, gap, and title visibility
- preview rendering and PDF export
- `Export All` to a project-named folder
- undo/redo across the main editing flow

## Major Gaps Versus The Original Spec

### Detection and analysis

- There is no `Analyze` or `Auto Detect` pipeline yet.
- There is no staff/system detection, instrument-label detection, OCR, or OMR assist.
- There is no confidence display or repair workflow for automatic results because there are no automatic results yet.

### Scan rescue and page correction

- There is no scan rescue mode.
- There is no deskew, thresholding, de-noising, or rotation correction workflow.
- There are no per-page page-crop tools for difficult scans.

### Canvas editing depth

- Bands are full-width by default and only top/bottom editing is exposed in the canvas.
- Left/right trim is stored in the model for headers but still not available as a normal band-editing UI.
- There is no option-drag duplicate, batch editing, shift multi-select, or command-click add/remove workflow.
- There is no horizontal nudge or per-band scale override UI.

### Propagation and template workflow

- Propagation is still minimal.
- Current support is only `Copy To Next Page`.
- There is no copy to page range, copy selected part only, or match-similar-pages template propagation yet.

### Navigation and project ergonomics

- The left sidebar does not yet include page thumbnails or page-level project structure.
- There is no page search, part search, compare-before-after, or multi-window comparison workflow.
- The toolbar is still much smaller than the full spec vision.

### Preview and layout controls

- Preview stacks systems vertically, but there is no manual page-break editing.
- There is no drag reordering of extracted systems.
- There is no preview-side per-system nudge tool.
- There is no custom header/page-number system beyond the current typed header and source-header crop options.
- Output page size and margin controls exist in the model, but there is not yet a full user-facing settings workflow for them.

### Settings hierarchy

- The spec calls for clear global, per-part, per-page, and per-band settings layers.
- The alpha currently covers some project-level and part-level settings plus a few band controls.
- Per-page overrides and richer per-band overrides are still mostly missing.

### Persistence and platform polish

- The project currently embeds a copy of the source PDF for portability instead of using security-scoped external file bookmarks.
- The app is macOS-only and not packaged for the App Store.
- There is no automated test suite yet.

## Practical Next Steps

1. Improve propagation from `Copy To Next Page` to page-range and similar-page template copy.
2. Add left/right trim editing for bands.
3. Add page thumbnails and faster page navigation.
4. Add manual page-break and system reordering in Preview.
5. Add first-pass staff/system auto-detection for clean born-digital PDFs.
6. Add scan rescue tools for skewed or noisy scans.
7. Add automated tests around document model, layout planning, and export.
