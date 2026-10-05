# Partsmith — product and engineering specification

This describes the current macOS extraction preview as of October 2026. It
replaces the original manual-MVP proposal. See [README.md](README.md) for the
getting-started flow and [KNOWN_LIMITATIONS.md](KNOWN_LIMITATIONS.md) for current
limits; neither the feature list nor a successful detection run certifies a
score's musical completeness.

## Product goal

Turn full-score PDFs into readable individual parts while preserving the source
engraving. Support born-digital scores and scans, run locally without a network
connection, and make corrections practical on a large score.

Partsmith is a geometry-first extraction app. It detects staff geometry and
copies PDF regions; local text recognition assists instrument setup and shared
markings. It does not transcribe pitches or rhythms, transpose, re-engrave
playing music, or export MusicXML. The narrow multi-bar-rest feature generates
rest notation only for supported or explicitly counted silent passages.

## Product principles

1. **Start with Auto, keep corrections accessible.** The magic wand is the main
   entry point. Manual parts and crop drawing remain available.
2. **Preserve intended notation.** A crop may retain neighboring ink when that
   is necessary to keep a target note, lyric, slur or direction. Cleaner-looking
   output does not justify deleting target notation.
3. **Keep the source immutable.** Projects embed the source PDF and store crop,
   rectification and layout metadata separately.
4. **Share score layout by default.** Scale, system gap and side margins stay
   synchronized; a part can explicitly override them.
5. **Make changes undoable and visible.** Source and Preview edit the same bands;
   previews and native exports use the same layout engine.

## Current primary workflow

1. Import a PDF and open **Auto Extract**. Its window can move and resize.
2. Use **All Pages** or **Selected Pages** with thumbnails and page ranges to
   define the input. This selection also controls deskew and analysis.
3. For a scan, optionally run **Deskew & Align Pages** before identifying names
   or staves. Existing corrections are kept. Once source crops or a header exist,
   adjust page alignment in the Inspector and recheck affected crops.
4. Choose **Select Instrument Names on Score**. With a page selection, picking
   opens the first included page. Click or drag around complete printed labels
   in top-to-bottom order, including any instrument number. Recognized labels
   remain highlighted and editable. Separate repeated labels become distinct
   parts. For an unnamed staff, drag a box in the blank space beside it, enter a
   name and staff count in the source bar, and choose **Add Instrument** or
   Return. A pending typed entry can be canceled; adding it uses the same unique
   name and source occurrence rules as recognition. These boxes are setup
   markers, not crop geometry. Use **Done — Back to Auto Extract** to return.
   Starting profiles and typed names are alternatives; a piano grand staff uses
   two staves. Name recognition does not prove the instrument assignment.
5. Review staff counts and Lyrics options. Leave printed-header detection on to
   propose source artwork for the first output page. Shared-direction copying
   is experimental and enabled for new consistent-layout setups; automatic
   full-bar-rest compression is also offered.
6. Run **Auto**. Inspect crop proposals, the printed header and uncertain
   assignments. Readable pages with no detected staves are skipped without an
   acknowledgement or typed reason; **View Skipped Pages** and **Restore Page**
   make recovery available. A failed page render is an error, not a blank page.
7. For changing instrumentation, use **Assign Instruments** on the enlarged
   score, drag across each printed system's staves, and identify its actual
   roster. The selection highlights live; clicks and Shift selection refine it.
   **Page N · System N** supplies page context. **Bars in system** can suggest an
   editable count from clear connected barlines; verify it before assigning
   rests for absent instruments. Revisiting assigned systems restores their
   roster, staff counts, first bar and bar count.
   **Find Similar Systems** reuses reviewed examples but cannot establish a new
   instrument identity from staff count alone.
8. Choose **Add Parts**. Adding parts is one undoable transaction; automatic
   rest compression runs separately and has its own Undo.
9. Review every part in **Preview**. Select a system and drag its top or bottom
   handle to refine its crop; the same change appears in Source and export.
   Restore a compressed source strip before editing its crop. Check the source
   beyond both edges, not only the visible output.
10. Adjust shared layout and explicit musical page breaks, save the project,
    and export the selected part or **Export All**. Compare output pages with
    the source, including shared directions and rest counts.

## Current interface and editing model

The main window has a parts sidebar, a Source/Preview canvas and a contextual
Inspector. Source supports PDF navigation, Fit Width/Fit Page, visible crop
handles, band moving and copying bands to later pages. Manual **New Part** and
crop drawing provide a fallback. Auto offers its own scrollable input-page
previews and enlarged assignment workflow.

A source band belongs to one part and source page. Saved geometry includes
horizontal and vertical crop bounds. Source and Preview expose top/bottom crop
handles; Preview does not independently reposition music from its source crop.
Bands can retain exclusions, editorial labels, copied source markings, bar
numbers and explicit page breaks. Generated rests for omitted staves are saved
separately from crops because no printed staff exists to restore.

Printed-header selection copies source artwork; typed titles remain available.
A header proposal can be adjusted on the score or disabled. Existing manual
header choices are kept unless edited. Shared directions retain source
rectangles, placement and recipient identity; optional automatic recognition
must still be checked against the score.

## Settings and pagination

- **Score layout:** output size is Letter or A4. Default margins are 18 pt left
  and right, 48 pt top and bottom. Scale, system gap and side margins apply to
  all linked parts.
- **Part overrides:** **Customize This Part** freezes those three effective
  settings for the selected part. Turning it off resumes score settings.
  **Use These Settings for All Parts** promotes the selected values and removes
  every part's overrides in one undoable change. Titles, color, Balance Page
  Fill and Use Consistent Scale remain part settings.
