# Score Part Extractor for macOS — Product + Engineering Spec

## Project codename
Partsmith

## Product goal
Build a native macOS app that turns a full-score PDF into clean individual part PDFs by selecting, assigning, and relayouting staff regions from the source score.

The app should optimize for:
- preserving the original engraving
- fast manual correction when detection is imperfect
- a macOS-native workflow for large monitors, keyboard shortcuts, drag/resize precision, and multi-window use

## Core product decision
This is a **geometry-first extraction app**, not a notation-OMR editor.

That means:
- the primary pipeline copies/clips regions from the source PDF
- the output stays visually faithful to the original score
- OCR/OMR is only used as assistive metadata or rescue tooling
- full music re-engraving is explicitly out of scope for V1

## Users
- conductors
- orchestra librarians
- arrangers and engravers
- teachers
- chamber musicians working from public-domain or rehearsal PDFs

## File types
### Inputs
- PDF full scores
- born-digital PDF scores
- scanned / photocopied PDF scores

### Outputs
- per-part PDF files
- project document bundle containing source reference, selections, settings, previews, and export presets

## Product principles
1. **Manual-first, auto-assisted**
   Automation should accelerate setup, not block progress.
2. **Everything is editable**
   Any detection result can be nudged, replaced, copied, or deleted.
3. **Native desktop ergonomics**
   Toolbar, inspector, keyboard commands, thumbnails, multi-select, undo, drag-drop.
4. **Stable geometry model**
   Global defaults, part-level settings, and page/system overrides must be clearly separated.
5. **Non-destructive**
   Source PDF remains untouched; the project stores transforms and assignments only.

## Non-goals for V1
- MusicXML export
- note-level editing
- collaborative cloud sync
- iPad support
- App Store release requirements
- automatic part extraction from arbitrarily bad scans with no manual intervention

## Competitive / inspiration takeaways
### Good ideas to borrow
- Select parts on the full-score canvas using visible top/bottom crop bands.
- Maintain a dedicated parts list with color coding.
- Offer a separate preview/layout stage for each part.
- Allow per-part settings like scale, title visibility, and staff separation.
- Support copy/paste of selection outlines across pages with similar layout.
- Keep both an automatic mode and a manual mode.

### Pitfalls to avoid
- Hidden navigation between selection mode and preview mode.
- Weak or absent undo/redo.
- iPad-style UI compromises on macOS.
- Over-promising “magic” detection without showing confidence or an easy repair path.
- Fragile zoom/navigation and poor large-screen behavior.
- No deskew / rotation correction for scanned pages.
- Unclear distinction between global settings and part-specific overrides.
- Freezes during analysis or export.

## UX overview
## Main window layout
Three-pane desktop layout:

1. **Left sidebar**
   - project / pages / parts
   - page thumbnails
   - part list with color chips, staff-count badge, export status

2. **Center canvas**
   - full-score PDF view or part preview
   - vector overlay layer for boxes, bands, handles, labels, confidence hints
   - zoom, pan, fit-width, fit-page, rotate, compare-before-after

3. **Right inspector**
   - context-sensitive settings
   - document settings
   - selected page settings
   - selected part settings
   - selected band/staff settings

Top toolbar:
- Import PDF
- Analyze
- Auto Detect
- Manual Band Tool
- Propagate
- Preview
- Export
- Undo / Redo
- Search page / part
- Toggle scan rescue

## Primary workflow
### Flow A: Clean born-digital PDF
1. Open PDF.
2. App analyzes pages and detects staff/system candidates.
3. User creates parts or imports detected instrument names.
4. User assigns bands to parts on representative pages.
5. User propagates template to similar pages.
6. User reviews each part in preview mode.
7. User adjusts layout settings per part.
8. Export selected or all parts to PDF.

### Flow B: Scanned / photocopied PDF
1. Open PDF.
2. User toggles Scan Rescue Mode.
3. App deskews, thresholds, and detects staff candidates.
4. User corrects page rotation / skew if needed.
5. User assigns bands to parts.
6. Remaining flow is identical.

