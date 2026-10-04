# Numbered-line envelope compatibility: independent preservation gates pass

The narrow candidate passes the unchanged independent gates: **no newly lost source-owned pixel, no new whole-neighbor inclusion in the 297 grid, all 336 source envelopes retained, and exact baseline loss sets in the separate 29 + 6 cases**. All 27 junction separation negatives stay free of whole-neighbor inclusions. This supports proceeding to real-score review; it is not release approval or a claim that existing omissions are solved.

Native SHA256 is `e32b5a76928b505efbeba6fa5bc9aef4b58ed0e2b7d11ddeef3269b73570996f`; author protocol SHA256 is `caced5d8a638510b906541cd02fb23141ac04582ecf6e9e37a318a088691de2f`. The independent protocol, exact observer and source bindings were frozen before this run. This candidate uses numbered-line V2 plus conservative preservation of older single-owner component envelopes. It contains **none of the rejected source-span V1–V4 inference**.

| Unchanged suite | Production baseline | Narrow candidate |
| --- | ---: | ---: |
| 297 fully preserved cases | 238 / 297 | 238 / 297 |
| 297 complete owner masks | 732 / 891 | 732 / 891 |
| 297 omitted original pixel observations | 88,821 | 88,809 |
| 297 newly omitted source pixels | — | 0 |
| Junction negatives gaining a whole neighbor | 0 / 27 | 0 / 27 |
| 336 fixed source envelopes | 336 / 336 | 336 / 336 |
| Original 29 complete owners | 64 / 99 | 64 / 99 |
| Prospective six-case addendum complete owners | 12 / 18 | 12 / 18 |

## Exact source comparison

The 297 constructor, source transforms, raster scales, original owner masks and logging-only evaluator are byte-identical to the earlier independent run. Its baseline previously reproduced every original production result field exactly; that source-bound result and all exact pixel-loss sets were reused, without another native baseline run. Candidate raw image hashes, all 891 owner-mask hashes and owned source index sets match it. Loss comparisons include already failing cases and use complete original source-pixel cells, not aggregate success or classifier-generated ownership.

No baseline-retained pixel is newly omitted. Twelve source pixels recover in case170, middle owner: `edgeMusicBroken`, scale 0.5, tilt 1.5°, bow 10. Its top crop changes from 216 to 212 source pixels, reducing loss from 641 to 629. Its full original envelope is still not retained.

Case176 now retains exactly its production coverage: owner losses remain **970 / 650 / 808**, including the middle crop's top at 212. The earlier numbered-line V2 regression had moved that edge to 215 and lost nine additional original pixels. This candidate prevents that regression by retaining historical single-owner support; it does **not** claim full shared-musical ownership or complete case176 recovery.

No one of the 297 cases increases its whole-neighbor count. Eight cases reduce that count, and total relations change from 398 to 386. All 27 `headAtJunction` cases remain at zero. Thirty-eight owner crop rectangles change, so the result is not simply unchanged output. All 336 immutable source envelopes and upper-target guards survive; 147 of their records change.

Only after these gates passed were the unchanged original 29 cases and six-case addendum run, once each. Their loss sets exactly equal their production baselines: 18,018 and 6,294 missing pixel observations respectively, with no recovery or new loss. No new spurious whole-neighbor relation appears. Existing four-core, filled/hollow musical-span and three-head failures remain explicit. The candidate has no source-span helper or emitted span records; the raw component lists are retained instead.

## Representation and limits

The added support matches old and new connected components using actual black pixels at the same coordinates. The old component must have exactly one owner, at least one new child must retain that same sole owner, and any new owner-bearing child must have exactly that owner. Unowned children are allowed without assigning them an owner. A qualifying older vertical envelope is added as an outward-only ownership alternative. Multi-owner or conflicting children abstain.

Static comparison to frozen numbered-line V2 shows the addition of this support pass and final flagged supports; existing mask/structural decisions and ordinary component construction are unchanged. Exact ordinary-component equality to V2 was not independently replayed because that older 297 result has only counts, not complete component lists. Relative to production, numbered-line cleaning changes ordinary geometry in 248 of 297 cases and replaces some old alternative records. Those changes are recorded rather than mislabeled invariant. Independent source-loss comparison is the tested preservation claim.

Historical support can include staff-line residue; it is not a new proof that such extrema are music. These bounds do not guarantee clean output, identify omitted target staves, repair all preexisting omissions, or establish complete musical ownership. The rejected combined candidate and its 27 junction failures remain separately frozen and are not reinterpreted by this result.

## Execution and archive

The candidate ran each of 297, 336, 29 and six cases once. No source fixture, oracle, mask, threshold or expectation changed. A postprocessing syntax typo was corrected without rerunning native detection. Compiler/run logs, exact results and loss sets, full candidate Core, unchanged constructors/evaluator, source/input hashes and executable hashes are in `evidence.zip`; every payload is bound by `archive-manifest.json` and was verified after packaging.

Measured native wall times for 297 and 336 were 9.38 and 9.27 seconds under concurrent testing; the earlier production 297 baseline was 3.62 seconds. The smaller native runs took 0.439 and 0.084 seconds. These are observations under different concurrent workloads, not isolated speed ratios or responsiveness guarantees. Peak memory was not instrumented by this independent run. The additional run/component storage therefore needs real application measurement as part of broader evaluation.

Source inputs for the smaller suites remain in the separately frozen [original study](../musical-span-independent-2026-10-03/README.md) and [addendum](../musical-span-attached-addendum-2026-10-03/README.md); all their manifest entries were reverified. The author owns permanent 796 and original four-core checks; the parent owns the subsequent 39-page source replay. This reviewer did not duplicate those runs or modify production, PDFs, projects, source corrections or guards.
