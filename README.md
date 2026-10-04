# Partsmith

Partsmith turns a full-score PDF into editable instrument parts on your Mac. Start with **Auto Extract**: choose the music pages, identify the instruments, then let Partsmith find and assign the staves. Refine the results directly in each part's Preview and export a PDF for every instrument.

The app preserves the original engraving or scanned notation. Staff detection, printed-name recognition, deskew and eligible rest compression run locally—no internet connection, Python installation or AI service is needed.

## Download

**[Download Partsmith v0.1.0-alpha.4 for macOS](https://github.com/wmppaul/partsmith/releases/download/v0.1.0-alpha.4/Partsmith-v0.1.0-alpha.4-macos.zip)** · [Release notes](https://github.com/wmppaul/partsmith/releases/tag/v0.1.0-alpha.4)

Requires **macOS 14 or later**; supports Apple Silicon and Intel. Unzip the download and open `Partsmith.app`. This alpha is ad hoc signed, not notarized. If macOS blocks it, open **System Settings → Privacy & Security → Open Anyway** after trying to launch it.

The [in-repository preview ZIP](artifacts/macos/Partsmith-extraction-preview-macos.zip) contains the same reviewed build. See [known limitations](KNOWN_LIMITATIONS.md) before preparing performance parts.

## Getting started with Auto Extract

1. **Import your score.** Create a new project and drag a full-score PDF into the center pane, or choose **Import PDF**.
2. **Click the Auto Extract magic wand.** Its window moves and resizes, so you can keep the score visible.
3. **Choose the music pages.** Use **All Pages**, or switch to **Selected Pages** and click the thumbnails or enter a range such as `2-8, 12`. Leave out cover material and contents pages. For a tilted scan, choose **Deskew & Align Pages** before selecting instrument names. Deskew and Auto use the same page selection.
4. **Select the instrument names.** Click **Select Instrument Names on Score**, then click the printed names in one complete system from top to bottom. With Selected Pages, Partsmith opens the first included page. Recognized names stay highlighted. Drag a box around a label if a click misses a number or word; adjust its green corners to reread it. Choose **Done — Back to Auto Extract** in the bar on the score to return to setup. You can instead choose **Use a Starting Profile** or type names with **Add Instrument**.
5. **Check the setup.** Verify instrument order and staff counts: a piano grand staff is **2 staves**, while each violin is normally **1 staff**. Enable **Lyrics** for vocal parts. Separate printed labels produce separate parts even when their names match. Leave automatic printed-header detection and full-bar rest compression enabled if you want those features.
6. **Run Auto, then Add Parts.** Check the proposed assignments and crops; the window offers a larger **Assign Instruments** view for corrections. Pages with no detected staves are skipped automatically, and **View Skipped Pages** is optional. If music was missed, restore that page and correct it. **Add Parts** accepts valid assignments without an acknowledgement checkbox. Unresolved staff assignments or missing counts for omitted instruments still need correction.
7. **Refine the parts in Preview.** Select a part in the sidebar and switch to **Preview**. Click a system, then drag its blue top or bottom handle to trim extra neighboring music. Release to apply, or press Escape to cancel. The change also appears in Source and the exported PDF; Undo restores it. Check the intended notes, lyrics, ledger lines and directions after trimming.
8. **Set the layout and export.** Adjust **Scale**, **System Gap** and **Side Margins** in **Score Layout**; they stay synchronized across parts. Use **Customize This Part** for an exception, or **Use These Settings for All Parts** to share a tuned layout. Save the project, then use **Export PDF** for the selected Preview or **Export All** in Source mode for one PDF per part.

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

**Count and compress full-bar rests automatically** runs after Add Parts. For an existing part, use **Find & Compress Rests**; for one strip, use **Count & Compress This Strip**. Clear, eligible single-staff rest strips become counted rests. Uncertain notation stays as its original crop. **Restore Original Crop**, Undo and a reviewed manual count remain available.

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
