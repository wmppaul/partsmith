# Partsmith

Partsmith turns a full-score PDF into editable instrument parts on your Mac. Start with **Auto Extract**: choose the music pages, identify the instruments, then let Partsmith find and assign the staves. Refine the results directly in each part's Preview and export a PDF for every instrument.

The app preserves the original engraving or scanned notation. Staff detection, printed-name recognition, deskew and eligible rest compression run locally—no internet connection, Python installation or AI service is needed.

## Download

**[Download Partsmith v0.1.0-alpha.6 for macOS](https://github.com/wmppaul/partsmith/releases/download/v0.1.0-alpha.6/Partsmith-v0.1.0-alpha.6-macos.zip)** · [Release notes](https://github.com/wmppaul/partsmith/releases/tag/v0.1.0-alpha.6)

Requires **macOS 14 or later**; supports Apple Silicon and Intel. Unzip the download and open `Partsmith.app`. This alpha is ad hoc signed, not notarized. If macOS blocks it, open **System Settings → Privacy & Security → Open Anyway** after trying to launch it.

The [in-repository preview ZIP](artifacts/macos/Partsmith-extraction-preview-macos.zip) contains the same reviewed build. See [known limitations](KNOWN_LIMITATIONS.md) before preparing performance parts.

## Getting started with Auto Extract

**[Open the illustrated Getting Started guide](docs/getting-started.md)** for a complete walkthrough with numbered screenshots, from importing a score to exporting every part.

![Choose music pages, straighten scans, and select instrument names](docs/images/getting-started/03-pages-deskew.png)

1. Import the full-score PDF and press the blue **Auto Extract** magic wand.
2. Choose the music pages, **Deskew & Align Pages** if needed, then select instrument names on the score. For an unnamed staff, drag a blank box beside it and type a name.
3. Check instrument order and staff counts, run **Auto**, then **Add Parts** when assignments are valid.
4. Refine each part in **Preview**, tune the shared layout, save the editable project and **Export All**.

For changing instrumentation, omitted-system rests, crop cleanup and other harder cases, use [Advanced workflows](docs/advanced-workflows.md). See the [Brahms quartet recheck](docs/brahms-quartet-review.md) for current Auto results and assisted corrections.

## Refining the result

### Page layout

- **Scale** applies the selected enlargement, including above 1.00×. When the music becomes wider than the available page area, Partsmith warns instead of silently capping it. Check Preview for notation cut off at the physical paper edge.
- **Side Margins** start at **18 pt** in new projects. Reducing them gives the music more page width.
- **System Gap** ranges from **4 to 200 pt** and keeps the requested spacing even with **Balance Page Fill** enabled. Larger gaps can add pages.
- Layout sliders update the Preview in the background after you finish dragging. Layout changes leave the saved source crops unchanged.
- **Use Consistent Scale** preserves relative source sizes and horizontal alignment within a part. **Balance Page Fill** redistributes complete systems; neither chooses musically convenient page turns. Add **Start on New Page** to a selected system when needed.

### Printed headers and instrument names

Auto can copy the printed title and composer into the first page of each part. Check the header preview; use **Adjust on Score** to change it, or turn off **Use Printed Header** to skip it. The Inspector also supports a manual Source Header or typed title and subtitle.

Names remain editable after recognition. Use **Add Names from Score** to extend a list, or **More → Replace List from Score** to start over. Name selection identifies the parts; it does not determine their crop indents.

### Rests and changing instrumentation

**Count and compress full-bar rests automatically** runs after Add Parts. For an existing part, use **Find & Compress Rests**; for one strip, use **Count & Compress This Strip**. Clear, eligible rest strips become counted rests, including piano grand staffs when both hands rest for the same measures. Uncertain notation stays as its original crop. **Restore Original Crop**, Undo and a reviewed manual count remain available. Consecutive confirmed rests join by default, including an opening compressed strip followed by omitted-system rests when its ending is a plain barline. Directions, changed printed context and explicit breaks keep rests separate. For inserted rests or manual replacements without printed source context, uncheck **Join with previous rest** to keep a local boundary.

If silent instruments disappear from the full score, enable **Instrument layout changes between systems** before running Auto. In **Assign Instruments**, use Fit Width or zoom and drag across the staves of one complete system; the selection highlights as you drag. Click to adjust the selection, or Shift-click/Shift-drag to add staves. Check the instruments actually printed and their staff counts. **Page N · System N** identifies the system within its source page.

**Bars in system** suggests a count from clear shared barlines when possible. Check or edit it, especially at pickups or split measures, then choose **Assign System**. A single selected staff or unclear connections between staves need a manual count. Confirmed absent instruments receive that many bars of rest; a piano grand staff counts measures once. Revisiting an assigned system restores its instruments, first bar and count; **Load** also restores them. New suggestions leave entered and assigned counts intact.

Use **Find Similar Systems** to suggest layouts from reviewed examples. Check the suggested identities; a matching staff count alone is not enough. Verify each affected system's own rest duration. See the [detailed extraction workflow](EXTRACTION_WORKFLOW.md).

### Shared musical markings

Auto offers detection and copying of some shared headings, tempos, repeat directions and endings. This is still incomplete: compare the score for rehearsal letters, meter changes and other directions that each player needs. Source-marking copies and editorial labels remain editable. Crops can include neighboring notation when that is necessary to preserve the intended part.

## A parallel ChatGPT/Codex workflow

The [score-part-extraction skill](skills/score-part-extraction/SKILL.md) produces faithful cropped PDF parts and editable `.partsmithproject` bundles with visual source/output review. It can assist with difficult assignments, crop corrections and source directions. The macOS app runs independently and entirely offline.

The skill's protected-region checks are not enforced by the native editor. Its exporter and the app can paginate differently, so review native re-exports. [Reviewed examples](output/pdf) and the [evaluation index](Tests/quality_control/README.md) distinguish automatic proposals from assisted corrections and remaining issues.

## Run from source

Open [Partsmith.xcodeproj](Partsmith.xcodeproj) in Xcode, build the **Partsmith** scheme and import a PDF. Alternatively:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Partsmith.xcodeproj -scheme Partsmith -configuration Debug \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

A [sample project](Partsmith/Resources/Fixtures/SampleProject.partsmithproject) and [sample score](Partsmith/Resources/Fixtures/SampleScoreFixture.pdf) are included for exploring the UI. The historic sample crops are not a musical correctness reference. Focused verification commands are listed in [EXTRACTION_WORKFLOW.md](EXTRACTION_WORKFLOW.md).

## Project and release files

A `.partsmithproject` package contains `project.json` for settings, crops and assignments, plus the embedded original `source.pdf`. Deskew and editing are stored separately from the original source.

- [App](Partsmith/App/PartsmithApp.swift), [document model](Partsmith/Core/DocumentModel/PartsmithDocument.swift), [layout](Partsmith/Core/Layout/PartLayoutEngine.swift), [PDF export](Partsmith/Core/Export/PartPDFExporter.swift)
- [Product specification](score-part-extractor-spec.md) and [implementation guide](codex-implementation-brief.md)
- [Release publishing](docs/RELEASING.md) and [current build review](artifacts/macos/README.md)
