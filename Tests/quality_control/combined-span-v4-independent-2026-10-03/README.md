# Combined numbered-line V2 + musical-span V4: preservation passes, ownership regression

This private candidate is **not eligible for promotion**. It retains every fixed source-owned pixel in the original 297-case grid, but wrongly joins local instruments in all 27 preexisting `headAtJunction` cases. Their 84 additional whole-neighbor inclusions are a crop-quality regression. No fixture, ownership mask, production file, delivered PDF or project was changed.

Frozen Native SHA256: `87e515434e671bc11f7c304342112401fcd0fc3d800015b8f93f7b29ab013487`. Candidate protocol SHA256: `e2a31249983f182093c4eec093b36f942c1ab796fd6da3be7ed9bfa216ed767d`. The independent protocol and source bindings were frozen before execution. This is a separately tested composition; the older aborted V3 composition was never run by this reviewer.

| Unchanged suite | Production baseline | Combined result |
| --- | ---: | ---: |
| 297 cases, complete source envelopes | 238 / 297 | 297 / 297 |
| 297 cases, complete owner masks | 732 / 891 | 891 / 891 |
| Source-owned pixel observations omitted | 88,821 | 0 |
| 336 fixed musical source envelopes | 336 / 336 | 336 / 336 |
| Original 29 cases, complete owners | 64 / 99 | 70 / 99 |
| Prospective six-case addendum, complete owners | 12 / 18 | 15 / 18 |

Every original 297 result field was reproduced exactly by the new baseline observer after removing only its extra logging fields. The unchanged source constructor, transforms, scales, analysis calls and crop planner were used. Candidate source bytes, all 891 mask hashes and source pixel-index sets match that baseline. Loss is measured using complete original pixel cells, not just a new component envelope or aggregate pass count. All 88,821 previously omitted pixel observations recover and none are newly lost, including within formerly failing cases. Case176's original raw source, three owner masks and baseline loss sets independently match the earlier frozen oracle; all three full 1,400-pixel masks now survive.

The 336 constructor is byte-identical to its frozen predecessor. All fixed envelopes and upper-target guards survive; 147 result records change. Its original baseline was reused without another native run.

## The failed ownership distinction

[Original source for case202](case202-original-source.png) was reconstructed only for display from the unchanged constructor and logged original owner pixels; its raw image SHA256 exactly matches the executed input (`75cc3c790e03a49c2d1541cabd1e813fc1acf4d542a686735d4d57087c74bfab`). It was viewed before the [three baseline/candidate crop comparisons](case202-crop-comparison.png).

The frozen constructor assigns each of the three local heads and short stems to its own staff. The long connecting barline is structural. Candidate case202 adds one ownership alternative spanning source `[590, 200, 604, 508]` for all three staffs. Vertical crops change from `[140, 241]`, `[292, 391]`, `[442, 534]` to `[140, 514]`, `[182, 514]`, `[182, 534]`. No source pixel was previously missing in this representative case; two complete foreign staff cores and substantial additional neighboring notation now appear.

All 27 junction variants gain between two and four whole-neighbor relations, totaling 84. The combined candidate also repairs 24 source pixel observations in three previously incomplete junction variants; the other 24 already preserved all owned source ink. That small preservation gain does not erase the separate ownership regression. The original expectations are unchanged.

A genuine shared-musical fixture such as case176 explicitly owns the entire head-to-head shaft for all three parts. Junction fixtures instead own local head/stem segments and leave the connecting structural shaft unowned. Both appear as connected, solid head-bearing vertical paths. The raster alone can be ambiguous, so source-path connectivity and notehead solidity do not establish shared musical ownership. This report does not propose a new scalar cutoff or relabel the fixed oracle.

Across the entire 297 grid, 90 cases gain whole-neighbor relations: these 27 junction cases plus 63 cases with genuinely shared source ownership. Positive per-case increases total 320 relations (84 junction, 236 shared-owner music), with nine reductions elsewhere; total neighbor relations change from 398 to 709. Full per-kind counts and exact source loss sets are retained. Extra width in shared-owner cases is distinguished from the local-owner negative rather than treated as a universal error.

## Separate 29 + 6 controls and remaining misses

The unchanged original 29 cases and six-case addendum each ran once with the same logging-only case/span observer used for V4. Their exact owner loss sets and raw span/body witnesses equal standalone V4. No new source loss or spurious whole-neighbor inclusion occurs in these smaller suites, and none of their 16 negative source/scale observations emits a span. The new 297 result demonstrates a limitation absent from those smaller negative controls.

Known misses remain: the original suite has 29 incomplete owners, including existing four-core targets, hollow-head cases and full-size filled-head cases. The full-size three-head addendum still loses 646 / 568 / 1,082 source pixels; its half-scale counterpart succeeds. Hollow recognition remains outside this classifier's claim. Passing the 297 grid is not a claim of complete musical preservation on all source shapes.

Unlike standalone source-span V4, numbered-line cleaning changes ordinary components and some old alternative geometry. This is recorded explicitly: 248 of 297 cases change ordinary component multisets and 25 replace at least one old alternative record. All 35 smaller cases also change ordinary multisets, with one alternative replacement in each suite. No component-invariance claim is made for the composition; every original-owned pixel is checked independently.

## Reproduction and evidence

`evidence.zip` contains both frozen full Core snapshots, the logging-only observer, immutable constructors, baseline and candidate raw results, exact source/loss sets, scripts, compiler/run logs, executable hashes and reused-result bindings. Its `archive-manifest.json` binds every archived payload. Existing smaller-suite source inputs remain in the separately frozen [original 29-case study](../musical-span-independent-2026-10-03/README.md) and [six-case addendum](../musical-span-attached-addendum-2026-10-03/README.md), whose manifests were reverified before execution.

The 297 baseline and candidate each ran once; candidate 336 ran once; candidate 29 and six-case addendum each ran once. The latter use returned-span serialization only, with no duplicate uninstrumented run. Native 297 wall times were 3.62 seconds baseline and 8.71 seconds combined; 336 took 8.37 seconds under concurrent compilation/testing. Small-suite native times were 0.463 and 0.083 seconds including logging. These are local observations, not app responsiveness guarantees.

This reviewer did not duplicate the author's permanent 796 checks, original four-core run or parent's full-score replay. The parent is evaluating the real 39-page score diagnostically after this rejection; that run cannot erase these unchanged negative outcomes. Prior V1–V4 reports, source guards and the known p35 guard failure remain unchanged.