## Interaction model
### Selection on the score canvas
Selections are **horizontal bands** spanning left-to-right music content, with adjustable:
- top crop
- bottom crop
- left trim
- right trim
- per-page vertical offset

Each band belongs to exactly one part and one source page.

### Recommended band behavior
- click on a staff center to create a band snapped to the nearest staff group
- drag top/bottom handles to refine crop
- option-drag duplicates a band
- command-click adds/removes source systems from a part
- shift-select enables batch edits to multiple bands
- copy current page outline to next page / page range
- copy one part’s layout to another part when page structure matches

### Preview mode
Preview mode should show the assembled destination part pages, not the source page.

In preview mode the user can:
- adjust scale
- adjust staff separation
- toggle title block
- edit title/composer/part name text
- toggle source page numbers / custom headers
- choose page size and margins
- reorder or suppress extracted systems
- insert manual page breaks

## Settings hierarchy
### Global project settings
- output page size (Letter, A4, custom)
- default margins
- default scale
- default inter-system gap
- source-side trim defaults
- scan rescue defaults
- export quality preset

### Per-part settings
- part name
- color
- expected staves per system
- show title
- title text
- composer text
- header alignment
- scale override
- staff separation override
- margin override
- page-break strategy

### Per-page override
- page rotation
- deskew angle
- page crop trim
- layout template id

### Per-band override
- top/bottom/left/right crop
- x/y nudges
- scale override
- include/exclude in export

## Data model
### ProjectDocument
- id
- projectName
- createdAt
- modifiedAt
- sourcePDFBookmarkData
- sourcePDFFileHash
- pageCount
- projectSettings
- pages: [PageModel]
- parts: [PartModel]
- templates: [LayoutTemplate]
- exports: [ExportRecord]

### PageModel
- pageIndex
- sourceSize
- rotationDegrees
- deskewDegrees
- contentBounds
- scanModeEnabled
- rasterCacheKey
- detectionResult
- assignments: [BandAssignment]

### DetectionResult
- systems: [SystemCandidate]
- instrumentLabelCandidates: [TextLabelCandidate]
- confidenceSummary
- detectionMode (vector | raster | rescue)

### SystemCandidate
- id
- bounds
- staffLineGroups
- estimatedStaffCount
- confidence

### PartModel
- id
- name
- color
- expectedStavesPerSystem
- layoutSettings
- sourceBandRefs
- previewCacheKey

### BandAssignment
- id
- pageIndex
- partID
- systemCandidateID?
- rect
- snappedTop
- snappedBottom
- leftTrim
- rightTrim
- sourceOrderIndex
- excluded

### LayoutTemplate
- id
- name
- pageRangeRule
- normalizedBandRects
- expectedSystemCount

## Architecture
## Recommended tech stack
### UI
- SwiftUI for app shell and inspector UI
- AppKit interop where needed for precision desktop behavior
- PDFKit-backed viewer for source PDF rendering/navigation
- custom overlay layer for editable bands and handles

### Core document handling
- PDFKit / Quartz for reading, rendering, navigation, and writing PDF-related data
- CGPDF inspection layer for low-level page metadata and optional content parsing

### Image / scan pipeline
- Core Image / Accelerate for basic preprocessing where practical
- optional OpenCV bridge module for deskew, thresholding, morphology, and staff-line detection
- Vision only for assistive OCR tasks such as instrument labels or bar-number hints, not for full music recognition

### Storage
- document-based project file bundle
- JSON metadata + thumbnails/cache subfolders inside bundle
- autosave snapshots

### Packaging
- native macOS .app
- direct distribution first
- code signing and notarization later

## Module breakdown
### 1. App Shell
Owns window lifecycle, menus, commands, settings, recent documents, autosave, crash recovery.

### 2. Project Document Module
Reads/writes the project bundle and security-scoped reference to source PDF.

