# Initial-override heading repair and overlapping source blocks

This production candidate repairs the pre-existing omission documented in `../schumann-tempo-recipient-study/OVERRIDE-AUDIT.md`. An unchanged initial staff override with an absent source-marking list now receives the same required heading as automatic planning. An explicitly empty list still means the user removed the copy; an explicit nonempty list is retained. This does not integrate the unfinished Schumann German-tempo/recipient experiment.

## Ownership and original pixels

New recognition records the source page dimensions, physical staff lines, system index, instrument ownership and music/cue kinds in an optional `ScoreHeadingRecognitionBinding`. Automatic heading application requires that ownership to remain identical. An initial override moving a source or recipient to another system, exchanging parts, changing music to cue, or changing staff geometry cannot copy the stale heading. It adds a notice without blocking ordinary crop acceptance. Legacy inventories derive a comparison from the automatic staff assignment before applying the reviewed override. Crop edges are deliberately excluded from the identity: a changed crop with an absent marking list re-evaluates whether the actual heading is already included.

The same planner path handles automatic and reviewed pages. Explicit marking lists remain authoritative. This bounded fix does not reinterpret an explicitly materialized marking as automatic metadata.

Overlapping heading fragments with the same physical anchor and recognition binding are combined only when their original rectangles overlap in both axes. The union retains all padded source edges and both recognized labels; old individual ink measurements are discarded, and the native detector measures the complete union again. Separate vertical events, distinct anchors, different bindings and mere edge contact remain separate. A singleton retains its exact original geometry and ink measurement.

Merged headings store optional original `fragmentBounds`. Later calls—including a decode/replan—test overlaps against these constituents, never the expanded union's empty corners. An empty, malformed or inconsistent constituent list cannot trigger another merge. Existing inventories without this optional field remain readable. This is necessary because native recognition and the planner both invoke coalescing.

Ending suppression and linked-page cleanup recognize both grouped and original heading rectangles. A local ending cannot delete a coincident heading. Keeping the original lookup also preserves previously materialized individual heading copies. The review UI can label the grouped source copy using both recognized heading labels.

## Frozen failures and validation

The historical seven-case oracle remains unchanged in the Schumann study. Its former five failures now pass. The historical report is not rewritten as a success.

The new `tools/test_heading_overrides.swift` contains 57 independent geometric controls: absent/empty/explicit marking lists; legacy and recorded source ownership; source and recipient relocation/kind changes; malformed bindings; unchanged singleton measurements; complete source-block grouping; remote and empty-corner negatives; repeat-call and serialization idempotence; and invalid fragment provenance.

The new `tools/test_heading_categories.swift` adds four focused checks. `grouped-category-before.json` records the two reproduced grouped-heading deletion failures. `grouped-category-after.json` records their repair while retaining the legacy-fragment protection. `repeated-coalescing-before.json` records the two repeated-call/serialization failures before original fragment geometry was retained.

Final results and exact source/test hashes are recorded alongside this report. Existing shared-heading checks, the unchanged seven-case audit and the complete local-ending app regression are run against the final candidate. The ending replay uses the frozen 68-page evidence; it does not claim a fresh Vision scan. Full native recognition and independent source-pixel review belong to the parent's separate heading-block study.

## Reproduce

From the repository root:

```sh
bash tools/test_heading_overrides.sh
bash tools/test_heading_categories.sh
bash tools/test_shared_headings.sh
bash tools/test_shared_ending_app.sh --corpus
```

The original seven-case audit uses its unchanged Swift file under `schumann-tempo-recipient-study`, compiled with the same five lean detection sources listed in `tools/test_heading_overrides.sh`.

This does not add a new OCR vocabulary or recover every separated heading. Horizontally overlapping headings separated by a real vertical gap still encounter the existing single-row placement limitation. Native musical coverage, page layout, and absent-instrument rests remain separate from these override/provenance controls.
