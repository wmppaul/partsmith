# Partsmith macOS builds

Use [Partsmith-extraction-preview-macos.zip](Partsmith-extraction-preview-macos.zip) for the current extraction workflow. Unzip it and open the contained `Partsmith.app`. This is an unsigned universal arm64/x86_64 build for macOS 14 or later, not a notarized public release.

This preview adds whole-score offline Auto, saved instrumentation and crop settings, reviewed assignments, mixed staff-size detection, shared source marking support, balanced pagination, output page numbers and one undoable apply. Compact cropping now follows ink, separates tilted system barlines during analysis, assigns lyric hyphens to their vocal staff, and supports validated per-band crop-edge edits during Auto review. Saved fixed-padding setups remain compatible. See [the complete-score evaluation](../../EXTRACTION_WORKFLOW.md) and [all 19 reviewed parts](../../output/pdf/full-score-sets/README.md).

The older `Partsmith.app` and `Partsmith-v0.1.0-alpha.2-macos.zip` in this directory are historical builds and do not include the current extraction changes. The source for rebuilding the preview lives in this repository.

The magic wand is the recommended first action after importing a score. **Auto Extract** opens a movable, resizable window. Start with optional **Deskew & Align Pages**, then choose a preset, type names, or use **Pick Names from Score** to click the printed labels. Recognition runs locally and suggests two staves for piano-like instruments. Existing page corrections are preserved; deskew is offered before bands or a source header have been selected.

Choose **Auto** and then **Add Parts**. Neither step requires an “I reviewed” checkbox. Blank and catalogue pages have one-click **Exclude This Page** and **Restore Page** actions; no typed reason is needed. Changed or missing staff assignments remain visible, and unresolved assignments still need correction before adding. Crop changes remain editable and applying parts is one undoable edit.

The September 20 workflow update passed 55 instrument-name checks, 28 deskew/cancellation checks, and 64 existing whole-score document checks. A live test on the 35-page Brahms Trio completed deskew, name picking, automatic extraction, two one-click exclusions, and addition of three parts with 131 bands each. This verifies interaction and assignment completeness; it does not replace the separate musical crop review.

Compact crops also retain small detached marks directly above connected target notation and allow more room above scanned slurs and ascenders. This improves the medium-skewed Trio scan; it does not establish complete automatic ownership of every direction or overlapping mark.
