# Part extraction workflow

Partsmith preserves the score's printed notation as editable crops and assembles a PDF for each part. The native macOS workflow runs offline. The [score-part-extraction skill](skills/score-part-extraction/SKILL.md) provides a parallel ChatGPT/Codex workflow with source maps, protected regions and independent output review. They share an editable project format, but their typography and pagination can differ.

Use [Getting Started](docs/getting-started.md) for the illustrated app walkthrough and [Advanced workflows](docs/advanced-workflows.md) for task-specific instructions. This page covers review, changing instrumentation, reproducible checks and the status of the example outputs. The [known limitations](KNOWN_LIMITATIONS.md) describe remaining recognition and editing gaps.

## Native Auto workflow

1. Import a full-score PDF and choose **Auto Extract**. Its window is movable and resizable, so the source remains accessible.
2. Set **Pages to extract** using **All Pages**, thumbnails or a range under **Selected Pages**. For a scan, optionally run **Deskew & Align Pages** before selecting names or creating crops. Both deskew and Auto use the selected input pages; existing corrections are kept.
3. Choose **Select Instrument Names on Score**. Click each printed name, or drag around its full label, in top-to-bottom order within one system. For an unnamed staff, drag a box beside it; an empty or unreadable selection opens a focused name field and staff count below the score. Add the typed name with **Add Instrument** or Return, or cancel that selection. Both typed and recognized picks stay highlighted and use the same separate-part naming rules. The source bar shows the list and **Done — Back to Auto Extract**, which returns to setup. With an explicit page selection, picking opens the first included page. Use **Add Names from Score** or **More → Replace List from Score** for an existing list. A starting profile or typed list is also available.
4. Check instrument names, order and staff counts. A piano grand staff uses two staves. Enable **Lyrics** for vocal parts; shared lyrics and additional verses still need source comparison. Separate printed labels remain distinct parts even if recognition gives them the same name. Adjusting a green name box rereads that label rather than adding another part.
5. Keep **Find the printed title and composer automatically** enabled if wanted, then choose **Auto**. New profiles use **Compact — follow notation**; fixed padding is also available. Auto shows the proposed crops and printed header, along with uncertainty notes. The experimental source-direction option can copy detected tempos, repeats and paired endings; it does not certify complete marking coverage.
6. Resolve incomplete assignments and inspect any uncertain crops. Pages with no detected staves are skipped automatically; **View Skipped Pages** is optional. Unreadable pages remain errors. **Add Parts** applies a valid plan as one undoable edit, without a review checkbox or typed blank-page reason. Automatic full-bar-rest compression, when enabled, runs afterward as a separate undoable operation.
7. Select each part in **Preview**. Click a system and drag its blue top or bottom handle to refine the crop; release to apply or press Escape to cancel. Source, the saved project and export use that same crop. Use **Restore Original Crop** before editing a compressed source strip.
8. Adjust layout, inspect every output page, save the project and use **Export All** in Source mode. **Export PDF** in Preview exports the selected part. Manual parts, crop drawing and the single-page **Find Staves** tool remain available.

The printed header is a source-image selection, not a newly typeset title. Its review offers **Use Printed Header** and **Adjust on Score**. Existing manual header choices are preserved. Once crops or a header exist, automatic deskew in the setup is disabled; page corrections remain available in the Inspector and require renewed crop review.

## Changing instrumentation and silent systems

Enable **Instrument layout changes between systems** when the score hides silent instruments or changes its printed staff grouping. Auto detects the staves, then **Assign Instruments** provides a larger, zoomable source view. Drag across the staves of one complete system and watch the highlighted selection. Click individual staves to adjust it; Shift-click or Shift-drag adds staves. Check the instruments actually printed and set their staff counts. A temporary divided section can use a different staff count without changing the overall instrument setup.

The selector and assignments show **Page N · System N**, where system numbers restart on each source page. Returning to an assigned system restores its instrument choices, staff counts, optional first bar and bar count. Selecting that system's exact staff group or choosing **Load** also restores its assignment. A new, unassigned system does not inherit the previous system's rest duration.

