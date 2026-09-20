# Partsmith macOS builds

Use [Partsmith-extraction-preview-macos.zip](Partsmith-extraction-preview-macos.zip) for the current extraction workflow. Unzip it and open the contained `Partsmith.app`. This is an unsigned universal arm64/x86_64 build for macOS 14 or later, not a notarized public release.

This preview adds whole-score offline Auto, saved instrumentation and crop settings, reviewed assignments, mixed staff-size detection, shared source marking support, balanced pagination, output page numbers and one undoable apply. Compact cropping now follows ink, separates tilted system barlines during analysis, assigns lyric hyphens to their vocal staff, and supports validated per-band crop-edge edits during Auto review. Saved fixed-padding setups remain compatible. See [the complete-score evaluation](../../EXTRACTION_WORKFLOW.md) and [all 19 reviewed parts](../../output/pdf/full-score-sets/README.md).

The older `Partsmith.app` and `Partsmith-v0.1.0-alpha.2-macos.zip` in this directory are historical builds and do not include the current extraction changes. The source for rebuilding the preview lives in this repository.

The Trio review update requires a starting profile or confirmed instrument setup for a new project. Choose **Clarinet Trio** for Clarinet, Cello and a two-staff Piano part. In the 35-page Brahms scans, the final blank page and publisher catalogue need separate, explicit **Exclude This Non-Music Page** actions with reasons; zero detected staves never silently excludes a page. Review now shows assigned/excluded/pending page counts and accepts a typed source-page number. **Auto Rectify Page/All** adjusts page geometry; **Auto Extract** finds and assigns parts. Crops and shared directions still require source review before export.

Compact crops also retain small detached marks directly above connected target notation and allow more room above scanned slurs and ascenders. This improves the medium-skewed Trio scan; it does not establish complete automatic ownership of every direction or overlapping mark.
