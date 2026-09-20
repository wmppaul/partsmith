# Part extraction: complete-score native workflow

The current deliverable contains **19 complete parts from five complete scores**, generated through Partsmith's offline analyzer, planner, document transaction, layout engine and PDF exporter. The [reusable extraction skill](skills/score-part-extraction/SKILL.md) documents both the native macOS path and the portable workflow. [All outputs and editable projects](output/pdf/full-score-sets/README.md); [complete download](artifacts/Partsmith-complete-score-parts.zip).

The September 20 crop revision removes excessive neighboring staff context from Ave and the Quartet. **These are reviewed outputs, not unattended Auto results:** Ave retains 56 of 64 automatic crop rectangles and uses 8 local corrections; the Quartet retains 159 of 480 and uses 321 explicit corrections. Instrument setup and shared musical directions remain reviewed inputs. The Quartet still needs substantial crop review before Auto alone can be considered robust.

| Complete source | Parts | Output pages by part |
|---|---:|---|
| Mozart, Ave verum corpus | 8 | One page each: SATB, two violins, viola, combined Basso ed Organo |
| Mozart, Notte e giorno | 2 | Voice 3; Piano 4 |
| Brahms, String Quartet No. 3, Op. 67 | 4 | Violin I 13; Violin II 11; Viola 11; Cello 12 |
| Schumann, Frauenliebe und Leben, all eight songs | 2 | Voice 13; Piano 17 |
| Brahms, Clarinet Trio, Op. 114, all four movements | 3 | Clarinet in A 16; Cello 16; Piano 32 |

The set contains **156 output pages and 1,131 part bands**. All 84 input PDF pages were analyzed; the Trio's blank page and catalog were explicitly excluded. The native detector finds all **1,357 physical music staves**, with zero manual staff-position corrections. These are corpus results, not a guarantee for arbitrary scores. The original state was checkpointed at `6b422ea`, the excerpt workflow at `3aa78d1`, and the broader complete-score generation at `9df1d62` before this refinement.

## Crop quality and remaining context

| Score | Previously delivered neighboring line centers | Revised | Complete neighboring staves, before → after | Pages, before → after |
|---|---:|---:|---:|---:|
| Ave | 227 | 12 | 0 → 0 | 8 → 8 |
| Quartet | 3,629 | 148 | 589 → 0 | 75 → 47 |

These counts measure detected line centers inside main crops; they are an approximate context metric, not musical recognition. Every revised band and output page was also reviewed visually against the source. Ave's duplicated lyric rows and broad adjacent staff areas are gone. Some isolated neighboring notes, slur arcs, glyph tips and directions remain where vertical ranges overlap; two publisher copyright lines remain in the organ part. The Quartet retains overlapping fragments and occasional printed catalog-number fragments. No masks were used, and all independently reviewed target regions remain intact.

The final native Auto proposal itself improved to 14 neighboring line centers in Ave and 470 in the Quartet, with 0 and 38 complete extra staves respectively. Ave's 64 protected envelopes fit that proposal; 121 of the Quartet's conservative source envelopes did not. Those envelope failures are not a count of missing notes, but they require review and cannot be passed merely by issuing warnings. The final corrections and their reasons are recorded in the reviewed overrides and [Quartet correction report](Tests/full_scores/quartet-compact-correction-report.json).

## What the app now does

Initialize printed instrument order and staff counts once; enable Lyrics for vocal staves. New setups use **Compact — follow notation**. Analysis separates staff lines and tilted system barlines before measuring connected ink. Lyric rows and trailing hyphens stay with their vocal staff. Compact defaults follow detected ink with a small margin; explicitly entered padding is minimum context. Existing saved fixed-padding setups retain their behavior.

Run Auto over the whole source and inspect its review. **Adjust crop edges on this page** provides source-point Top/Bottom controls, highlights the selected band, and can restore automatic edges. Edits preserve assignments, labels, source cues and section breaks. The editor rejects edges outside the page or through assigned staff lines, including tilted ends. It cannot recognize every detached note or dynamic: compare the surrounding source before accepting an edit. Adding the reviewed parts remains one undoable transaction.

