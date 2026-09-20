# Part extraction: complete-score native workflow

The current deliverable is **19 complete parts from five complete scores**, generated through Partsmith's native whole-score Auto planner, document transaction, layout engine and PDF exporter. The reusable [score-part-extraction skill](skills/score-part-extraction/SKILL.md) now documents this offline path alongside the portable Python workflow. [All outputs and editable projects](output/pdf/full-score-sets/README.md); [download the complete set](artifacts/Partsmith-complete-score-parts.zip).

The original project was checkpointed at `6b422ea`; the earlier reviewed extraction workflow was checkpointed at `3aa78d1` before this complete-score iteration.

| Complete source | Parts | Output pages by part |
|---|---:|---|
| Mozart, Ave verum corpus | 8 | One page each: SATB, two violins, viola, and the printed combined Basso ed Organo staff |
| Mozart, Notte e giorno | 2 | Voice 3; Piano 4 |
| Brahms, String Quartet No. 3, Op. 67 | 4 | Violin I 18; Violin II 19; Viola 19; Cello 19 |
| Schumann, Frauenliebe und Leben, all eight songs | 2 | Voice 13; Piano 17 |
| Brahms, Clarinet Trio, Op. 114, all four movements | 3 | Clarinet in A 16; Cello 16; Piano 32 |

There are 184 output pages and 1,131 part bands. All 84 input PDF pages were analyzed; the Trio's blank page and publisher catalog were explicitly reviewed and excluded. The native detector finds all **1,357 physical music staves** in this corpus with **zero manual staff-position corrections**. These are corpus results, not a claim of arbitrary-score reliability.

## What Auto does, and what is initialized manually

The user or assistant enters instrument names, printed order and staff counts once. The app saves that setup and automatically analyzes every source page, proposes systems/parts and crops, presents a review, and adds all approved parts in one undoable transaction. Manual instrument naming is intentional; no OCR or remote model is required. Per-instrument crop padding is adjustable in the app.

All 1,131 final crop rectangles come from native detected geometry and saved padding/margin profiles. There are no hand-drawn geometry overrides or cleanup masks in these full outputs. Reviewed metadata handles Notte's two piano-only introduction systems (clearly labeled cues in the voice part), movement/song boundaries, and shared printed directions. Shared tempo/rehearsal/return glyphs are copied from verified source rectangles; automatically understanding those markings is still outside Auto's capability. The app retains/removes such fragments; their creation in this evaluation uses the reviewed batch plan.

The actual Auto interface was exercised through computer use on complete Ave: eight instruments initialized, organ lower padding changed from seven to nine spaces, setup saved/reopened, all four review overlays inspected, and 64 bands applied. Every resulting crop matches the batch geometry to numerical precision. [UI evidence](Tests/full_scores/ave-ui-auto-results.json).

## Corrections driven by independent review

- Skew-aware sampling across multiple horizontal regions recovers weak staff lines and rejects dense note/beam harmonics. Different staff sizes on the same page are supported; the Trio's smaller clarinet/cello staves and dense page 16 now work.
- A Quartet p9 false narrow Cello pattern had the right count but wrong five-line spacing. Left-edge evidence and a regression on line height corrected it. Staff count alone is never the acceptance gate.
- Quartet crops needed wider top/bottom context to retain high slurs, ledger notes and rehearsal boxes G, M and D. Target preservation takes precedence over removing neighboring notes.
- Ave's combined bass/organ part needed extra lower padding for the third figured-bass row.
- Independent Trio review rejected horizontal margins that cut a final barline and the `1` in measure number `122`. Full-width crops corrected both across the entire score.
- Final safety review added visible per-band detector warnings, rejected overlapping shared-direction fragments, and stopped preview/export when requested scan correction fails; wrong-coordinate fallback cannot silently produce a part.
- Layout now minimizes pages and balances systems within musical sections, reducing spacing before changing page count. It keeps a consistent scale, preserves crop geometry and ignores source-page boundaries. Export adds `page / total` footers. Musical page-turn timing still needs a player's judgment.

## Review and verification

Independent agents reviewed source pages, crop boundaries and final outputs. Every final PDF page received visual inspection. The reports distinguish complete source comparisons, output layout inspection and magnified vulnerable passages: [small scores](Tests/full_scores/small-score-independent-review.md), [Quartet source](Tests/full_scores/brahms-quartet-review.md), [Quartet output](Tests/full_scores/quartet-independent-review.md), [Trio source](Tests/full_scores/brahms-trio-review.md), [Trio independent review](Tests/full_scores/trio-independent-review.md).

