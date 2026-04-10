# Partsmith

Partsmith is a document-based macOS prototype for extracting instrument parts from a full-score PDF by drawing editable horizontal crop bands on the source score and stacking those bands into a preview/export PDF.

## What is implemented

- Native SwiftUI macOS app shell with a `.partsmithproject` document type
- Embedded source PDF inside the project bundle
- Parts sidebar with part creation, color assignment, and deletion
- PDFKit-backed source page viewer
- Editable horizontal crop bands with visible top and bottom drag handles
- Right-side inspector for selected part and band settings
- Preview mode that renders the selected part into stacked output pages
- PDF export for the selected part
- Undo/redo for import, part edits, band creation, resizing, exclusion, and deletion

## Project layout

- [Partsmith.xcodeproj](/Users/will/Documents/git/partsmith/Partsmith.xcodeproj)
- [Partsmith/App/PartsmithApp.swift](/Users/will/Documents/git/partsmith/Partsmith/App/PartsmithApp.swift)
- [Partsmith/Core/DocumentModel/PartsmithDocument.swift](/Users/will/Documents/git/partsmith/Partsmith/Core/DocumentModel/PartsmithDocument.swift)
- [Partsmith/Features/SourceCanvas/SourceCanvasView.swift](/Users/will/Documents/git/partsmith/Partsmith/Features/SourceCanvas/SourceCanvasView.swift)
- [Partsmith/Core/Layout/PartLayoutEngine.swift](/Users/will/Documents/git/partsmith/Partsmith/Core/Layout/PartLayoutEngine.swift)
- [Partsmith/Core/Export/PartPDFExporter.swift](/Users/will/Documents/git/partsmith/Partsmith/Core/Export/PartPDFExporter.swift)

## Run

1. Open [Partsmith.xcodeproj](/Users/will/Documents/git/partsmith/Partsmith.xcodeproj) in Xcode.
2. Build the `Partsmith` scheme.
3. Launch the app and either:
   - import a PDF directly, or
   - open [Partsmith/Resources/Fixtures/SampleProject.partsmithproject](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleProject.partsmithproject)

## Fixture files

- [Partsmith/Resources/Fixtures/SampleScoreFixture.pdf](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleScoreFixture.pdf)
- [Partsmith/Resources/Fixtures/SampleProject.partsmithproject](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleProject.partsmithproject)

## Document format

`*.partsmithproject` is a file package containing:

- `project.json`: project metadata, parts, bands, and settings
- `source.pdf`: the immutable embedded source score PDF

See [Partsmith/Resources/Fixtures/SampleProject.partsmithproject/project.json](/Users/will/Documents/git/partsmith/Partsmith/Resources/Fixtures/SampleProject.partsmithproject/project.json) for a concrete example.

## Limitations

Current gaps are summarized in [KNOWN_LIMITATIONS.md](/Users/will/Documents/git/partsmith/KNOWN_LIMITATIONS.md).
