# Musical-span V2: mandatory recovery gate fails

**Do not promote V2.** It rejects the attached pp false positive, but it no longer recovers the exact original case176. No new source pixels are lost relative to unchanged production in this bounded suite; that preservation property does not satisfy the required complete recovery.

Frozen Native SHA256: `08ef2cc99337e104d646a1ded1d7b5dc63819b9735a511192d74570e41fff6d8`. Candidate protocol SHA256: `2c1caa954c2b2fe718b83986b69445915700adbd6f7ca4a0b2eb9b878d14050b`. The original 29-case/99-owner suite, source masks, expectations and baseline are unchanged. V1 remains separately frozen.

| Original 29-case suite | Production baseline | Rejected V1 | V2 |
| --- | ---: | ---: | ---: |
| Complete owner observations | 64/99 | 73/99 | 67/99 |
| Case176 owner losses | 970 / 650 / 808 | 0 / 0 / 0 | 970 / 650 / 808 |
| New lost pixels versus production | — | 0 | 0 |
| Negative observations emitting spans | 0/12 | 0/12 | 0/12 |

V2 emits exactly one span in this suite, for the filled shared-shaft source at scale 0.5. All three owners in that case recover, accounting for 2,836 recovered owned-pixel observations. The scale 1 version remains incomplete, as do the hollow positives. Case176 emits no span; its middle owner still loses 650 of 1,400 original pixels. Its full [218, 190, 609, 539] envelope is not retained. The mandatory full-recovery obligation was not weakened after this result.

All ordinary component multisets are exactly equal to baseline and V1. Every pre-experiment production ownership alternative remains present. V1-specific source-span alternatives are intentionally replaced by V2; exact comparisons record which disappear. Against V1, six owner observations lose its recovery, totaling 5,534 newly missing owned-pixel observations. These losses are relative to the rejected experiment, not a regression in the unchanged production baseline. Exact sets are retained in both comparison files.

The [unchanged prospective addendum](../../musical-span-attached-addendum-2026-10-03/candidate-v2/README.md) confirms that pp and flat context negatives emit no spans. Three-head recovery is complete at scale 0.5, but remains incomplete at scale 1 because the lower body is not accepted. No blanket claim that all three-head notation is fixed follows.

Each suite was executed exactly once using a private logging-only copy of the frozen Core. The observer adds one serialization of returned `SourceSpanWitness` records immediately before unchanged insertion; the evaluator adds case labels. The full frozen Core, observer source, minimal logging patch and harness are archived. Only Native differs in the observer snapshot. No classifier, crop, input or expectation is edited. There is no separate uninstrumented V2 rerun or claim of measured equality to one. Original source input hashes and all previous report manifests were verified unchanged after execution.

The synthetic V2 run measured 0.196 seconds, including witness serialization and excluding compilation; this is not an app-performance guarantee or a directly comparable uninstrumented benchmark. Build succeeded with an unused-local-variable warning, retained in `build.log`. This reviewer did not rerun the author's standalone case176/four-core tests or five real pages, and did not run a new whole score. All existing real source guards, including the preexisting p35 failure, remain untouched.

V2's source-footprint distinction demonstrates a useful rejection on these synthetic negatives, but the required real motivating preservation gate fails. Results are archived without retuning. Production, application bundles and delivered parts remain unchanged.