When the selected staves match the checked instrument counts, Partsmith tries to fill an empty **Bars in system** field in the background. The suggestion uses aligned printed barlines across multiple staves, including connections through a staff gap. It counts a piano grand staff once. A single selected staff, disconnected barlines or unclear source geometry can leave the count manual. Existing entered and assigned counts take priority over suggestions.

Check or enter the system's actual count before choosing **Assign System**. Printed barline compartments can include pickups or split measures; a suggested count does not establish their rhythmic duration. For confirmed absent instruments, Partsmith inserts that many bars of rest so the part's timeline does not silently lose measures. These are editable rest records tied to the system's source location. Confirm silence and keep any tempo, meter or rehearsal change at its original measure; neither staff geometry nor the bar-count suggestion establishes those musical facts.

After assigning an example of each layout, expand **Reuse Assigned Layouts** and choose **Find Similar Systems**. **Show** highlights each proposal on the source. Review the matching instrument groupings, enter required counts, select the proposals and choose **Use Selected Layouts**. Similarity is an aid to assignment, not proof of instrument identity. Missing or ambiguous systems still need manual assignment.

For example, Mozart K.488 movement I, source page 17, has piano and strings in bars 144–149, piano alone in bars 150–152, and the full ensemble in bars 153–156. The strings need a three-bar rest for the piano-only system; the winds need six bars followed by three bars. Keep shared changes at their correct measure when preparing those rests. The [Mozart source review](Tests/extraction/mozart-variable-instrumentation-review.md) documents the example.

## Rest compression and layout

**Count and compress full-bar rests automatically** examines newly added source strips. Existing parts have **Find & Compress Rests**, and individual strips have **Count & Compress This Strip**. The detector works locally in the background and retains printed opening/ending context. Uncertain passages keep their source notation. **Set Count Manually**, **Restore Original Crop** and Undo support reviewed exceptions and recovery.

Automatic recognition supports complete single-staff strips and two-staff groups whose hands agree on whole-rest counts and boundaries. Partial-system runs, playing entrances, interior changes and ambiguous neighboring ink can prevent compression. Consecutive confirmed rests join by default, including a compressed opening grand staff followed by inserted rests when its closing barline is ordinary. The opening clefs, signatures, brace and directions remain, with one shared count. A later printed prefix remains separate so a changed signature or direction cannot disappear. Directions, explicit breaks, excluded rows and conflicting bar numbers also stop joining. Optional first-bar numbers are not required; counts are still confirmed independently for every source system. For inserted rests or manual replacements without printed source context, uncheck **Join with previous rest** to keep a separate row. The [automatic-rest review](Tests/extraction/automatic-rest-review.md) records positive examples and rejected passages; [complete Brahms examples](output/pdf/automatic-rests/README.md) retain their original source crops.

**Scale**, **System Gap** and **Side Margins** use shared score settings by default. Editing one linked part updates the other linked parts and supplies defaults for future parts. **Customize This Part** freezes its current values as a local override; turning it off resumes the shared values. **Use These Settings for All Parts** promotes the selected part's layout and removes those overrides in one undoable step. Page balancing, consistent scale, titles and source crops remain separate settings.

New projects start with 18-point side margins. System Gap ranges from 4 to 200 points and is applied literally, even when balancing is enabled. Page balancing can redistribute complete systems without reducing that chosen gap. Larger gaps can therefore add pages. Explicit page breaks support movements, songs or reviewed turns; automatic musical page-turn planning is not implemented.

Scale applies the requested enlargement instead of stopping at the available width. Above 1.00, verified blank source-side space is removed when possible. **Fits Within Margins** is a recommendation: exceeding it can put notation into the margins or beyond the paper edge, where Preview and PDF export clip it. With **Use Consistent Scale**, systems within a part share a horizontal source reference, preventing different ink bounds from recentering individual strips. Unusually tall indivisible crops still fit vertically to a page. Inspect the result before export.

Layout sliders keep a draft during a gesture and commit once on release. Preview builds in the background, cancels superseded work and keeps the previous pages visible. Preview and export use the same layout and drawing code. Large source PDFs can still take time to render.

## Review standard

Check every requested part and every final output page against the original score. An independent reviewer should inspect both the uncropped source and the delivered PDF; reviewing only an already cropped image can conceal missing notation.

