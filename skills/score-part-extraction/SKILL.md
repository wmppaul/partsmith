---
name: score-part-extraction
description: Extract instrument or vocal parts from full-score PDFs as faithful cropped PDF strips, with editable Partsmith projects and visual quality review. Use for creating parts from digital or scanned scores, not for note transcription, transposition, MusicXML, or re-engraving.
---

# Score part extraction

Run this as a complete workflow in ChatGPT/Codex. The Partsmith macOS app is an optional local editor, not a dependency. Preserve the source engraving and source PDF. Never claim that staff detection establishes instrument identity or musical completeness.

## Inspect and map

1. Identify requested parts and scope. Inspect the opening page and every layout change. Count printed staves and systems; read labels, braces and clefs. A brace can join two instruments, a large gap can separate orchestral groups within one system, and an absent staff can represent rests rather than a missing page. Keep grand staffs together.
2. Run `scripts/extract.py analyze SOURCE --out WORK/analysis [--pages 1-4]`. Dependencies: Python 3.10+, PyMuPDF, NumPy and Pillow. Use an isolated environment or available bundled runtime. Exact commands and recipe schema are in [references/recipe.md](references/recipe.md).
3. Inspect all numbered analysis images. Detection proposes five-line staffs, not instruments. Establish a page/system/part map from the score itself. Verify counts visually; if a staff is missed or invented, correct the map manually. Never repeat an assignment modulo a fixed count across changing layouts.

## Select and build

Write a JSON recipe using top-down PDF points. See [references/recipe.md](references/recipe.md). Include SHA256 of the input, scope pages, source system identifiers and unique strip IDs. Use suggested rectangles as starting points; adjust them against the rendered score, not just staff-line bounds.

- Keep clefs, signatures, ledger notes, beams, slurs, articulations, dynamics, lyrics and continuations. Boundaries between staffs are not necessarily halfway. Examine notation above and below each staff. Remove neighboring music without cutting the selected part.
- Inventory shared tempo changes, rehearsal marks, repeats/endings, measure numbers, directions, cues, and long rests. Copy a required shared marking only from a verified source or add a clearly identified editorial label. Do not invent tacet durations. If geometry cannot separate overlapping notation, retain context or flag an unresolved passage rather than silently deleting it.
- If adjacent notation intrudes only in a small horizontal area, use a precisely reviewed `exclusions` rectangle inside the crop to cover that intrusion with white. Compare every patch against the source at high resolution; masks must never erase target notes, clefs, slurs or directions. If the inks actually overlap, a whiteout cannot separate them: retain context or leave the passage unresolved.
- On scans the analysis rotation is only a detection aid. Recipe rectangles remain in the original page coordinates, and export retains the original scan angle. Inspect tilted line ends. For substantial skew/perspective, normalize a separate high-resolution derivative first and record its relation to the immutable original; do not reuse coordinates from a different image space.
- Explicitly label excerpts. Account for every source page in scope and every system for the requested part, including omitted/tacet systems. A successful script does not prove complete coverage.

Run `scripts/extract.py build RECIPE --out OUTPUT`. It creates vector-preserving part PDFs, a source-embedded `.partsmithproject`, output PNGs, source-crop PNGs and a provenance manifest. The project preserves editable crops, exclusions, editorial strip labels and explicit page breaks. Do not promise identical typography or pagination between the two exporters. Builds are staged: a failure leaves the previous generation intact; a successful replacement moves it to a hidden sibling backup whose path is returned.

## Review and iterate

Inspect every final output page, comparing against the source in reading order. Use a second agent for independent review when available; give it the raw source, recipe, outputs and the task, without the expected verdict. A short complete score is a stronger test than cherry-picked strips from a long score. At least one case should exercise a different layout, such as a grand staff or scan.

Review separately:

- **Identity and coverage:** correct instrument, all systems and bars in order, no unexplained gaps/duplicates, explicit excerpt/tacet handling.
- **Crop edges and musical context:** all target notation retained; no adjacent notes, lyrics or partial staff lines; shared markings accounted for.
- **Readability and layout:** readable staff size, correct aspect ratio, no title or page-boundary clipping, sensible page turns. Cropping cannot repair an unreadable source or engrave a multimeasure rest.

Revise the recipe, rebuild, and inspect the changed output and its page-break consequences. Output hashes change on rebuild. Record actual review observations and exact output hashes using the schema in the reference; then run `verify`. This validates that the review refers to these outputs, not that the judgments are musically correct. Do not fill passing checks without inspecting the evidence. Leave failures as draft with explicit unresolved issues.

Deliver the reviewed PDFs, editable project and concise review results, including tested scope and material limitations. The macOS app can open the project via File > Open, adjust crops and export locally without ChatGPT or an internet connection.