Ambiguous connected notation is retained and flagged; detached marks touching another staff may need a local correction. Names, changing instrumentation, shared directions and page-turn timing are not inferred musically. Shared tempo/rehearsal/return glyphs are copied from verified source rectangles; overlapping cue boxes are completed in the main crop when possible to avoid duplicate glyphs. The native app runs without Python, a network connection or an AI service.

Layout balances complete systems within movements/songs at a consistent scale, removes source-page breaks and prints page-number footers. It reduces spacing before increasing page count. The new full sets preserve the original engraving and scan resolution; performance page turns have not been tested by players.

## Review and verification

Independent agents reviewed every revised source band and final page. See [Ave final review](Tests/full_scores/ave-compact-final-review.md), [Quartet final review](Tests/full_scores/quartet-compact-independent-review.md), and the unchanged [small-score](Tests/full_scores/small-score-independent-review.md) and [Trio](Tests/full_scores/trio-independent-review.md) reviews. Previous failed compact generations remain clearly labeled as historical evidence.

All 1,563 protected/source-direction regions in the complete deliverable pass exact 216 dpi comparison: **312,753,822 grayscale pixels**, zero differences after documented reference normalization. Source envelopes were established independently from raw scores; they are not chosen to fit the output. The checker also requires every inventoried shared cue to exist in its main crop or a copied fragment. It records raw full-source differences, uses independently serialized original vector content, and when needed matches a scan's reviewed crop extent or CoreGraphics matrix serialization to avoid sampling-phase false positives. No exported music is used as reference content; no similarity tolerance, smoothing or whiteout is introduced. Negative controls deliberately remove notes/staves/cues, omit required cue metadata and cut a protected edge, and must fail.

Finalization rejects stale maps, manifests or PDF hashes, and compares the editable project's crop rectangles, source pages, labels, cues and section breaks with the delivered plan. Explicit geometry correction counts and band IDs are part of each review record. The three unchanged score sets retain their prior reviewed generation.

Native validation passes **147 planner/corpus assertions, 56 document assertions, 5,315 layout assertions and 161 rendering/export checks**. The legacy bridge also passes 362 preservation checks. Debug and universal arm64/x86_64 Release builds succeed. The [macOS preview archive](artifacts/macos/Partsmith-extraction-preview-macos.zip) is an unsigned local build. Exact build hashes and validation logs are recorded in [native-validation.json](Tests/full_scores/native-validation.json). The isolated live UI smoke check could not start: computer use returned no app state before being stopped. No new UI interactions are claimed; the crop editor is covered by the document tests and successful builds.

## Reproduce a reviewed revised set

```sh
bash tools/score_extraction_batch.sh inventory --source SCORE.pdf --out WORK/inventory
bash tools/export_score_plan.sh --inventory WORK/inventory/inventory.json \
  --profile Tests/full_scores/ave-compact-profile.json \
  --overrides Tests/full_scores/ave-compact-overrides.json \
  --title 'Ave verum corpus, K. 618' --composer 'Wolfgang Amadeus Mozart' --out WORK/parts
.build/extraction-venv/bin/python tools/review_score_output.py WORK/parts \
  --map Tests/full_scores/ave-tight-map.json --pixels
```

Use the matching Ave source PDF for this example. Quartet settings use `quartet-compact-profile.json`, `quartet-compact-overrides.json` and `brahms-quartet-tight-map.json`; exact sources and hashes are in the maps. These overrides include disclosed local corrections and are valid only for their reviewed source. For a new score, initialize its setup and review fresh Auto proposals instead of reusing these rectangles. The other three full-score profiles/overrides remain unchanged.

The sections below document historical excerpts. The complete-score results above supersede their coverage, detector counts and app limitations.

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

## Movable magic-wand workflow (September 20, 2026)

After import, the source view promotes **Auto Extract** as the starting action. It opens a document-owned, movable and resizable window, leaving the score interactive. Optional **Deskew & Align Pages** runs before instrument identification, preserves existing corrections, and cancels with the window. Existing bands and source-header coordinates are protected from a late geometry change.