- **Identity and coverage:** correct instruments, all systems and measures in order, no unexplained gaps or duplicates, and confirmed rest counts for absent instruments.
- **Target preservation:** complete notes, ledger lines, slurs, articulations, dynamics, lyrics and required shared markings. Check outside each crop boundary as well as inside it. Missing target notation fails even if the crop looks cleaner.
- **Neighboring notation:** disclose retained fragments and investigate large overlapping staff areas. Keep uncertain neighboring ink when removing it would risk the intended part. Whiteout is appropriate only where source comparison establishes spatial separation.
- **Readability and layout:** useful staff size, no paper-edge clipping, complete titles and copied markings, sensible page fill, and practical turns. A balanced page is not automatically a playable turn.

The skill records independent source-coordinate protected regions and rejects crop or whiteout changes that violate them. Native editing preserves the crop and mask data but does not enforce those skill guards. Changes to crops, rectification or pagination require renewed review. Copied-direction detection and pixel comparisons support that review; neither establishes complete musical meaning.

Keep source hashes, instrument maps, explicit corrections, output hashes and review findings together. Failed experiments must remain identified as failed; do not weaken a source obligation to make a cleaner crop pass. Rebuilding changes the output generation, so bind the review to the actual files delivered.

## Reviewed examples and current evidence

The [quality-control index](Tests/quality_control/README.md) is the detailed record of complete outputs, unresolved sources and experiments. It distinguishes production changes from private candidates. Examples are assisted and source-reviewed unless explicitly stated otherwise; none establishes unattended extraction for arbitrary scores.

| Example | Scope and review status |
| --- | --- |
| [Original five complete score sets](output/pdf/full-score-sets/README.md) | September 20 generation: 19 parts, 156 output pages, 1,131 bands across Ave verum, Notte e giorno, Brahms Quartet, Schumann songs and Brahms Trio. Includes disclosed manual crop corrections. Its historical output counts and rendering checks belong to that generation. |
| [Current Brahms Quartet recheck](docs/brahms-quartet-review.md) | October 10: both complete editions and all four parts checked. Fresh Auto remains draft; the current assisted 93521 delivery retains seven prior trims and adds 72 reviewed rehearsal/fermata copies. |
| [Brahms Quartet IMSLP93521](output/pdf/auto-qc-2026-10-04/brahms-quartet-93521-reviewed-trims/README.md) | Complete four-part alternative with seven reviewed trims and the prior Viola direction repair; neighboring fragments and difficult turns remain. This is manual cleanup, not a new automatic crop result. |
| [Mendelssohn: Verleih uns Frieden](output/pdf/auto-qc-2026-10-03/mendelssohn-verleih-uns-frieden-native-draft/README.md) | Five complete parts with confirmed omitted-system rests and reviewed crop corrections. A separate [Bass-turn version](output/pdf/auto-qc-2026-10-03/mendelssohn-verleih-uns-frieden-reviewed-turn/README.md) moves the turn into rests. |
| [Mendelssohn: Hear My Prayer](output/pdf/auto-qc-2026-10-03/hear-my-prayer-40163-native-draft/README.md) | Six complete parts with assisted changing-layout assignments, source copies and local corrections. Remaining overlap and difficult turns are disclosed. |
| [Brahms: Two Motets IMSLP101580](output/pdf/auto-qc-2026-10-03/brahms-two-motets-op74-101580-native-draft/README.md) and [IMSLP101579](output/pdf/auto-qc-2026-10-03/brahms-two-motets-op74-101579-native-draft/README.md) | Separate complete five-part drafts and reviews for two distinct scans, including divided staves, shared lyrics and footnotes. |
| [Brahms: Gesang der Parzen IMSLP109041](output/pdf/auto-qc-2026-10-03/brahms-parzen-109041-reviewed-draft/README.md) | Complete assisted 20-part draft; retained neighboring notation, small print and performance-turn limitations remain. The separate IMSLP109040 scan has a source map but does not yet have a completed extraction/review. |

