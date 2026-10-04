# Known limitations

Partsmith extracts parts by preserving the score's printed notation in editable crops. It runs locally on macOS and provides automatic staff detection, assisted instrument setup, rest counting and layout. It does not transcribe notes, transpose music or re-engrave a score. See [Getting Started](README.md#getting-started-with-auto-extract) for the Auto workflow and [EXTRACTION_WORKFLOW.md](EXTRACTION_WORKFLOW.md) for review and test guidance.

## Detection and musical review

- **Auto needs an instrument setup.** Select printed names on the score, choose a starting profile or enter names. Recognition retains printed numbers and gives separate labels unique part names, but names, order, staff counts and shared lyrics still need checking.
- **Scans and dense notation remain difficult.** Deskew and alignment run before staff identification when requested. Severe curvature, faint or broken lines, overlapping notation and unusual engraving can produce missed staves or broad crops. A plausible staff count does not prove the correct instrument mapping or complete notation.
- **Changing instrumentation needs explicit assignment.** Drag across a system's staves in the enlarged **Assign Instruments** view, then confirm its instruments and staff counts. Page/system labels and recalled assignments help navigation; **Find Similar Systems** reduces repeated work. Equal staff counts can describe different ensembles, so matching geometry does not establish instrument identity.
- **Suggested system bar counts need checking.** **Bars in system** can fill an empty field from shared printed barlines across multiple selected staves. It requires clear connecting barlines across a staff gap; a single selected staff, disconnected patterns or uncertain scans remain manual. It counts printed compartments, not rhythmic durations: pickups and split measures can make that number unsuitable for whole-bar rests. Verify it against the source before assigning absent-instrument rests. Entered and assigned counts are kept when a new suggestion finishes.
- **Target preservation takes priority over cleanup.** Neighboring notes and staff fragments can remain, sometimes including a whole neighboring staff. Check notes, ledger lines, slurs, dynamics, lyrics, shared verses and footnotes against the original. Trimming a crop in Preview makes cleanup easier, but cannot determine musical ownership or separate ink that physically overlaps.
- **Shared-direction detection is incomplete.** Auto's experimental option copies some printed tempos, repeat directions and paired endings. Rehearsal letters and some endings are missed; copied boxes can retain neighboring notation or duplicate locally visible words. Inspect the copies and add or remove source markings as needed. Automatic direction copying currently requires consistent instrumentation.
- **A reviewed example is not a general accuracy guarantee.** Complete assisted outputs, unresolved sources and rejected detector experiments are distinguished in the [quality-control index](Tests/quality_control/README.md). Detector counts and pixel-preservation checks do not replace musical review. Private experiments described there are not necessarily included in the app.

## Rest compression

- Automatic compression recognizes complete **single-staff** strips with clear measure boundaries and one hanging whole-bar rest per bar. It retains printed opening and ending context and keeps uncertain strips unchanged. Playing entries, ambiguous symbols, interior changes, fermatas, repeat notation and neighboring ink can prevent recognition.
- Opening-symbol recognition handles treble and bass clefs; uncertain alto/tenor clefs remain unchanged. Grand staffs, rest runs within a mixed playing/resting system, and automatic joining of source-image rest strips are not supported.
- **Set Count Manually** is available for reviewed exceptions. Original crops remain saved and can be restored. Explicit joining is subject to musical-context barriers; confirmed rests for instruments omitted from a system have a separate joining workflow. Neither path infers an unknown tacet duration.
- Rest detection cannot recover notes already lost by a crop. Verify the target staff before compressing it, and preserve any tempo, meter, key, repeat or other change within a rest passage.

## Editing and layout

- **Scale, System Gap and Side Margins are shared by default**, with **Customize This Part** for local overrides. **Use These Settings for All Parts** clears those overrides in one undoable step. Other options, including page balancing and consistent scale, remain per-part settings.
- **Scale can exceed the available page width.** The Inspector's **Fits Within Margins** value is guidance, not a clamp. Oversized notation can enter the margins and be clipped at the paper edge in Preview and exported PDFs. An unusually tall indivisible crop still shrinks to fit the page height; inspect its readability.
- **System Gap is literal**, including with **Balance Page Fill** enabled. Balancing can change page breaks while keeping the chosen gap; a large gap can add pages. The app does not read the music to choose comfortable performance page turns. Explicit breaks and editorial labels are available.
- Preview crop handles edit the same top and bottom boundaries as Source and export. Bands retain left/right trims from setup or saved projects, but direct crop handles edit top/bottom boundaries. Whiteouts are edited numerically; drawing and dragging them directly on the score is not implemented. Recheck whiteouts after crop or rectification changes.
- **Expand Crop** moves edges outward by source PDF points and supports Undo; it does not recognize missing notes. The extraction skill's protected-region guards are not enforced by native editing. Changes and native re-exports need fresh review.
- Rotated PDF pages and unusual CropBox/MediaBox combinations need special care. A failed requested rectification is reported rather than silently using the wrong page geometry.

## Platform and performance

- The app requires macOS 14 or later. The downloadable build supports Apple Silicon and Intel, is ad hoc signed, and is not notarized or distributed through the App Store.
- Source PDFs are embedded in project bundles. The native workflow needs no Python environment, downloaded AI model or network service.
- Staff analysis and preview rendering run in the background with cancellation and stale-result checks. Layout sliders commit once on release and keep the previous preview visible while rebuilding. Large or complex PDFs can still take time to render; export and some older analysis paths can block the interface.
- Auto offers page thumbnails, ranges and optional skipped-page review. Pages with no detected staves can be skipped without acknowledgement; an unreadable page is an error. General source-page thumbnail navigation, drag reordering and batch band editing remain absent.
- The bundled historic sample project contains exploratory crops. Use the reviewed examples linked from [EXTRACTION_WORKFLOW.md](EXTRACTION_WORKFLOW.md) for correctness checks, and read each example's remaining limitations.
