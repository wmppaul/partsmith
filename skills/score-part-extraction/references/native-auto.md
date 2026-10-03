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

Choose the preset explicitly for a new setup. A four-staff system is ambiguous:
a string quartet is four one-staff parts, while a clarinet trio is Clarinet,
Cello, and two-staff Piano. A correct staff count cannot distinguish them. The
Inspector's **Auto Rectify Page/All** controls page alignment; **Auto Extract**
in the toolbar creates parts.

New setups use **Compact — follow notation** in **Crop Context**. The analyzer
measures connected ink beyond the staff and preserves a small safety margin.
Enable **Lyrics** for vocal staves; figured bass and additional verses may need
extra lower padding. Padding overrides are minimum context, in staff spaces,
not maximum crop extents. Existing saved setups retain their original fixed
padding until Compact is selected. Review uncertain touching notation: ink
connected to multiple staves is retained with a warning. Detached markings that
touch a neighboring staff can require a local expansion; a warning alone does
not establish preservation.
Per-instrument overrides are available. Start with zero left/right
trimming, especially on scans with alternating margins. Check every final
barline and printed measure number before removing horizontal margins.

Run **Auto** and review every source page. The detector uses skew-aware evidence
from several horizontal regions, including the left edge, and allows different
staff sizes on the same page. Detection does not rotate or clean the exported
source. Exact staff counts alone are insufficient: check the actual five-line
positions and spacing, and compare all systems against the raw source.

Changed instrumentation must be reviewed explicitly. The page correction panel
can assign detected staves, record a missing/tacet part, exclude a non-music page,
and add a verified movement/song heading and page break. A piano
introduction with no printed voice should be represented by a clearly labeled
cue or a verified rest instruction, never an unexplained missing opening.
The app skips readable zero-staff pages without requiring a typed reason or
acknowledgement. Use **View Skipped Pages** for source review and **Restore Page**
when music was missed. A page with undetected music must stay included; a failed
raster is an error, not evidence of a blank page.

Use **Adjust crop edges on this page** for a source-reviewed local correction.
Top and Bottom are source-page points measured downward; select the part/system
button to highlight its rectangle. **Restore Automatic Edges** removes that
correction. The editor keeps assigned staff lines inside the crop, but cannot
recognize every detached note or marking. Inspect outside both edges before
accepting the review. Count and disclose these corrections separately from Auto.

Adding the reviewed parts is one undoable transaction. Stale source/rectification
results and duplicate populated parts are rejected. Inspect Preview and export
all parts. Balanced pagination minimizes pages by choosing the widest viable gap
down to four points; it preserves notation scale and crop geometry. Reserve
explicit breaks for musical sections, not source-page boundaries.

For a difficult turn, use the Inspector's **Start on New Page** on a reviewed
system and compare both pages plus the rest of that part's changed pagination.
Keep rapid passages and first/second endings together where practical. Verify
rests in that instrument's source staff; a repeat barline or a fermata printed
only above another part does not establish a rest. Compare the added page count
with the compact version, and keep a separate editable alternative when the
tradeoff is useful. Reopen and reexport the saved project to verify the breaks,
source crops, copied directions and notation scale persist. This is a manual
musical review; the layout engine does not infer safe page turns.

In Preview, **Scale** above 1.00 uses verified blank horizontal source margins
to enlarge notation without changing saved crop bands. Scale at or below 1.00
keeps its previous geometry. The widest retained strip limits **Use Consistent
Scale**; the Inspector reports that limit. Reduce per-part **Side Margins** for
more output width. Analysis retains scan speckles, neighboring ink, copied
markings and rest context, so a noisy or wide strip may prevent further
enlargement. Do not erase notation to defeat this limit. Preview and native PDF
export use the same layout; inspect enlarged output against the original source.

## Shared markings and review

Shared rehearsal letters, tempos, endings and return instructions can be printed
only on the top staff. Read the full score, inventory those directions, and copy
verified source rectangles or add a faithful editorial direction to the relevant
parts. Native source-marking rectangles keep their source horizontal positions
in separate rows above or below the target crop. Keep an end-of-system return
instruction below that same system; moving it above the following system can
change its meaning. The batch reviewed plan can create these
rectangles; the app can retain and remove them, and can edit editorial labels.
Automatic staff assignment does not automatically understand shared directions.
Treat a stacked movement name, tempo and metronome indication as one musical
instruction. Keep every line, including the beat symbol, augmentation dots and
number; overlapping horizontal positions do not justify dropping a line.
Before adding a copied marking, check whether the recipient already retains a
complete equivalent marking above its own staff at the same musical position.
Matching tempo words alone do not replace an additional metronome indication.
Equal numerals or words elsewhere are not sufficient. In particular, a neighboring
instrument's ending below the target staff cannot replace the target's ending.
Check both members of a first/second-ending pair, including across systems or
pages. After tightening a crop, check again that its required local marking is
still present; restore a verified source copy when it is no longer retained.
After changing staff assignments, recheck the source system and recipients of
shared markings. Verify that saving and reopening the corrected setup retains
required copies and respects explicitly removed copies.
Check both a return instruction and its destination symbol, plus any first/second
endings. Copying the sentence alone does not make the repeat complete.