- **Scale:** 0.60–1.40×. The chosen horizontal scale is applied, even beyond the
  recommended width. **Fits Within Margins** warns when music can reach beyond
  margins or the physical paper edge. It does not cap the slider's effect.
  Above 1.00, verified blank source side margins can be removed without changing
  saved crops. A single indivisible band too tall for the printable page still
  needs vertical fitting.
- **System Gap:** 4–200 pt, honored at the selected value even with Balance Page
  Fill enabled. Larger gaps can add pages; balancing does not silently reduce
  the chosen spacing.
- **Alignment:** Use Consistent Scale shares a horizontal source frame within
  the part, avoiding shifts caused by independently trimming each strip. Source
  indents remain part of the engraving; selecting instrument names does not
  create a separate layout indent.
- **Page turns:** complete strips are stacked and paginated without musical
  reflow. **Start on New Page** provides a reviewed break. The engine does not
  infer safe musical turns.
- **Responsiveness:** layout sliders retain their draft while dragging and
  commit on release. Preview work runs in the background and superseded work
  is discarded. Large-score performance remains a test requirement, not a
  blanket real-time guarantee.

## Architecture and storage

The native app uses Swift/SwiftUI with AppKit, PDFKit, CoreGraphics, CoreImage
and Apple Vision. It has no Python runtime, cloud backend or AI-service
requirement. The separate extraction skill offers a portable Python workflow.

| Area | Responsibility |
| --- | --- |
| `App` and `Features` | Document windows, guided Auto, Source, Preview, Inspector and export controls |
| `Core/DocumentModel` | Saved project state, source embedding, undoable transactions, background analysis coordination |
| `Core/Detection` | Staff evidence, instrument profiles, system assignments, crop context and assistive recognition |
| `Core/PDFSource` and `Core/Rendering` | Original and rectified source rendering and geometry |
| `Core/Layout` | Effective shared/part settings, strip placement, headers, rest rows and pagination |
| `Core/Export` | Native PDF output and preview generation |

A `.partsmithproject` bundle contains `project.json` and the immutable
`source.pdf`. The JSON holds project settings, parts, bands, instrumentation
setup and page rectifications. See
[ProjectModels.swift](Partsmith/Core/DocumentModel/ProjectModels.swift) for the
implemented schema. Cached work is not a substitute for saved source geometry.
There is no compatibility commitment for this pre-release format.

## Detection and review boundaries

Staff detection uses skew-aware evidence from multiple horizontal regions and
supports different staff sizes on one page. Compact crops follow notation with
context; Lyrics and per-instrument padding refine that context. Explicit deskew
changes the rendered coordinate space, while skew-aware detection alone does
not straighten the exported source. Keep original and corrected coordinates
separate in tests and corrections.

Instrument picking reads user-selected labels locally. Assignment applies the
reviewed roster; it does not independently understand every staff. Reusable
layouts compare reviewed source examples. Condensed scores, changing divisions
and omitted instruments may need manual system assignments and verified counts.

System bar-count suggestions require multiple selected staves with consistent
barline evidence and connections across a staff gap. Single-staff selections,
disconnected barlines and uncertain geometry remain manual. Suggestions fill an
empty field without replacing entered or assigned values. They count printed
bar compartments and cannot establish the duration of pickups, split measures
or unprinted silence. Cancel work when its page, system or selection changes.

Automatic direction copying currently targets supported tempos, navigation
instructions, linked symbols and paired first/second endings in consistent
instrument layouts. Other endings, rehearsal letters and measure numbers still
need source review. Recognition failure cannot be treated as proof of absence.

Automatic rest compression supports eligible complete single-staff strips and
two-staff groups with matching whole-rest measures and clear bar boundaries. It retains opening and ending source
context and leaves uncertain notation unchanged. Consecutive confirmed rests
join by default; retain later printed prefixes, directions, explicit breaks and
uncertain ending boundaries. A compressed opening can extend through following
inserted rests when its closing barline is ordinary. All source rows stay editable.
It is not general rhythmic
recognition and does not infer the silence of an unassigned instrument.

## Verification and release criteria

- Exercise born-digital, scanned, vocal, grand-staff and changing-roster scores.
- Check instrument identity, all source systems and intended notation, shared
  directions, rest counts, neighboring context and final pagination separately.
- Compare Source and Preview edits, undo/redo, saved-project reopen and export.
- Cover shared settings, isolated overrides, promotion to all parts, literal
  scale/gap behavior and source alignment with focused regression tests.
- Run actual Auto/document/export paths when assessing the app; a detector's
  staff count alone does not test names, headers, directions or final output.
- Package a native macOS app and record build/source evidence. Direct download
  is supported; Developer ID signing and notarization remain release work.

[EXTRACTION_WORKFLOW.md](EXTRACTION_WORKFLOW.md) documents focused commands;
[Tests/quality_control](Tests/quality_control) holds dated review evidence.
Historical reports describe their frozen builds, not every subsequent version.

## Deferred or explicitly out of scope

- General OMR, pitch/rhythm editing, transposition and MusicXML export
- Automatic correctness for arbitrary scans, instrument rosters or page turns
- Automatic inference of every absent instrument's rest duration
- Custom page sizes and export-quality preset UI
- Cloud collaboration, iPad support and App Store distribution

Further work should extend the current Auto-first app, preserving manual repair
and source fidelity. The original manual-only prototype milestone is complete.
