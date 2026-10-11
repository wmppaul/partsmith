# Getting Started screenshot sources

These captures come from the actual universal Alpha 6 release app, not mockups. The guide follows a fresh import of the scanned Brahms Quartet IMSLP09200, deskew, four name selections, Auto, Add Parts, Preview, project Save and Export All. All four PDFs were generated through the app. The separate Brahms quality-control evidence evaluates musical completeness; these screenshots are instructions, not a performance-ready example.

`raw/` retains the native app screenshots. `callouts.json` records crop rectangles and arrow coordinates in source screenshot pixels. The renderer crops and resizes those pixels, adds vector numbered arrows and explanatory captions, and writes the PNG files used by the guides. It does not redraw, erase or fabricate app controls. SVG files retain the editable callout layout and reference the corresponding raw PNG.

To regenerate with Node and `sharp` available:

```sh
node tools/render_getting_started.cjs
```

The assignment screenshot uses the same fixed quartet to show the larger system-selection controls. It is not a changing-instrumentation result. Screenshot framing excludes unrelated desktop windows and file dialogs.
