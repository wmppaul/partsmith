# Musical-span V3: full case176 recovery, bounded remaining misses

**V3 passes the mandatory case176 recovery and the unchanged synthetic negatives.** This is a bounded independent result, not approval to ship or combine classifiers. The full-resolution filled and three-head examples still have incomplete ownership, and hollow examples remain unsupported.

Frozen Native SHA256: `6f8a9200324702cc6579dba7455e7c6a0e2686cf6ab1e4606309d48e9196010c`. Candidate protocol SHA256: `10761c23ed286b161835cfef75aa1a8367817fcac731b7b661022f71a3c4ab6e`. V3 changes only the thickness-test membership: actual black shaft pixels inside a detected body's observed attachment-row interval join its existing offshaft footprint. Disk centers still lie in the original offshaft footprint. No input, threshold, source mask or expected ownership changed.

| Original 29-case suite | Production | V1 | V2 | V3 |
| --- | ---: | ---: | ---: | ---: |
| Complete owner observations | 64/99 | 73/99 | 67/99 | 70/99 |
| Case176 owner losses | 970 / 650 / 808 | 0 / 0 / 0 | 970 / 650 / 808 | 0 / 0 / 0 |
| New lost pixels versus production | — | 0 | 0 | 0 |
| Negative cases emitting spans | 0/12 | 0/12 | 0/12 | 0/12 |

Both original case176 bodies are recognized, with source interval [593, 190, 609, 539] assigned to all three owners. Each owner retains all 1,400 original pixels, including the complete middle-owner envelope [218, 190, 609, 539]. The filled shared-shaft example at scale 0.5 also fully recovers. These six complete owner recoveries total 5,264 recovered pixel observations versus production. V3 adds the 2,428 case176 recoveries to V2 without losing any V2-owned pixel in these tests.

The filled scale 1 source still loses 1,081 / 1,031 / 994 pixels; the hollow positives remain incomplete. Against rejected V1, those filled scale 1 owners give back 3,106 pixel observations. Those are retained as exact loss sets, not concealed by the recovered case176 or aggregate counts. Original four-core failures are unchanged.

All ordinary component multisets equal production, V1 and V2. Every production and V2 ownership alternative is retained. No new spurious whole-neighbor core appears, and none of the twelve original negative source/scale cases emits any span, including deduplicated internal records.

The [six-case addendum](../../musical-span-attached-addendum-2026-10-03/candidate-v3/README.md) is unchanged in crop/loss outcomes from V2: pp and flat contacts remain negative, three-head recovery is complete at scale 0.5, but incomplete at scale 1. A successful full-interval union cannot compensate for a missed endpoint head.

`body-membership-checks.json` independently validates all nine emitted body records across both suites: each disk is completely covered by the recorded footprint/shaft union, its center lies offshaft, restored shaft pixels remain within observed attachment rows, and recorded footprint bounds are exact. All four full-resolution bodies are checked against the unchanged original source bytes. Case176 has 78 original offshaft pixels plus exactly 24 original black shaft pixels per head, with no invented ink. Half-scale records pass geometry/union checks; their thresholded source pixels were not independently rerendered, and that limit is explicit.

Each suite ran exactly once using the same logging-only observer mechanism as V2. The observer only serializes returned span records and evaluator case labels. The full frozen Core, observer patch and unchanged harness are archived. No separate uninstrumented native run is claimed. Elapsed time was 0.161 seconds for the 29 synthetic cases, including serialization and excluding compilation; it is not an app responsiveness guarantee. The unused-local-variable compile warning is retained.

This reviewer did not duplicate the author's standalone case176/four-core or five-real-page runs, and did not run a new whole score. All old reports, source inputs and real guards were reverified unchanged. Further integration requires separately frozen combined-source evidence and real-score review; production and delivered parts remain untouched by this evaluation.