The Mac magic-wand setup has an optional **Copy detected tempos, repeats and
paired endings (experimental)** setting for consistent instrument layouts. It
runs native heading, navigation, linked-symbol and paired-ending recognition in
the background after staff detection. In Auto review, dashed purple boxes identify source copies;
select a listed direction to highlight its source, or **Remove Copy** for that
recipient. A matched repeat symbol links to its printed reference; a paired
ending offers links to both original brackets, including across source pages. Scan
notes are informational and do not block **Add Parts**. Recognition failures
retain valid music crops and identify the failed pass; they are not evidence
that a score has no directions. Assignment changes discard stale automatic
copies while retaining manual source rectangles. Changing the assignment of
either ending invalidates both halves of that pair without removing unrelated
directions. Run Auto again to recognize directions for the revised setup.
Ending recognition currently requires a supported first/second pair; unpaired,
third/list endings, rehearsal letters and bar numbers still need separate source
review. Missing or unresolved pages prevent pairing across the gap. A staffless
page is not assumed to be blank for this purpose. This option is off by default.

Review all output pages against the source. Retained neighboring notes are
permitted under `preserve-target` when target ink needs the same space. Unnecessary
neighboring staff lines or complete lyric rows are crop-quality defects even
when every target note survives. Compare context before and after changes, and
ensure the intended staff remains identifiable. Fix a systematic edge failure by improving detection or a
saved profile before introducing per-band geometry corrections. Never reduce a
crop to make a page fit, or shrink a protected region merely to pass a test.
On scans, inspect detached high slur crowns, fermatas and text ascenders, not
just noteheads and stems. A crop can preserve the notes while clipping those
marks by only one or two points. Verify the exact source file hash: separately
skewed versions of the same edition need fresh source-coordinate guards.

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
An override's supplied `sourceMarkings` list is authoritative, including `[]`
when copies have been removed. Omit it (or use `null`) to retain automatic
navigation propagation. Crop-edge resets and unrelated edits must not restore
a removed copy; the original source owner's crop is a separate decision.

The review utility renders every output page, checks coverage against independent
source counts, and compares protected target regions and copied directions with
the immutable original source. Scanned-source checks first use the full original
page. When a bitonal image's resampling phase depends on the visible crop extent,
a second independent reference uses that same reviewed extent; the raw untrimmed
differences remain recorded and protected-region containment is still required.
When native PDF matrix serialization also changes raster sampling phase, a
standalone CoreGraphics reference draws the original source at the reviewed
placement. It never uses exported music as reference content.
Vector sources use
an independently serialized full-source CoreGraphics reference to account for
export path/glyph rounding, while retaining raw direct-render differences. Shared
cues use their independently reviewed fragment extent. No broad pixel-similarity
tolerance is used. Pixel agreement establishes export fidelity only
within those reviewed regions. It does not identify an instrument, discover
unrecorded notes, or replace a visual review. Keep output/source hashes and
independent review findings with each delivered set.

When changing crop analysis, test musical ownership separately from staff-line
continuity. Include curved and interrupted lines, ledger patterns, long stems
ending near an outer staff line, and detached marks near the following staff.
Keeping every previous component is insufficient: a new competing component can
change attribution and make an old mark disappear. An uncertain interpretation
should only expand the final crop, leaving ordinary ownership and detached-mark
discovery intact. Preserve failing source guards and inspect their exact excluded
ink rather than relaxing them to match the candidate.

Compare every source page, including unresolved instrument layouts. Ignore only
component ordering; ownership, bounds and alternative-evidence tags are semantic
changes. Review original source context before proposed rectangles. Diagnostic
single-staff crops can check preservation on an unresolved page, but do not
establish instrument identities or permission to invent missing rests. Finish
with the actual document Auto worker, complete exports, and a saved-project
reopen; raw inventory results alone do not validate directions or pagination.

For detector changes or a requested whole-corpus evaluation, freeze the native
analyzer and exporter before starting the resumable corpus runner. Supply
`--exporter` to generate all parts of every completely resolved plan, rather than
stopping at staff counts. See `Tests/quality_control/README.md` in the checkout.
The runner checks every physical source page, part/band order, PDF hashes and
the editable project's source and crop boundaries. Unresolved profiles remain
unfinished inputs in its aggregate. Its raw-page diagnostic exports do not
exercise name picking, printed-header selection, optional deskew or automatic
rest compression. Run those separately when evaluating those app settings.
Keep raw and corrected coordinates separate, and reuse recorded corrections
without estimating a different correction for the comparison. A live worker
or temporary observation timeout is not a reason to restart extraction.

