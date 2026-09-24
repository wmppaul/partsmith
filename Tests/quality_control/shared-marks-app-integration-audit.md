# Native Auto shared-mark integration audit

Read-only audit, 2026-09-24. No production edits or new test execution in this audit. Source hashes are recorded in `shared-marks-app-integration-audit.json`.

## Recommendation

Expose an **off-by-default, fixed-layout-only** Auto option, initially named “Copy detected tempos and repeat directions (experimental)”. Keep Add Parts available according to the existing assignment/crop validity rules: no new mandatory review checkbox and no OCR-failure acceptance barrier. Explain briefly that endings and bar numbers may still need attention. Do not call it complete repeat preservation.

Recognition, visible review of copied rectangles, persistent removal decisions, and invalidation after staff-assignment edits belong in the same initial implementation. The tested rectangle/copy models already support save and export. A checkbox plus direct detector calls alone leaves review and stale-assignment problems.

## Existing path and insertion points

| Area | Current call site | Integration consequence |
|---|---|---|
| Setup | `ScoreExtractionView.swift:323–349` | Add the opt-in near header/rest options. `@AppStorage` default false is the smallest preference change; capture its value at run start. Keep it separate from instrument identity. A project-specific preference instead requires ProjectSettings coding/default tests. |
| Start | `ScoreExtractionView.runAuto`, around line969 | Pass a captured recognition option to `PartsmithDocument.detectScore`. Existing source/profile/page selection remains unchanged. |
| Worker | `PartsmithDocument.detectScore`, lines597–664 | Keep analysis and recognition on the existing serial `staffDetectionQueue` with worker-owned PDFDocument and per-page autorelease pools. No Vision calls in a SwiftUI body, review replan, or main-thread image update. |
| Completion | `PartsmithDocument.swift:652–662` | Enrich analyses before the single final `ScoreDetectionReview.initial`. Keep operation-identity, cancellation, source-data and rectification checks. |
| Review drawing | `ScoreExtractionView.scorePageOverlay`, lines476–497 | Currently draws only main crops. Draw sourceMarking rectangles too, with the recipient part, above/below side and selection highlight. The same source rectangle may feed multiple recipients; group its outline but list its recipients. |
| Review controls | `ScoreExtractionView.reviewControls`, around690–752 | Add a nonblocking “Copied directions” list with count, source page/system, thumbnail or focus action and Remove. Show recognition failures/skipped-layout pages distinctly from zero matches. Existing currentDetectorNotes collects band/staff warnings, not page warnings, so merely appending `analysis.warnings` is insufficient. |
| Apply | `PartsmithDocument.addScoreParts`, lines824–901 | Already maps planned sourceMarkings/isBelow into BandModel and commits all parts atomically. Retain this transaction. |
| Persistence/export | `ProjectModels.swift:504–517,696`; `PartLayoutEngine.swift:328–355,490`; `PartPDFExporter.swift:151` | Source rectangles and placement survive save/reopen and render from the original source, including rectification. Raw OCR strings/templates need not be persisted for first integration. |

## Recognition orchestration

1. Continue staff/ink analysis unchanged. For opted-in runs, require `requiresSystemAssignment != true` and a complete valid automatic page plan before recognizing that page. Mark others as “not scanned: resolve staff layout” rather than claiming no marks. Do not force counts or infer silent durations.
2. Match proven CLI rendering: heading OCR uses up to2200×3200 pixels, navigation/destinations2400×3500. For rectified pages create the OCR raster using the captured rectification and the same corrected coordinate space as the analysis. Current app analysis raster (native1800×2600, or corrected scale2.5) is not the tested OCR input. Do not reanalyze staves at the OCR resolution or mix uncorrected pixels with corrected coordinates.
3. Run heading and navigation recognition, forwarding `isCancelled` and `observedFailure`. Keep result data off the main thread. On a module's runtime failure, discard that module's partial result for the page and retain the ordinary staff/crop result with a visible nonblocking issue. Do not return nil and mislabel it as “source changed”. No success/zero-match claim for a failed request.
4. After navigation instructions have been collected across **all selected pages**, collect destination templates from eligible recognized instructions, then scan selected pages for linked destination glyphs. Destinations can precede their instruction; a forward-only one-page pipeline misses these. Respect input selection: do not silently recognize unselected pages to supply templates. No template is “unsupported/no reference”, not evidence that no symbol exists.
5. Store only small analysis metadata/template patches between passes. Re-render one page at a time for the destination pass. Preserve `observedMatches` template source-page/bounds in ephemeral review diagnostics so a copied symbol has inspectable provenance. The returned empty recognizedText denotes a glyph, not OCR failure; don't show an empty label in UI.
6. Build the final review once. Extend progress with a phase (staffs, directions, destination symbols) so the app does not sit at “all pages analyzed” while OCR continues. Pass cancellation into the heading detector's own planner call too; that call currently omits its isCancelled argument.

Cancellation remains cooperative. BlockOperation.cancel clears published progress and prevents old completion from attaching; an in-flight synchronous Vision request can finish before the worker exits. Keep checks before/after requests and between passes. A new run must never receive the previous run's warnings/results. OCR off by default must reproduce the current plan exactly.

## Review invariants that need implementation

### Removal must survive replanning

The post-apply Inspector already has Remove (`InspectorView.swift:414–428`). Auto review does not. Copying a plan into an override and deleting its sourceMarking is currently insufficient for navigation: `reviewedPage` invokes `copySharedNavigation` again and can re-add it from analysis metadata.