The automated review validates independently counted system coverage, output order, crop/placement bounds, staff containment and exact source/output hashes. Protected source regions are independently reviewed musical envelopes, not inferred note recognition. They supplement, rather than replace, visual comparison. All 1,326 protected/source-direction regions pass exact comparison at 216 dpi (382,119,104 grayscale pixels). Main target regions use an untrimmed source reference; copied directions use the independently reviewed fragment extent. Scanned scores compare directly against the original. For the two vector Mozart scores, an independent full-source CoreGraphics serialization accounts for path/glyph rounding at export; raw direct-render differences are retained in the reports. There is no image-similarity tolerance, smoothing or source-ink modification. Per-set fidelity records describe the method and limits. The [fidelity review](Tests/full_scores/pixel-fidelity-review.md) records successful negative controls for deliberately removed notes, staves, tempo glyphs and clipped guards. The [finalization audit](Tests/full_scores/review-finalization-audit.md) verifies stale maps/reviews/placements are rejected before publication.

Native checks pass 126 complete-corpus planner assertions, 35 whole-score document assertions, 5,315 layout assertions and 161 rendering/export checks. The 362-check legacy preservation bridge still passes. Both Debug and universal arm64/x86_64 Release builds succeed. The [macOS preview archive](artifacts/macos/Partsmith-extraction-preview-macos.zip) is an unsigned local build, not a notarized public release.

## Reproduce the complete native path

```sh
bash tools/test_score_planner.sh --corpus
bash tools/test_score_document.sh
bash tools/test_layout_export.sh
bash tools/test_preservation_exports.sh
.build/extraction-venv/bin/python Tests/full_scores/test_pixel_comparator.py
bash tools/score_extraction_batch.sh inventory --source SCORE.pdf --out WORK/inventory
bash tools/export_score_plan.sh --inventory WORK/inventory/inventory.json \
  --profile Tests/full_scores/SCORE-profile.json \
  --overrides Tests/full_scores/SCORE-overrides.json \
  --title 'Work title' --composer 'Composer' --out WORK/parts
.build/extraction-venv/bin/python tools/review_score_output.py WORK/parts \
  --map Tests/full_scores/SCORE-map.json --pixels
```

Exact source filenames/hashes, profiles, reviewed mappings and exceptions are under [Tests/full_scores](Tests/full_scores). The two Brahms map filenames use the `brahms-` prefix. Regenerating a map requires fresh source review; do not overwrite reviewed envelopes merely to satisfy a new crop.

The remaining sections document earlier excerpts and historical limitations. They are retained as failure/review evidence; the complete-score results above supersede their source coverage, detector counts and UI limitations.

---

# Earlier excerpt workflow and evaluation

The result is two parallel workflows: a reusable [ChatGPT/Codex skill](skills/score-part-extraction/SKILL.md), and an improved native macOS application that runs without internet access. They share an editable project format. The skill is installed in the local personal skills directory as `score-part-extraction`.

The previous project state, including unfinished bar-number work, was preserved in commit `6b422ea` before these changes.

## What was tested

| Score and scope | Extracted part | Result |
| --- | --- | --- |
| Mozart, Ave verum corpus, complete four-page score | Soprano; eight systems, bars 1–46 | Reviewed one-page PDF. All lyrics, notes, slurs, opening tempo and source measure numbers retained. |
| Mozart, Notte e giorno, complete four-page score | Piano; twenty grand staffs, bars 1–73 | Reviewed four-page PDF. Seven precise exclusions remove neighboring lyric fragments while preserving nearby notation. Original source page divisions retained. |
| Brahms, Quartet No. 3 Op. 67, medium scan, PDF pages 1–3 | Violin I; fourteen systems, bars 1–98 | Preservation review passed after expanding every crop, removing all masks, and freshly checking all target notation. Three-page excerpt, with neighboring ink deliberately retained. The earlier clean-isolation test remains a historical failure. |
| Schumann, Frauenliebe und Leben Op. 42, lightly skewed scan | Voice; complete first song, six systems | One-page reviewed part. All lyrics, directions, phrasing and final fermata retained. No masks; five strips include small neighboring fragments. |
| Brahms, Clarinet Trio Op. 114, lightly skewed scan, PDF pages 1–3 | Clarinet in A; eleven systems, bars 1–62 | Three-page reviewed excerpt. All target notes and markings retained; six strips retain neighboring fragments. No masks. |

