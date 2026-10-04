# Unchanged attached-symbol and three-head addendum: V2

V2 rejects the pp-derived false musical span seen in V1, but three-head preservation remains scale-dependent. No source, mask, ownership obligation or expected outcome changed from the [frozen prospective addendum](../README.md). This remains a V1-informed challenge, not newly blinded evidence.

| Six cases / 18 owners | Baseline | V1 | V2 |
| --- | ---: | ---: | ---: |
| Complete owners | 12 | 14 | 15 |
| Three-head owners fully retained | 0/6 | 2/6 | 3/6 |
| Negative cases emitting spans | 0/4 | 1/4 | 0/4 |
| New foreign whole-core inclusions versus baseline | — | 2 | 0 |

At scale 0.5, V2 accepts all three source heads, emits one interval for owners [0, 1, 2], and retains all 1,625 source pixels for each owner. At scale 1, only two bodies are accepted: the interval belongs to [0, 1], and the three owners still lose 646, 568 and 1,082 pixels. Full three-head recovery therefore fails at that scale. The existence of an all-head union in code does not establish that every real head was identified.

Both pp and flat context negatives emit zero spans at both scales. All twelve negative owner observations remain complete, and the two V1 whole-neighbor additions disappear. Ordinary component multisets are unchanged and every production-baseline alternative remains present. No newly lost baseline pixel is found.

Compared specifically with rejected V1, V2 recovers 1,196 owned-pixel observations at scale 0.5 but newly misses 1,082 at scale 1 across three owners. Exact loss sets are preserved, so the improved aggregate 14→15 complete-owner count does not conceal those losses. Relative to production baseline, 3,998 pixel observations recover with no new losses.

The already compiled V2 observer was reused for one pass over the six unchanged inputs. Raw body footprints, filled disks, explained thin runs, source gaps and owner intervals are preserved in `span-witnesses.json`. Native measured 0.032 seconds including serialization; no performance conclusion follows. The observer-only scope and source/executable hashes are in `bindings.json`; the full frozen/observer Core and evaluator are in the [original-suite V2 evidence](../../musical-span-independent-2026-10-03/candidate-v2/README.md). No separate uninstrumented or real-score replay was performed here.

The original suite's mandatory case176 full recovery also fails in V2. This addendum provides a bounded negative-control improvement, not approval to promote the candidate. V1 reports, existing source guards, production and delivered parts remain unchanged.
