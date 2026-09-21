# Planner performance validation, 2026-09-20

The updated release CLI plans the 39-page rectified Brahms IMSLP93521 inventory in **1.27 seconds wall time**, producing 604 bands, automatically excluding the cover, and leaving no unresolved pages. Its complete plan equals the frozen reference plan with the same cover exclusion, including all warnings and ordering.

## Measured bottleneck and change

The 15 MB inventory contains 68,940 components and decoded in 0.37 seconds. An instrumented reference planning pass took 69.84 seconds. The detached-high-mark search accounted for 68.44 seconds (98%): it compared components 558,042,038 times and repeatedly allocated ownership sets. A five-second native CPU sample independently showed the planner spending its time in those Set allocations and releases.

The target staff IDs, first line and staff spacing are constant throughout one band's crop calculation. The optimized planner therefore selects connected high target ink once per band, then runs the same overlap and distance predicates against that subset. All preservation thresholds, propagation passes, ownership rules, ambiguous-ink handling and warnings are unchanged.

The same instrumented fixture then took **1.89 seconds**, with 814,577 high-target comparisons. Its encoded complete plan was byte-identical to the reference (SHA256 `58736df7c2a40c4b3d2733d6d3b9f07db94f48737c60a8abb55ddf066dd3794f`). This is approximately 37 times faster for that measured pass.

The app, batch planner and exporter previously built a plan and then immediately rebuilt it when automatically excluding pages without staves. `ScoreDetectionReview.initial` now establishes those exclusions before the first plan. It retains every analysis and stored override, so restoring a page behaves as before. Failed page renders remain unresolved. The app still rejects canceled callbacks. Shared-heading metadata and the copy helper were retained unchanged; this performance change does not enable heading recognition in the app.

## Equivalence and regressions

Every one of the 36 corpus entries is accounted for:

- All **20 available profiles** matched the frozen reference exactly across **578 pages and 6,230 bands**. Comparison used complete `Equatable` plans and encoded JSON, including warning order, bounds, source markings, labels and part order.
- Fifteen of those profiles produced bands. Five variable-layout profiles correctly retained their unresolved zero-band results.
- Sixteen inputs lack initialized profiles and are explicitly recorded as not evaluated for planner equality.
- Fresh native analysis of the newly recovered Mozart86903 page 25 (20 staves / 16 bands) and Frauenliebe51733 page 14 (15 staves / 10 bands) also produced exact reference/candidate plans, with both plans ready to apply.
- **63** new initial-review tests passed, including sparse page scope, source header/data/rectification identity, failed-raster retention, saved override restoration, global validation after filtering, and cancellation.
- Existing suites passed: **139** whole-score document assertions, **83** planner checks and **82** crop-quality checks.
- A separate read-only review found no concrete factory issue. `git diff --check` passed.

The machine-readable record is `planner-performance-validation.json`. Scratch snapshots, the native CPU sample, reference/candidate plans, comparator and per-source timings are under `.build/planner-perf/`. Source, executable, inventory and profile hashes are recorded. The reference snapshot includes the in-progress shared-heading metadata/helper; those definitions were not changed by this optimization.

Timings are local measurements, not portable test budgets. Plan equality preserves prior behavior and does not establish musical correctness, resolve variable instrumentation, or validate final part output.

Focused regression commands:

```sh
bash tools/test_review_initialization.sh
bash tools/test_score_document.sh
bash tools/test_score_planner.sh
bash tools/test_crop_quality.sh
```