When comparing detector revisions, distinguish ink-component array reordering
from changes in component geometry. An unresolved page that emits no bands can
hide a changed crop until the user assigns its staves. Review changed components
on those pages against the original source too. Temporary one-part-per-observed-
staff plans can expose crop changes without claiming instrument identities;
they are diagnostic fixtures, not deliverable parts. Follow the surviving ink
connections before changing a crop rule: an interior barline can still join two
staves after the right system edge has been separated successfully.

The repository also has experimental `headings` and `navigation` CLI passes.
They add source-image markings to a copy of an inventory before export. The
app's optional direction-copying workflow invokes the same native recognizers
and then pairs supported endings across the selected score pages. The
navigation pass can match a limited class of destination symbols against an
actual printed glyph in its recognized instruction. It does not infer every
repeat, ending or rehearsal mark. Keep a source-derived inventory of expected
directions, check all output copies for complete glyphs and correct system
ownership, and record omissions. Avoid duplicating a heading already visible in
the target crop. Font/OCR boxes alone may omit serifs, dots or parentheses;
inspect the original pixels beyond the proposed bounds.
Suppress a copied heading only when its complete source ink remains visible
at the correct musical position. Identical wording later in a system is not
necessarily the same instruction. A neighboring instrument's heading below
the intended staff is not a substitute for its properly placed heading above.
Keep duplication unresolved if removing it would leave only that neighbor text.


## Automatic multi-bar rests

The magic-wand setup offers **Count and compress full-bar rests automatically**,
enabled by default. After **Add Parts**, a separate background operation counts
eligible rest-only strips and applies all replacements in one Undo. Existing
parts expose **Find & Compress Rests**; the selected-band inspector exposes
**Count & Compress This Strip**. No count entry is required. **Set Count Manually**
is an optional fallback after a source review.

For a saved native project, the same document worker and PDF exporter are
available through:

```sh
bash tools/compress_score_rests.sh --project WORK/Score.partsmithproject \
  --out WORK/automatic-rests
```

Use a new output directory. This saves every part PDF, an editable project and
`automatic-rest-report.json` recording source hash, replaced band identities,
original rectangles, counts and retained source context. It never changes the
input project. Compare every replacement with the complete original score;
review also needs to account for shared directions outside the target staff.

The recognizer is deliberately narrow: one complete five-line staff, clear bar
boundaries and hanging whole-measure rests. It preserves opening source context
and the ending barline, and leaves unknown ink or ambiguous notation unchanged.
Grand staffs, mixed playing/resting strips, interior meter/tempo changes,
fermatas, repeats and copied shared markings within the compressed span are not
automatically compressed. Copied opening markings entirely before the retained
prefix boundary remain eligible.
Broad neighboring context can prevent an otherwise silent strip from matching.
Automatic replacements do not join across strips, because their individual
opening and ending context must remain. Original crops remain available through
**Restore Original Crop** and Undo. Recheck output layout after any replacement.

## Scores with omitted silent staves

Enable **Instrument layout changes between systems** in the magic-wand setup.
This disables automatic instrument cadence guesses even when a page's total
staff count happens to be divisible by the complete profile. Auto still detects
staff geometry. In **Assign Instruments**, use **Fit Width** and zoom; click the
first staff and Shift-click the last staff of one printed system. Check the
printed instruments in profile order, enter an optional first bar and the
system's bar count, then **Assign System**. Piano uses two staves but counts each
measure once. Instrument choices persist for the next system; counts do not.
Use **Load** to revisit an assignment.

Entered starting bar numbers are retained on printed music as well as inserted
rests, including after crop review, Add Parts, saving and PDF export. Exported
music numbers use the page margin; narrow margins or very short crops reserve a
separate row so a number cannot cover notation. Leaving the starting bar blank
does not infer a number.

An unassigned staff is not evidence of silence. Only explicitly unchecked,
confirmed silent instruments receive generated rests. Their counts are required
before adding the reviewed parts, because dropping an absent system would
silently shorten the part. Page exclusions retain their separate non-music
meaning. A system that loses staves to another assignment requires reassignment.
Legacy omissions without counts are unresolved when replanned, rather than
silently discarded.

Generated rests use separate saved metadata (`generatedRest`), with count,
optional first bar and source-system reference. Their source rectangle is only
an ordering/inspection anchor; never treat it as a crop of that instrument.
There is no Restore Original Crop action for an instrument that was not printed.
The Inspector permits changing the inserted rest count; saving, Undo and native
PDF export preserve its distinction from a detected rest replacement. Counts
of one render as a whole-measure rest. No automatic joining across source
systems is assumed.

Verify measure coverage and all shared changes. Split rests at tempo/meter/key
changes, rehearsal marks, repeats and other significant events; do not assume
that absence of a staff makes those events irrelevant. The assignment workflow
does not yet infer omitted instruments or their measure counts from the score.
Mozart K.488 movement I page 17 is a regression case: bars 144–149 show piano and
strings, 150–152 show piano only, and 153–156 show the full ensemble. The silent
strings need three bars in the middle, and winds need both the six-bar and
three-bar silent systems. The source only prints instrument labels on its
opening system, so later identities cannot be recovered by label OCR alone.
