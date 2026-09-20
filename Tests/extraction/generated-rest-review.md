# Generated silence for omitted instruments

`tools/test_generated_rests.sh` exercises the native planner, document transaction,
project codec, layout engine, and PDF exporter. It is separate from optical rest
recognition: a reviewed system assignment supplies the absent instruments and
the verified measure count.

The self-contained source is `sources/mozart-k488-page-17.pdf`. Its adjacent JSON
records the original full-score hash, publisher, original PDF page number, and
lossless-page-copy method. Rendering the copy and original at 1800 × 2546 pixels
produced identical pixels. The original PDF was not modified.

## Independently reviewed musical reference

Mozart K. 488, first movement, source PDF page 17 contains three systems:

| System | Measures | Printed instruments | Generated silence |
| --- | --- | --- | --- |
| 1 | 144–149, six bars | Piano, Violin I, Violin II, Viola, Cello/Bass | Six bars for Flute, Clarinet, Bassoon, Horn |
| 2 | 150–152, three bars | Piano only | Three bars for all eight other parts |
| 3 | 153–156, four bars | All nine parts | None; every printed strip remains |

All 18 physical staves are accounted for. The resulting project contains 27
items: 15 original printed strips and 12 generated rests. Piano grand staves
remain grouped into one musical item per system. Every part retains three
items in source order. This is a page-17 excerpt, not a complete concerto export.

The nine exported excerpt pages were inspected against the source. Playing
entrances, source clefs and keys, ties, slurs, dynamics, and piano runs remain.
Several compact source crops retain neighboring fragments, notably Flute,
Bassoon, Viola, and Violin II. No whiteout cleanup was applied. The generated
silence itself contains no image from another instrument.

## Regression coverage

The 65 workflow checks include:

- A one-bar omitted piano generates one ordinary whole-bar rest, not two bars or
  a multi-bar symbol with a numeral of one.
- Generated metadata, source system index, measure start, and variable-system
  setup survive save/reopen and atomic Apply, Undo, and Redo.
- Crop, whiteout, source-rest restoration, and bar-number OCR cannot reinterpret
  a generated silence as a source image. Count edits use a distinct undoable API.
- Crop copying neither repeats generated silence on another page nor overwrites
  a confirmed silent part at its destination.
- Invalid duration, source-system index, or overflowing measure span blocks
  export; generated/source-replacement conflicts cannot render surrogate music.
- Changing the entire source page from red to blue leaves generated-only output
  pixels identical. A real-crop control produces different pixels, proving that
  this comparison actually observes source imagery.
- Real native analysis and reviewed assignment of the Mozart excerpt produce
  every expected part and silence item with the original PDF bytes unchanged.

Generated rests represent a confirmed duration; they do not infer or reproduce
unreviewed shared tempo, meter, rehearsal, or movement changes. Such changes
still require explicit source review. An independent agent reviewed the model,
document guards, copying, layout, and export paths and found no concrete issue.
