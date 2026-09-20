# Automatically counted multi-bar rests

These are complete Brahms Clarinet Trio parts produced by Partsmith's native automatic rest counter and PDF exporter from the existing reviewed medium-skewed project. No rest counts were entered manually.

| Part | Complete output | Automatic replacement |
| --- | ---: | --- |
| Clarinet in A | 12 pages | Bars 42–47 become a six-bar rest on output page 1 |
| Cello | 12 pages | Bars 76–82 become a seven-bar rest on output page 2 |
| Piano | 24 pages | Original notation retained throughout |

The files and editable project are in `trio/`. Open the project with the current [Partsmith preview](../../../artifacts/macos/Partsmith-extraction-preview-macos.zip). Its original source crops remain recoverable with **Restore Original Crop**. Older builds do not understand the retained opening/ending context of automatic replacements.

All 393 source strips remain in order. The complete 35-page source is embedded unchanged; the reviewed non-music pages 34–35 stay excluded. Printed clefs, keys, opening bar numbers and ending barlines are retained. The clarinet entrance in bar 51 and cello entrance in bar 83 remain intact. The project differs from the reviewed input only in the two rest replacements and its modification timestamp.

An independent review inspected every output page and enlarged source comparisons for both replacements. All 46 unaffected page drawing streams match the reviewed baseline, including pixel-identical Piano pages. Source hashes, detector results and output review evidence accompany the files. Existing neighboring fragments and the study score's staff size remain as documented in the [original reviewed set](../brahms-trio-medium/README.md); rest counting does not clean or re-engrave those crops.

The automatic detector was also tested on the full 43-page Magic Flute score: all 77 proposed runs (384 bars) were independently counted from the source. The full Schumann project retained its notation: its broad rest crops include neighboring ink. A separately reviewed tighter Schumann strip correctly counts eight, while the following strip with a fermata stays unchanged. These tests establish the documented examples, not universal recognition of arbitrary scores.
