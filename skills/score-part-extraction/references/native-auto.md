# Native whole-score Auto on macOS

Partsmith can run this path without Python, a network connection, or an AI service.
It shares the analyzer, assignment planner, document transaction and PDF exporter
with the repository's batch evaluation tools. The portable Python workflow in
this skill remains available when Partsmith/macOS is unavailable.

## Initialize once, then analyze the whole source

Import the complete PDF and choose **Auto Extract**. Enter the printed instrument
order and the number of staves per instrument (two for a piano grand staff).
Read the labels and braces yourself; these names are a reviewed setup, not OCR
recognition. Partsmith saves the setup with the project. Computer use may perform
this initialization when the user authorizes the extraction.

Open **Crop Context — Padding and Source Margins** when additional context is
needed. Padding is in staff spaces above/below the outer staff lines. The default
is seven spaces on each side; dense overlapping notation and figured bass can
need more. Per-instrument overrides are available. Start with zero left/right
trimming, especially on scans with alternating margins. Check every final
barline and printed measure number before removing horizontal margins.

Run **Auto** and review every source page. The detector uses skew-aware evidence
from several horizontal regions, including the left edge, and allows different
staff sizes on the same page. Detection does not rotate or clean the exported
source. Exact staff counts alone are insufficient: check the actual five-line
positions and spacing, and compare all systems against the raw source.

Changed instrumentation must be reviewed explicitly. The page correction panel
can assign detected staves, record a missing/tacet part, exclude a non-music page
with a reason, and add a verified movement/song heading and page break. A piano
introduction with no printed voice should be represented by a clearly labeled
cue or a verified rest instruction, never an unexplained missing opening.

Adding the reviewed parts is one undoable transaction. Stale source/rectification
results and duplicate populated parts are rejected. Inspect Preview and export
all parts. Balanced pagination minimizes pages by choosing the widest viable gap
down to four points; it preserves notation scale and crop geometry. Reserve
explicit breaks for musical sections, not source-page boundaries.

## Shared markings and review

Shared rehearsal letters, tempos, endings and return instructions can be printed
only on the top staff. Read the full score, inventory those directions, and copy
verified source rectangles or add a faithful editorial direction to the relevant
parts. Native source-marking rectangles keep their source horizontal positions
in a separate row above the target crop. The batch reviewed plan can create these
rectangles; the app can retain and remove them, and can edit editorial labels.
Automatic staff assignment does not automatically understand shared directions.

Review all output pages against the source. Retained neighboring notes are
permitted under `preserve-target`, but report them and ensure the intended staff
remains identifiable. Fix a systematic edge failure by improving detection or a
saved profile before introducing per-band geometry corrections. Never reduce a
crop to make a page fit, or shrink a protected region merely to pass a test.

## Reproducible repository evaluation

In a Partsmith checkout with Xcode installed:

```sh
bash tools/score_extraction_batch.sh inventory --source SCORE.pdf --out WORK/inventory
bash tools/export_score_plan.sh --inventory WORK/inventory/inventory.json \
  --profile PROFILE.json --overrides REVIEWED_OVERRIDES.json \
  --title 'Work title' --composer 'Composer' --out WORK/parts
python tools/review_score_output.py WORK/parts --map REVIEWED_SOURCE_MAP.json --pixels
```

The overrides are optional. They describe reviewed layout changes, section
boundaries and shared source markings; any explicit crop rectangles must be
disclosed separately from automatically generated geometry. The export runner
uses the same `addScoreParts` transaction as the app, preserves an immutable
source in an editable project, and records every source-to-output placement.

The review utility renders every output page, checks coverage against independent
source counts, and compares protected target regions and copied directions with
unclipped source renderings. Scanned-source checks compare directly against the original; vector sources use
an independently serialized full-source CoreGraphics reference to account for
export path/glyph rounding, while retaining raw direct-render differences. Shared
cues use their independently reviewed fragment extent. No broad pixel-similarity
tolerance is used. Pixel agreement establishes export fidelity only
within those reviewed regions. It does not identify an instrument, discover
unrecorded notes, or replace a visual review. Keep output/source hashes and
independent review findings with each delivered set.