Instrumentation can be entered manually, chosen from presets, or populated by clicking printed names on either the raw or rectified score. Local Apple Vision recognition isolates the clicked label from adjoining staff symbols; names and staff counts remain editable. A new project starts with no assumed quartet profile. Starting a new clicked list replaces entries only after the first successful pick; choosing a preset cancels pending recognition.

Both acknowledgement checkboxes and mandatory typed omission/exclusion reasons have been removed. **Add Parts** applies valid proposals directly as one undoable edit. **Exclude This Page** records an explicit exclusion and advances to the next flagged page. Warnings and genuine missing-assignment checks remain.

Validation: **55 instrument-name checks**, including the actual Brahms labels before and after native deskew; **28 deskew lifecycle checks**, including cancellation ownership, stale geometry, bands and source headers; and **64 whole-score document checks**. The universal Release app builds successfully. Live UI testing moved the window, selected printed labels, ran deskew on the 35-page medium-skewed Brahms scan (7 corrected pages), assigned all 393 bands, excluded pages 34 and 35 with one click each, and added three 131-band parts. Reopening and Escape closing were also checked. An early UI build still included an adjoining OCR character in the clarinet name; the final detector passes exact-name tests on the production raw and corrected rasters. These are workflow checks, not a fresh review of every musical crop.

Run the focused suites with `bash tools/test_instrument_names.sh`, `bash tools/test_rectification_flow.sh`, and `bash tools/test_score_document.sh`. Apple Vision and corrected-image rendering need ordinary local graphics service access.

### On-score name feedback and automatic printed headers

Recognized instrument names now keep a green outline and readable badge beside the printed label while picking. Earlier successful picks remain visible after later clicks, including unsuccessful clicks. Highlights follow the displayed raw or rectified page, clear when its source geometry changes, and never enter exported parts.

The magic-wand setup also offers **Find the printed title and composer automatically**. Offline recognition locates a conservative source-image crop above the first music system. The review shows that crop with **Use Printed Header** and **Adjust on Score**; adding parts applies the untouched automatic header in the same undoable edit. Existing manual selections and typed-header preferences are preserved. Manual selection remains available if no suitable title is found.

Validation for this update: **97 instrument-name checks**, **38 source-header checks**, and **106 document assertions** including the real Ave Verum detection/export path. Header crops received visual inspection on raw and deskewed Brahms Trio, Ave Verum, and Notte e giorno; continuation-page titles were rejected. Document checks cover persistence, per-part export, invalid bounds, existing manual selections, and combined header/parts undo and redo. The universal Release build passes.

Live UI testing clicked all three printed Brahms Trio instrument labels and verified all three highlights and badges together. Auto produced a printed-header preview, assigned 393 bands, and added three 131-band parts after excluding the two non-music pages. The production part preview displayed the copied title and composer above the music. The smoke-test project is saved locally as `.build/Name-Header-UI-Smoke.partsmithproject`. These checks validate the new workflow; they do not constitute a fresh musical review of every crop.

Run the additional checks with `bash tools/test_source_headers.sh` and `bash tools/test_score_document.sh --source-header`.

### Input page selection and optional skipped-page review

Auto Extract now has a scrollable thumbnail picker, **All Pages** / **Selected Pages**, and ranges such as `1-8, 12`. Both deskew and extraction use only the selected source pages. Review navigation, source headers, crop coordinates, and exports retain their original source indices even for nonconsecutive selections. Thumbnails render at small sizes on a separate worker; invalid or empty ranges cannot start processing.

Successfully rendered pages with no detected staves are skipped automatically. **View Skipped Pages** and **Restore Page** allow optional inspection, while the blue **Add Parts** button remains available when the music assignments are complete. An unreadable raster remains an error rather than being silently treated as blank. Selecting only blank pages creates no empty parts.

Validation: **154 document assertions**, including real Ave Verum scoped-header detection and export, plus **37 deskew workflow checks**. Coverage includes sparse indices, selected-page progress, range parsing, empty/invalid input, skip/restore behavior, rendering failures, original-coordinate export, and undo/redo. Independent review checked both core and UI integration. The universal Release build and archive checks pass. Subsequent live testing verified the thumbnail selector, Current Page, and the sparse range `1-3, 25` selecting exactly four pages.