Reviewed results are [Ave verum](output/pdf/ave) and [Notte e giorno](output/pdf/notte), each containing its PDF, portable recipe, immutable source-embedded project and exact-hash review manifest. Preview PNGs are generated locally but omitted from git. Native re-exports also received visual inspection.

The original failed scan is retained locally under `.build/extraction/brahms-draft`. Its [failed review](Tests/extraction/brahms-failed-review.json) and [passage report](Tests/extraction/scan-test-report.md) remain historical evidence. The new [Brahms preservation output](output/pdf/brahms-preservation), [Schumann song](output/pdf/schumann-preservation), and [Clarinet Trio excerpt](output/pdf/trio-preservation) have fresh independent reviews bound to their exact PDF hashes. No failed result was simply relabeled. The user explicitly accepts neighboring notation and requires all intended-staff notes to remain.

## Preservation follow-up

The acceptance criterion separates **target preservation** from **neighboring notation**. Under `preserve-target`, neighbor fragments can remain; missing target notes, slurs, dynamics or other required marks still fail. Original `clean-isolation` recipes keep their original review criteria for compatibility.

The skill now requires source-coordinate protected target regions for preservation recipes. Builds reject crops that cut through these regions and whiteouts that intersect them. Enlarged context images show source ink outside each crop, avoiding the blind spot of checking only an already-clipped image. A version-2 review records an observation and neighbor-context disclosure for every strip. These guards protect reviewed regions; they do not infer instrument identity or automatically discover all notes. Native project edits do not yet enforce protected regions.

For the difficult quartet, two independent agents compared every source system with the new output, including high-right slurs and ledger notes, full fp/dim. markings, rehearsal boxes A–D, ties, articulations and meter changes. All 14 strips now preserve their target notation with no whiteouts. The broader crops intentionally admit adjacent Violin II notes and preceding-system cello fragments. [Author review](Tests/extraction/brahms-preservation-review-notes.md), [independent review](Tests/extraction/brahms-independent-review.md).

The cleaner scans were tested in parallel: the complete Schumann song and an eleven-system Clarinet Trio excerpt. Automatic staff counts were correct, but mapping and crop edges still received manual review. The trio required widening around low dynamics and high slurs; success does not imply one-click extraction. [Schumann independent review](Tests/extraction/schumann-independent-review.md), [Trio workflow](Tests/extraction/trio-preservation-review.md), [Trio independent review](Tests/extraction/trio-independent-review.md).

All 83 protected regions across these three results match an **unclipped full-source rendering pixel-for-pixel at 216 dpi** after applying the output placement transform. This supplements the musical comparisons; the regions themselves were established visually. [Pixel results](Tests/extraction/preservation-pixel-results.json).

## Iterations that changed the implementation

1. Dense beams initially merged staff-line responses. Local maxima and distributed horizontal evidence improved detection. The Python workflow finds all 64/58/56 expected staves across the two complete digital scores and three scan pages. Instrument identity still requires a source-derived map.
2. Correct staff counts still produced clipped lyrics, slurs and dynamics. Every final strip was compared against the source; crop edges were corrected individually. The piano's first two systems have no voice staff, so a repeated modulo assignment would have been wrong.
3. Some vocal lyrics overlap the piano clef's vertical range. Seven spatially precise whiteouts solved the separable cases. High-resolution review found a subpixel residual at coincident crop edges; boundary-only bleed fixed it without expanding interior mask edges.
4. Independent review found native layout could clip staff ends at enlarged scale and overflow tall bands. Export now respects margins, preserves aspect ratio and rejects invalid/missing source geometry explicitly.
5. A final code review found non-ASCII text could turn into question marks, and failed multi-part rebuilds could leave altered PDFs beside an old reviewed manifest. The skill now embeds a Unicode font when needed and stages complete generations before publication. Previous generations remain in returned hidden backup directories.
6. Editorial labels and explicit page breaks now persist into the native project, avoiding silent loss of a supplied tempo/rehearsal cue during local re-export.

The independent piano forward-test narrative is [here](Tests/extraction/forward-test-report.md). It records the historical intermediate limitations as well as the observed musical corrections; the current bridge also preserves labels/page breaks.

## Native app behavior

Import a score, create/select a part, then use **Find Staves**. The offline review sheet shows numbered proposals and line confidence. Select the relevant staves; use two staves per band for a grand staff. Repeated-order selection is available only when the detected count divides into the chosen system size, and still requires checking instrument order. Applying proposals is one undoable edit with duplicate suppression.