A minimal explicit policy is: an override band's **non-nil sourceMarkings array is authoritative**, including an empty array; nil permits automatic propagation. `setCrop` and `ScoreSystemAssignment.pageOverride` already materialize non-nil arrays. Track those authoritative recipient band IDs when copying navigation/headings, while retaining the existing separate rule for the navigation owner's explicit main crop. This avoids a new persistent project schema and permits per-recipient Remove through overrides. Validate compatibility with legacy nil overrides and reset behavior. An alternative explicit suppression field is possible, but do not overload an empty automatic result as a removal decision without documenting it.

### Staff-assignment edits invalidate ownership

`ScoreSystemAssignment.assign` preserves an old override only when partID and candidateIDs are unchanged (lines250–251). A changed band gets a fresh override. `reviewedPage` currently repropagates navigation by finding the recognized anchor in the **new** system, but does not repropagate headings at all (line622). Thus heading copies can disappear, and a retained old navigation anchor can be attached to a newly regrouped system without fresh recognition validation.

For the first fixed-layout feature, treat **candidate membership/order/system edits, ignored detections, or changed profile** as invalidating all automatically recognized ownership on that page. Clear that page's raw mark metadata and automatic copies from materialized overrides together, retain main crops and explicit removal/manual decisions, and display “Directions need a new scan after changing assignments.” Continue allowing Add Parts. A normal crop-edge edit alone must not invalidate mark identity or silently discard copied pixels.

The simplest initial rescan path is fresh Auto with the corrected fixed profile. Supporting recognition on manually remapped or reduced systems is a separate extension: detectors must accept the validated reviewed page plan/overrides; their current internal `plan(pages:[page],profile:profile)` ignores overrides and deliberately rejects requiresSystemAssignment pages. Never bypass this by clearing the variable-layout flag.

On rerun, recognition metadata must replace its own previous result rather than append. If supporting in-place rescans later, snapshot the reviewed system/candidate map and only publish if it is unchanged; source/rectification equality alone is insufficient.

### Current output limits remain visible

- Endings and system bar-number propagation are not provided by these detectors. KV498 lower parts still lack first/second endings.
- Current heading rectangle containment can duplicate an already visible source-owner label due solely to padding (KV498 Clarinet Rondo; Ave also has equivalent local labels). Finish the independently reviewed dedup work before presenting the option as polished.
- Copied heading envelopes can include slur fragments. Navigation/destination glyph matches preserve source pixels but do not establish the full semantic repeat itinerary.
- Heading copying currently runs only for automaticPage. If reviewedPage begins automatic heading propagation, use authoritative override lists and idempotence checks, and verify the first staff of the reviewed system is still the validated heading anchor.
- Automatic rest compression runs after apply (`ScoreExtractionView.swift:1127`). The existing rest flow protects copied marks farther right than its retained prefix (`PartsmithDocument.swift:1543–1546`); keep that rule. A new direction must not vanish through rest compression.

## Required validation before app release

Existing tests already cover planning, direct shared-heading/navigation selection, source-linked glyph fixtures, review initialization, normal Auto background/cancel/stale behavior, source-mark persistence, undo and export. They do not yet exercise the combined app recognition pipeline.

1. **Deterministic orchestration:** inject a recognizer/runner similar to RestAutoBandRecognizer. Assert opt-out makes zero OCR calls and identical plans; opt-in preserves source page indices, candidate arrays and correct selected scope; glyph matching waits until all instruction templates are available. Assert skipped layout is distinct from no match and failure.
2. **Cancellation/staleness per phase:** cancel during headings, navigation, template collection and destination scan; start a replacement run; mutate source/rectification and assignment map. No partial review/project mutation, stale warnings or stale completion. Test progress ownership and window-close cancellation.
3. **Failure without acceptance barrier:** injected Vision/render failure retains base staff/crop results, exposes the correct page/stage issue, does not claim zero successful matches, and leaves Add Parts governed by original plan validity. The CLI's strict fail-before-write behavior remains separate.
4. **Review edits:** source-mark box selection; per-recipient Remove survives unrelated crop edits, replan, reset, apply and undo; legacy nil override permits fresh propagation; explicit empty array suppresses it; reassignment invalidates old page ownership/copies instead of moving or dropping a mark silently.
5. **Coordinate and persistence path:** real rectified Brahms source at proven OCR resolution; apply/save/reopen/undo/redo/export keeps corrected source rectangles and above/below placement. Include input subsets and mixed above/below rows; no cross-system collision.
6. **End-to-end real outputs:** KV498 five frozen heading words; Ave complete figures and duplicate checks; Brahms instruction+linked symbols. Review all changed pages and page-count consequences, with frozen source guards and explicit unresolved endings/bar-label obligations. Validate rest compression with copied opening versus internal directions.
7. **Packaged app smoke test:** run actual local Vision OCR from the built app, offline, while moving/resizing/closing Auto. The earlier sandboxed CLI failed before recognition; successful unsandboxed CLI results alone do not establish app-runtime availability. The inspected Xcode project contains no explicit sandbox entitlement setting, but runtime verification is still required.

This is a bounded feature addition, but the removal and assignment invalidation tests are prerequisites. If they cannot be completed this turn, leave recognition CLI-only and retain this plan for the next app change.