### 3. PDF Source Module
Opens source PDF, renders pages at requested scale, exposes page geometry and searchable text.

### 4. Detection Engine
Produces page-level system candidates.

Submodes:
- vector-aware mode for clean PDFs
- raster-rescue mode for scans/photocopies

### 5. Assignment Engine
Maps detected systems/bands to parts and supports propagation across pages.

### 6. Layout Engine
Builds assembled part pages from source bands using target page size, margins, scale, and separation.

### 7. Export Engine
Writes one PDF per part and optionally a zip bundle.

### 8. OCR Assist Module
Reads instrument labels and optional text hints for header/title suggestions.

### 9. Cache Engine
Stores rendered page thumbnails, preview pages, and detection intermediates.

## Detection strategy
## V1 detection philosophy
Use the cheapest robust method first.

### Tier 1: Vector-aware heuristics
For clean PDFs:
- render page preview at moderate resolution
- estimate music content bounds
- detect horizontal line clusters corresponding to staves
- group staves into systems by vertical spacing and horizontal overlap
- optionally cross-check with PDF text near left margin for instrument labels

### Tier 2: Scan rescue heuristics
For scans:
- grayscale normalize
- adaptive threshold
- estimate skew angle from horizontal line response
- deskew
- detect staff lines via morphology / projection profile
- group 5-line staffs into systems
- estimate left content anchor and staff spacing

### Tier 3: Manual fallback
When confidence is low:
- user clicks to define band centers
- app snaps to nearest candidate lines if possible
- user can freely override snap

## Propagation model
The app should support three propagation modes:
1. **Same-page template propagation**
   Copy the current page’s band pattern to another page with similar spacing.
2. **Affine page adaptation**
   Allow vertical offset + scale correction when the same layout is slightly shifted.
3. **Manual exceptions**
   Preserve per-page corrections without breaking the template.

## Layout engine behavior
The layout engine takes assigned source bands and places them into destination pages.

### Placement responsibilities
- compute target page size and margins
- place title block if enabled
- stack extracted systems vertically
- apply user scale and staff separation
- preserve original source aspect ratio within each band
- allow manual per-band nudge in preview
- generate page breaks when content overflows

### Important constraint
V1 should **not** attempt musical reflow. It should only relayout image/vector excerpts as stacked systems.

## Export rules
- export all parts or selected parts
- preserve source rendering fidelity as much as possible
- embed metadata: title, composer, part name, source filename
- allow export preset: draft / standard / print
- export into user-selected folder

## Error handling and trust
### Must-have trust features
- Undo / Redo across all edit operations
- Autosave
- explicit “Revert page” and “Revert part layout”
- low-confidence warnings for auto detection
- activity indicator with cancellable background jobs
- immutable source PDF

### User-facing confidence model
Each page gets one status badge:
- Green: high-confidence template match
- Yellow: review recommended
- Red: manual attention needed

## Performance requirements
- open a 200-page PDF without blocking the UI thread
- render page thumbnails lazily
- analyze pages in the background with cancellation
- keep canvas interaction responsive at 60 fps target for common operations
- cache page rasters and preview outputs
- incremental export: only re-render modified parts where possible

## Accessibility and desktop polish
- full keyboard navigation
- standard macOS menus and shortcuts
- adjustable sidebar widths
- high-contrast selection handles
- reduced-motion-friendly transitions
- VoiceOver labels for controls where reasonable