### Numbered instruments, editable name boxes, and responsive preview

Printed ordinals are retained with instrument names, including Arabic and Roman prefixes. Spatially distinct labels remain distinct instruments even when their recognized names match; unique suffixes distinguish them. Clicking a label again or adjusting its green selection box updates the existing row. Manual name edits are preserved. The source canvas supports both clicking and dragging an exact recognition box.

Scale and Preferred System Gap keep a local draft during a slider gesture and commit one undoable edit on release. Preview generation uses immutable snapshots and a separate background PDF document, cancels superseded work, and retains the current page. Unchanged inputs reuse the preview. Export and preview continue to use the same layout and drawing code.

Validation: **205 instrument-name checks** cover actual numbered quartet labels on raw and rectified scans, ordinal clicks, region edits, and separate identical labels. **24 preview checks** cover rapid superseding changes on the 131-band Brahms part, cancellation, reuse, missing-source clearing, exact preview/export pixels on first/middle/last pages, and excluded-strip barriers for rest joining. Enqueuing the measured preview request took under 1 ms. Independent review found no snapshot, cancellation, or renderer isolation defects. Live testing confirmed numbered highlights, separate same-name rows, resizing a recognition box, slider track clicks, accessibility increments, and one-step Undo. The automation's native slider drag produced no callbacks, so live drag behavior remains unverified; standard SwiftUI tracking handles the local draft.

Run `bash tools/test_instrument_names.sh` and `bash tools/test_preview_performance.sh`.

### Explicit multi-bar rests

Select a rest-only band and expand **Multi-bar Rest** in the inspector. Enter 2–999 full bars and choose **Replace with Rest**. The renderer draws a vector five-line staff, H-bar and count, while the project retains the original source coordinates, whiteouts, labels and copied source markings. **Restore Original Crop** and Undo recover the source. Crop, source, instrument-assignment, whiteout, copied-marking or correction changes clear the affected replacement; copying a band to another page never copies its rest count.

**Join with previous rest** is an explicit choice, off by default. Joining stops at ordinary music, excluded strips, annotations, copied markings, explicit page breaks, conflicting known bar numbers, or a total above 999. Individual source bands and their original counts remain in the project. Preview retains excluded strips as ordering barriers, matching Export. No automatic rest recognition or partial-system cutting is performed.

The [source audit](Tests/extraction/rest-compression-review.md) identifies real whole-rest bands in Brahms, Mozart and Schumann, plus counterexamples containing a playing entrance, a fermata and changing meters. The [Brahms demonstration](output/pdf/rest-compression-example/README.md) replaces only bars 42–47 with a six-bar rest and retains the following mixed system, including the entrance in bar 51. This is an explicitly labeled one-page excerpt, not a revised full part. New tempo/key/meter changes, repeats, cues and fermatas need their original notation or separately preserved markings.

Validation: **44 rest layout/export checks**, **55 rest document checks**, **24 preview checks**, **5,315 existing layout assertions**, and **161 native crop/export checks** pass. A synthetic 4+5 example renders one nine-bar rest. Live UI testing restored the original Brahms strip, entered six bars, applied the replacement, and verified the result and following music in Preview. Source bytes remain unchanged. The universal Release app builds successfully.

Run `bash tools/test_multibar_rests.sh`, `bash tools/test_rest_document.sh`, and `bash tools/test_preview_performance.sh`.

## Practical limits

This workflow is robust about preserving source geometry, exposing uncertain results, retaining review evidence and refusing failed output. It is not unattended extraction for arbitrary scores. Staff detection cannot infer all instrument changes, shared markings or tacet duration. Small overlapping fragments can be masked only when the target ink is separately identifiable. Truly interleaved notation, severe scan distortion and musical page-turn planning still need informed review. The original failed clean-isolation test remains as evidence of unsafe cleanup; the new preservation result demonstrates the accepted alternative of retaining neighboring context.