Detection uses a background worker with its own PDFKit document, cancellation and stale-result checks. Rectification uses local CoreImage; a failed requested correction cannot silently supply proposals in the wrong coordinate space.

The band inspector provides **Expand Crop** (1–36 source points per side, clamped at page edges, one-step undo), whiteout areas, editorial labels and page breaks. Expansion never moves edges inward; existing whiteouts remain unchanged and need separate review. Preview and export use the same native renderer. The app requires no Python environment, downloaded model, cloud backend or AI service. Different typography can affect pagination relative to the skill, so check native re-exports.

Native detector evaluation covers nineteen source pages and 283 expected staves. Sixteen asserted pages find all 227 expected staves, including both new Schumann pages. The medium quartet yields 16/20/19 raw; applying the existing 0.675-degree correction on page 3 recovers the twentieth staff. These are geometry results, not claims of complete playable extraction. [Exact filenames and findings](Tests/extraction/native-detection-report.md).

## Reproduce the checks

Set up any Python 3.10+ environment with the skill requirements; the local run used `.build/extraction-venv`:

```sh
python3 -m venv .build/extraction-venv
.build/extraction-venv/bin/python -m pip install -r skills/score-part-extraction/scripts/requirements.txt
.build/extraction-venv/bin/python -m unittest discover -s Tests/extraction -v
.build/extraction-venv/bin/python Tests/extraction/regression_review.py output/pdf/notte
bash tools/test_staff_detection.sh --samples
bash tools/test_layout_export.sh
bash tools/test_preservation_exports.sh
.build/extraction-venv/bin/python Tests/extraction/check_preservation.py \
  output/pdf/brahms-preservation output/pdf/schumann-preservation output/pdf/trio-preservation
```

Python tests cover actual score counts, source immutability, vector preservation, bounds and coverage validation, portable project coordinates, whiteout transforms, review hashes, Unicode text, and failed/reduced-part rebuilds. Seven mask-edge pixel checks detect residual fragments; three critical clef/slur/chord regions must match an unmasked reference exactly.

All eighteen Python tests pass, including real regressions for a cropped Brahms slur and masks over fp, dim. and rehearsal D. Fresh rebuilds using the final skill reproduce all five reviewed output pages pixel-for-pixel at 144 dpi; [comparison record](Tests/extraction/final-rebuild-results.json). Independent agents both operated the skill and reviewed the implementation, with original failure repros rerun after fixes.

Native harnesses pass 5,295 layout assertions and 148 crop/export assertions, covering layout boundaries, tall crops, invalid geometry, explicit page breaks and labels, whiteout persistence, undo/redo, and real piano project re-export. An additional 362 preservation-bridge checks re-export all three scanned projects through the production native renderer: all 31 bands and 83 protected regions survive, with 3/1/3 output pages, all labels, and explicit breaks retained. The maximum source-coordinate deviation is about 0.000014 point due to PDFKit/PyMuPDF page-size precision (tolerance 0.0001 point). All seven scanned native output pages also passed visual review; [native result record](Tests/extraction/native-preservation-results.json). The detector suite separately checks grouping, undo/redo and stale/cancelled detection. Rendering checks compare all pixels outside native masks with the unmasked native renderer. The final native piano export has four pages of five systems each, with all eighteen supplied labels and seven masks preserved; every page received independent visual inspection. The macOS graphics sandbox can prevent CoreImage from rendering; corrected scan benchmarks were verified with ordinary local graphics access.

Debug and Release builds use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Partsmith.xcodeproj -scheme Partsmith -configuration Release \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The revised Release build and native rendering tests pass. A live UI spot-check of the new Expand Crop control could not run because the Mac was locked; the control’s document operation, edge clamping, persistence, undo and recovered-ink rendering were exercised by the native harness.

The resulting app is `.build/DerivedData/Build/Products/Release/Partsmith.app`; the local preview archive is [Partsmith-extraction-preview-macos.zip](artifacts/macos/Partsmith-extraction-preview-macos.zip). This is a local unsigned preview build, not a published/notarized release.

## Practical limits

This workflow is robust about preserving source geometry, exposing uncertain results, retaining review evidence and refusing failed output. It is not unattended extraction for arbitrary scores. Staff detection cannot infer all instrument changes, shared markings or tacet duration. Small overlapping fragments can be masked only when the target ink is separately identifiable. Truly interleaved notation, severe scan distortion and musical page-turn planning still need informed review. The original failed clean-isolation test remains as evidence of unsafe cleanup; the new preservation result demonstrates the accepted alternative of retaining neighboring context.
