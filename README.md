# Partsmith

Partsmith is a document-based macOS prototype for extracting instrument parts from a full-score PDF by drawing editable horizontal crop bands on the source score and stacking those bands into per-part PDF exports.

## Alpha Download

- macOS alpha zip: [Partsmith v0.1.0-alpha.2](https://raw.githubusercontent.com/wmppaul/partsmith/v0.1.0-alpha.2/artifacts/macos/Partsmith-v0.1.0-alpha.2-macos.zip)
- If macOS says `Apple could not verify "Partsmith.app" is free of malware that may harm your Mac or compromise your privacy`, open `System Settings > Privacy & Security`, scroll down, and click `Open Anyway`.

## Getting Started

1. Create a new project in Partsmith.
2. Drag a full-score PDF into the center pane.
3. Set the header block:
   - use `Source Header`, click `Edit`, drag a header box, then click `Save` near the orange header box, or
   - switch to `Typed` and enter a title/subtitle.
4. Click `New Part` in the bottom-left sidebar.
5. Click on the first staff/system for that part to create a crop band.
6. Resize the band if needed by dragging the top or bottom edge.
7. Click the next staff/system for the same part. The previous band height is remembered.
8. Rinse and repeat for the remaining systems and parts.
9. Use `File > Export All...` or the toolbar share/export button while in `Source` mode.
10. Partsmith creates a folder named after the project and exports one PDF per part, using the part names as filenames.

## What Is Implemented

- Native SwiftUI macOS app shell with a `.partsmithproject` document type
- Embedded source PDF inside the project bundle
- Drag-and-drop PDF import
- Parts sidebar with part creation, color assignment, selection, and deletion
- PDFKit-backed source page viewer with fit-width and fit-page
- Editable horizontal crop bands with visible top and bottom drag handles
- Band moving, height inheritance, and copy-to-next-page propagation
- Shared `Source Header` selection or typed title/subtitle headers
- Right-side inspector for project, part, and band settings
- Preview mode that renders the selected part into stacked output pages
- Single-part PDF export from Preview
- Multi-part `Export All` from Source mode
- Undo/redo for import, part edits, band creation, resizing, exclusion, and deletion

## Run From Source

1. Open [Partsmith.xcodeproj](/Users/will/Documents/git/partsmith/Partsmith.xcodeproj) in Xcode.
2. Build the `Partsmith` scheme.
3. Launch the app and either:
   - import a PDF directly, or
   - open [Partsmith/Resources/Fixtures/SampleProject.partsmithproject](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleProject.partsmithproject)

## Project Layout

- [Partsmith.xcodeproj](/Users/will/Documents/git/partsmith/Partsmith.xcodeproj)
- [Partsmith/App/PartsmithApp.swift](/Users/will/Documents/git/partsmith/Partsmith/App/PartsmithApp.swift)
- [Partsmith/Core/DocumentModel/PartsmithDocument.swift](/Users/will/Documents/git/partsmith/Partsmith/Core/DocumentModel/PartsmithDocument.swift)
- [Partsmith/Features/SourceCanvas/SourceCanvasView.swift](/Users/will/Documents/git/partsmith/Partsmith/Features/SourceCanvas/SourceCanvasView.swift)
- [Partsmith/Core/Layout/PartLayoutEngine.swift](/Users/will/Documents/git/partsmith/Partsmith/Core/Layout/PartLayoutEngine.swift)
- [Partsmith/Core/Export/PartPDFExporter.swift](/Users/will/Documents/git/partsmith/Partsmith/Core/Export/PartPDFExporter.swift)

## Fixture Files

- [Partsmith/Resources/Fixtures/SampleScoreFixture.pdf](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleScoreFixture.pdf)
- [Partsmith/Resources/Fixtures/SampleProject.partsmithproject](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleProject.partsmithproject)

## Document Format

`*.partsmithproject` is a file package containing:

- `project.json`: project metadata, parts, bands, and settings
- `source.pdf`: the immutable embedded source score PDF

See [Partsmith/Resources/Fixtures/SampleProject.partsmithproject/project.json](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleProject.partsmithproject/project.json) for a concrete example.

## Limitations

Current gaps and next steps are summarized in [KNOWN_LIMITATIONS.md](/Users/will/Documents/git/partsmith/KNOWN_LIMITATIONS.md).
