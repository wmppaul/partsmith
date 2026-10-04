# Partsmith implementation brief

Partsmith is an existing native macOS app for extracting instrument parts from
full-score PDFs. The manual MVP and whole-score Auto workflow are implemented;
do not restart the original prototype milestone. Current behavior is documented
in [README.md](README.md), [product specification](score-part-extractor-spec.md)
and [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md).

## Product direction

Start with the **Auto Extract** magic wand, then make source review and local
correction easy. Preserve the original engraving and immutable embedded PDF.
This is geometry-first extraction with assistive local recognition, not general
OMR, MusicXML editing or a cloud service.

## Established workflow

- Choose all or selected input pages, optionally deskew before identification,
  and select printed instrument labels on the score. Names are highlighted,
  editable and kept distinct even when their printed text repeats. The floating
  **Done — Back to Auto Extract** control completes name picking.
- Review instrument order/staff counts, printed-header detection and optional
  direction/rest recognition; run Auto and resolve uncertain assignments.
  Readable zero-staff pages are skippable without acknowledgement gates.
- Use enlarged system assignment and reviewed layout examples when instruments
  change. Confirm silence and bar counts before inserting rests for omitted
  instruments; never infer them from an unassigned staff.
- Add parts as an undoable operation. Refine crops in Source or Preview using
  the same saved geometry, review all output and export one or all parts.

## Current layout contract

Scale, system gap and side margins are shared across the score by default.
**Customize This Part** creates a local override; **Use These Settings for All
Parts** synchronizes them again in one Undo. Other part controls remain local.

Scale is 0.60–1.40× and applies as requested. Width warnings are advisory;
notation may extend into margins or beyond paper edges. Do not restore a hidden
horizontal fit clamp. An indivisible band taller than the printable page still
needs vertical fitting. Default side margins are 18 pt. System Gap is a literal
4–200 pt even when Balance Page Fill is on. Shared horizontal source framing
within a part preserves alignment between strips instead of centering separately
trimmed content. Source crop geometry is separate from output layout.

Layout sliders commit after a drag and rebuild previews in the background.
Preserve cancellation of superseded work and guard stale drafts when switching
between score-wide and part-only controls.

## Architecture and implementation constraints

- Swift/SwiftUI shell with AppKit for native window/canvas behavior; PDFKit,
  CoreGraphics and CoreImage for source/rendering, Apple Vision for local text.
- Keep document transactions, detection/assignment, source rendering, layout,
  preview and export responsibilities separate.
- Use the same effective settings and layout plan for Preview and PDF export.
- Keep source PDFs immutable and record page rectification independently from
  crops. Never mix corrected coordinates with raw-source coordinates.
- Keep user edits undoable. Do not add review acknowledgements or typed blank-page
  reasons as prerequisites to accepting otherwise valid Auto output.
- Retain source context when musical ownership is ambiguous. Tightening a crop
  requires checking target ink outside its proposed edges.
- Rest compression is deliberately narrow and reversible; shared-direction
  copying is experimental. Do not describe either as full music understanding.
- No network or AI service is required by the macOS extraction workflow.
- The pre-release project format has no backward-compatibility commitment.
  Compatibility machinery is not a reason to block an otherwise useful change.

## Verification and delivery

Use focused existing checks appropriate to the change; instructions and source
cases live in [EXTRACTION_WORKFLOW.md](EXTRACTION_WORKFLOW.md). For detection or
export changes, review complete outputs against their source and test the actual
Auto/document/export path. Keep target preservation, neighboring ink, identity,
coverage and page layout as separate findings. A successful staff count, pixel
comparison or build alone does not establish musical completeness.

Verify saved-project reopen and native re-export when document state changes.
Use independent review agents for substantial extraction and layout changes.
Record frozen source/build evidence with release QA; keep dated historical
reports intact. Update getting-started instructions and limitations when a
feature changes, then package the native macOS download from the tested source.

Potential next work belongs in [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md),
with clear boundaries between implemented behavior and proposed improvements.