## Suggested keyboard shortcuts
- Cmd+O open PDF/project
- Cmd+S save project
- Cmd+Shift+E export
- Cmd+Z undo
- Cmd+Shift+Z redo
- Space toggle preview
- A auto-detect mode
- M manual band tool
- P propagate
- F fit width
- 0 fit page
- ] next page
- [ previous page

## V1 feature list
### Must ship
- open PDF
- save/open project bundle
- page thumbnails
- full-score canvas with editable crop bands
- part list with colors and names
- manual assignment workflow
- template copy/paste across pages
- per-part preview
- show title toggle
- scale control
- staff separation control
- export PDFs
- undo/redo
- autosave
- scan rescue basic deskew + threshold + manual correction

### Nice to have for V1.1
- OCR instrument-name suggestions
- confidence badges
- batch propagation across page ranges
- export quality presets
- page rotation shortcuts
- compare source vs preview split mode

### Phase 2
- instrument-name auto-suggestion using OCR/text
- bar number overlay workflow
- rehearsal mark propagation
- smart grouping by repeated layout archetypes
- iPad build

### Explicitly deferred
- full OMR / MusicXML
- ML-trained band detector
- cloud sync / multiuser

## Acceptance criteria
### Manual extraction
Given a clean quartet score PDF,
when the user defines 4 parts and selects representative bands,
then they can export 4 readable part PDFs without leaving the app.

### Template propagation
Given pages with consistent system geometry,
when the user copies a page template to a range,
then all target pages receive aligned bands with only minor review required.

### Preview editing
Given an extracted violin part,
when the user changes scale, title visibility, and staff separation,
then the preview updates live and export matches preview.

### Rescue mode
Given a slightly skewed scanned page,
when the user enables Scan Rescue Mode,
then the app offers deskew and allows reliable manual band selection.

### Recovery
Given a mistaken delete or drag,
when the user presses Undo,
then the project returns to the exact prior state.

## Testing matrix
### Inputs
- born-digital chamber score
- orchestral score with many staves
- piano-vocal score
- choir score with systems of varying heights
- skewed scan
- photocopy with low contrast
- PDF with rotated pages
- password-free but malformed PDF

### Edge cases
- instrument changes mid-score
- tacet pages
- empty pages
- page turns requiring manual breaks
- repeated headers consuming vertical space
- systems that shift slightly page to page
- two-staff instruments mixed with one-staff instruments

## Suggested project structure
```text
Partsmith/
  App/
    PartsmithApp.swift
    Commands/
    Windows/
  Features/
    Project/
    SourceCanvas/
    PartPreview/
    PartsSidebar/
    Inspector/
    Export/
  Core/
    DocumentModel/
    PDFSource/
    Detection/
    Assignment/
    Layout/
    OCRAssist/
    Caching/
  Bridges/
    PDFKitBridge/
    OpenCVBridge/   # optional
  Resources/
  Tests/
    Unit/
    Snapshot/
    Integration/
```

## Implementation milestones
### Milestone 1 — Skeleton app
- document-based macOS app shell
- open/save project
- PDF rendering with thumbnails
- split-view UI shell

### Milestone 2 — Manual extraction MVP
- create parts
- draw/edit bands
- assign to parts
- preview assembled part pages
- export PDFs
- undo/redo

### Milestone 3 — Template propagation
- copy/paste page outlines
- page-range propagation
- part settings inspector

### Milestone 4 — Scan rescue mode
- threshold + deskew
- rescue toggles
- confidence indicators

### Milestone 5 — Polish
- keyboard shortcuts
- autosave recovery
- performance pass
- onboarding and help overlays

## Notes for Codex
1. Build the app as a **document-based macOS app**.
2. Keep extraction **geometry-first**; do not start with OMR.
3. Prefer a working manual MVP before clever detection.
4. Separate the app into UI, detection, assignment, layout, and export modules.
5. Keep all model edits undoable.
6. Make the source/preview mode switch obvious and keyboard accessible.
7. Avoid hidden gestures as primary controls.
8. Treat scan rescue as an explicit mode, not the default.
9. Use fake/sample PDFs and snapshot tests for layout regressions.
10. Leave clear extension points for future iPad support.

## First concrete coding task for Codex
Build a macOS document-based prototype with:
- a left parts sidebar
- a center PDF canvas using PDFKit
- a right inspector
- editable top/bottom crop bands on the source page
- a simple preview generator that stacks selected bands into a new page
- export of one part as PDF
- full undo/redo for band edits

That is the smallest end-to-end slice that proves the product.
