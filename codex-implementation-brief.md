# Codex implementation brief — Partsmith macOS MVP

Build a native macOS document-based app called **Partsmith** for extracting individual instrument parts from a full-score PDF.

## Product direction
This is a geometry-first PDF extraction app, not an OMR or MusicXML editor.

## Required stack
- Swift
- SwiftUI for the shell
- PDFKit-backed source viewer
- custom overlay layer for editable crop bands
- document-based project file
- full undo/redo support

## Build this first vertical slice
Implement an end-to-end prototype with:
1. left sidebar listing parts
2. center PDF canvas showing one source page
3. right inspector for the selected part/band
4. ability to create a part with name + color
5. click on a page to create a horizontal crop band
6. draggable top and bottom handles to resize the band
7. assign a band to a selected part
8. preview mode that stacks the selected part’s bands into a generated output page
9. export that preview as a PDF
10. autosave + undo/redo for band creation and edits

## Constraints
- no OMR
- no cloud backend
- no iPad code yet
- no App Store packaging work yet
- keep source PDF immutable

## Architecture constraints
Separate code into modules for:
- app shell
- document model
- PDF source rendering
- editable canvas overlay
- part preview layout
- export

## UX constraints
- make source mode vs preview mode obvious
- support fit-width and fit-page zoom
- use visible handles, not hidden gestures
- all destructive actions must be undoable
- avoid modal dead ends

## Deliverables
- buildable Xcode project
- sample project document format
- simple example PDF fixture for testing
- README with run instructions
- brief note listing known limitations

## After the vertical slice
Next milestone is template propagation across pages with the same layout.