The [October 4 shared-layout release record](Tests/quality_control/shared-layout-release-2026-10-04/README.md) binds the app package to its sources and independent checks: 7,157 layout assertions, 169 native crop/export checks, 411 scale/export checks, 67 shared-layout checks and 48 native Inspector checks. Its legacy comparison covers 38 rendered pages. These checks verify the scoped behavior; they do not rerun or certify every score in the corpus. The [literal-layout review](Tests/quality_control/literal-layout-release-2026-10-04/README.md) covers actual scale enlargement, exact spacing and the Brahms alignment fix.

The macOS package is universal for Apple Silicon and Intel, targets macOS 14 or later, and is ad hoc signed rather than notarized. The [build notes](artifacts/macos/README.md) identify the current package. Historical review directories and manifests remain unchanged, including their original failures, counts and UI-test limitations.

## Reproduce extraction and focused checks

The native tools require macOS and Xcode. The app itself needs no Python; the portable skill and pixel-review tools use Python 3.10+ with the dependencies in [requirements.txt](skills/score-part-extraction/scripts/requirements.txt). Do not reuse a profile's reviewed rectangles on a different edition or scan.

For the historical Ave source identified by its [review map](Tests/full_scores/ave-tight-map.json):

```sh
bash tools/score_extraction_batch.sh inventory --source SCORE.pdf --out WORK/inventory
bash tools/export_score_plan.sh --inventory WORK/inventory/inventory.json \
  --profile Tests/full_scores/ave-compact-profile.json \
  --overrides Tests/full_scores/ave-compact-overrides.json \
  --title 'Ave verum corpus, K. 618' --composer 'Wolfgang Amadeus Mozart' --out WORK/parts
.build/extraction-venv/bin/python tools/review_score_output.py WORK/parts \
  --map Tests/full_scores/ave-tight-map.json --pixels
```

This reproduces the reviewed setup through the current engine; it does not promise identical pagination to the historical build. Inspect the new outputs and keep their review separate. For a new score, build a new source map, initialize its instrumentation and review fresh proposals.

To examine eligible rests in a saved project without changing that input:

```sh
bash tools/compress_score_rests.sh --project PATH/Score.partsmithproject --out NEW_OUTPUT_DIRECTORY
```

The tool writes part PDFs, an editable project and a source-hashed report. Run focused checks according to the changed behavior:

| Area | Commands |
| --- | --- |
| Staff detection and planning | `bash tools/test_staff_detection.sh --samples`; `bash tools/test_score_planner.sh`; `bash tools/test_crop_quality.sh` |
| Auto setup and document transactions | `bash tools/test_instrument_names.sh`; `bash tools/test_instrument_pick_flow.sh`; `bash tools/test_rectification_flow.sh`; `bash tools/test_source_headers.sh`; `bash tools/test_score_document.sh` |
| Changing layouts and absent instruments | `bash tools/test_system_assignment_batch.sh`; `bash tools/test_generated_rests.sh`; `bash tools/test_generated_rest_joins.sh`; `bash tools/test_default_rest_joins.sh` |
| System selection and count suggestions | `bash tools/test_system_selection.sh`; `bash tools/test_system_bar_count.sh`; `bash tools/test_system_bar_request.sh`; `bash tools/test_system_bar_ui.sh` |
| Crop editing and preview performance | `bash tools/test_preview_crop.sh`; `bash tools/test_preview_crop_ui.sh`; `bash tools/test_preview_performance.sh` |
| Shared layout and PDF geometry | `bash tools/test_shared_layout.sh`; `bash tools/test_layout_export.sh`; `bash tools/test_scale_exports.sh` |
| Rest recognition and retained context | `bash tools/test_rest_detection.sh`; `bash tools/test_rest_auto_flow.sh`; `bash tools/test_rest_context.sh` |
| Shared source directions | `bash tools/test_shared_direction_app.sh`; `bash tools/test_shared_ending_app.sh`; `bash tools/test_heading_overrides.sh` |

Apple Vision, AppKit and corrected-image checks need ordinary local macOS graphics-service access; restricted environments can fail to render even when compilation succeeds. Source-dependent suites require the matching local sample PDFs. Harness checks do not replace visual review of the final app and exported parts.

Build the native app with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Partsmith.xcodeproj -scheme Partsmith -configuration Release \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The output is `.build/DerivedData/Build/Products/Release/Partsmith.app`. Packaging, signature checks and exact source/build evidence are separate release steps; a successful local build is not a notarized release.
