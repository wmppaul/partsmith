# Commands and reviewable recipe

From the skill directory, with dependencies installed in your chosen Python:

```sh
python scripts/extract.py analyze /path/score.pdf --pages 1-4 --out /path/work/analysis
python scripts/extract.py build /path/recipe.json --out /path/output
python scripts/extract.py verify --out /path/output --review /path/review.json
```

`analyze` writes page PNGs with staff hypotheses and `analysis.json`. Staff indices restart on every page; analysis never assigns parts. Zero candidates is not proof of a tacet or blank page. Small/thin staff lines or locally varying skew can cause missed candidates. Visually verify the count before using suggestions.

## Recipe schema v1

```json
{
  "schemaVersion": 1,
  "source": "../scores/source.pdf",
  "sourceSHA256": "SHA256_OF_EXACT_SOURCE_BYTES",
  "title": "Work title - excerpt, PDF pages 1-2",
  "composer": "Composer",
  "scopePages": [1, 2],
  "parts": [{
    "name": "Violin I",
    "omittedPages": {},
    "bands": [{
      "id": "violin1-p1-s1",
      "page": 1,
      "system": "1 (starts bar 1)",
      "rect": [25, 120, 565, 178],
      "label": "Optional verified editorial label",
      "exclusions": [],
      "pageBreakBefore": false
    }, {
      "id": "violin1-p2-s1",
      "page": 2,
      "system": "1 (starts bar 9)",
      "rect": [25, 30, 565, 88]
    }]
  }],
  "coverageNotes": "List all system starts and account for tacet/omitted systems.",
  "sharedMarkings": "Identify where tempo, rehearsal letters and repeats are retained or supplied."
}
```

Pages are one-based in recipes. Rectangles are `[left, top, right, bottom]` in PDF points measured from the displayed page's top-left corner. The native project converts to top-down fractions and zero-based page indices; its `rightFraction` is a **trim amount**, not the right edge. Build rejects rotated pages or differing CropBox/MediaBox because their mapping into the current native app requires an explicit normalization step.

Bands must be in source reading order. Each page in scope needs at least one band per part or an `omittedPages` entry, e.g. `{"2":"No printed violin staff; verified full-page tacet"}`. This page-level check does not validate individual system coverage: record and inspect that separately. Preserve both staves of keyboard systems in one band. A page with no printed staff at the start of a vocal number still needs its introduction/rest context handled.

`label` is separate from the source engraving. Use it for verified editorial information, not invented notation. Labels and explicit page breaks are also saved in the native project and can be edited in its band inspector. The native layout can still paginate differently because of typography/header sizing. Check any app re-export.

Optional `exclusions` contains rectangles in the same absolute, top-down PDF-point coordinates as `rect`. Every exclusion must be fully inside its band. They paint white over a small neighboring fragment without changing the immutable source. They are also saved in the native project's band geometry. Inspect the source and output at high resolution for every patch; a mask over a target note is data loss, even if the output looks tidy. Keep sufficient surrounding whitespace to avoid antialiasing remnants. Use these only when the undesired ink is spatially separable from target notation.

Band IDs use letters, digits, underscores or hyphens and must be unique across all parts. Non-ASCII header/label text uses an embedded Unicode font; unsupported glyphs stop the build rather than becoming question marks. Build into an empty directory or a prior generated output directory. Each build finishes in a staging directory before publication; the prior generation is retained in a hidden sibling backup. Removed parts are absent from the new generation, and a failed build cannot retain a misleading reviewed manifest alongside modified PDFs.

## Review schema

```json
{
  "reviewer": "Identity or description of independent reviewer",
  "outputSHA256": {"Violin I.pdf": "HASH_FROM_CURRENT_MANIFEST"},
  "reviewedBandIDs": ["violin1-p1-s1", "violin1-p2-s1"],
  "checks": {
    "identity": "pass",
    "coverage": "pass",
    "cropEdges": "pass",
    "globalMarkings": "pass",
    "readability": "pass",
    "pageTurns": "pass"
  },
  "notes": "Actual observed evidence, corrections made, scope and any qualifications."
}
```

Review all output pages at readable resolution, and all crop edges against the source. The verifier requires every current PDF hash and every strip ID. A fresh build resets status to draft. A review record is evidence of an inspection, not automatic music recognition. Do not mark unresolved missing notation as passing merely to produce a final status.
