# Original-source musical spans: independent V1 evaluation

**Keep this candidate private.** The original frozen suite proves a useful broken-stem recovery without new losses, but separate source-reviewed challenges and real Brahms pages show unsupported shared ownership that adds whole neighboring staves. No production file or delivered part was changed.

The original blinded input set remains 29 source/scale cases and 99 owner observations. Its protocol/input hashes are in `bindings.json`; the source images and original masks remain in the parent report’s frozen archive. Baseline and candidate use the same unchanged evaluator and planner. Candidate Native SHA256 is `00749e09b47ed1740feeab4d53aa77e7ce17658edb3d5a0f81fe60a51bf81fe1`.

| Original suite | Baseline | V1 |
| --- | ---: | ---: |
| Complete owner observations | 64/99 | 73/99 |
| Newly lost owned pixels | — | 0 |
| Recovered owned-pixel observations | — | 8,370 |
| Remaining lost owned-pixel observations | 18,018 | 9,648 |
| New spurious whole-neighbor observations | — | 0 |
| Negative source cases emitting new spans | 0/12 | 0/12 |

The exact original case176 fully recovers all three owners, each containing 1,400 original source pixels. The middle owner covers its full [218, 190, 609, 539] envelope. This is full recovery, not only restoration of the nine pixels lost by the rejected numbered-line V2 experiment. The filled broken shared-shaft example also fully recovers all three owners at both scales. The hollow version remains incomplete for all six owner observations, and the original four-core sources keep their 20 existing failures. Nothing was removed from the oracle to obtain these results.

A separate logging-only snapshot records every raw source-span witness, including records that might otherwise disappear during component deduplication. Its results are semantically identical to the uninstrumented run after excluding elapsed-time fields. Exactly three spans are emitted: case176 and the filled positive at both scales. None is emitted for the twelve negative source/scale cases or twelve original four-core sources. Full witness bodies, source intervals, source gaps and owner IDs are retained under `witnesses/`.

Native evaluation measured 0.148 seconds for the baseline and 0.152 seconds for V1, excluding compilation. These tiny local measurements are not app-performance guarantees. Both whole Core snapshots are archived; the baseline is in `../baseline/`. Only Native differs among the six compiled Detection inputs. An unrelated `ProjectModels.swift` arithmetic-parentheses difference is recorded because whole Core was captured, but that file is not compiled in this evaluator.

The separate [prospective attached-symbol addendum](../../musical-span-attached-addendum-2026-10-03/README.md) was informed by V1 and explicitly frozen before its own results. It finds one false pp-derived span, two new foreign-core inclusions, and incomplete distant-head preservation in a three-head shaft. It does not change or retroactively enlarge this blinded suite.

The [independent real-source review](real-source-review/README.md) inspected five source contexts and all sixteen fitted-body boxes from the parent’s full 39-page replay. Eight false spans expand 13 crops; ten crops acquire complete foreign cores, with 14 new crop/core relations. Ordinary staff/barline crosses, slur intersections and terminal corners are wrongly accepted as filled or hollow heads. This source evidence independently rejects promotion despite the useful synthetic recovery.

No broad recall claim, clean-part claim, source-guard adjustment or production integration follows. Existing p35 guard failure and other baseline crop defects remain explicit. All frozen input hashes were reverified after evaluation; the manifest and archive member hashes bind the evidence.
