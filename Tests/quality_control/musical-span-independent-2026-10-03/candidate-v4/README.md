# Musical-span V4: unchanged preservation, verified cell-area arithmetic

The unchanged 29-case suite retains V3's complete case176 recovery and introduces no new source losses or false negative-control spans. The new whole-body filledness values independently match the recorded source-cell geometry. This is bounded evidence, not approval to ship or combine classifiers.

Frozen Native SHA256: `ab60944ddeb2bd428329d71877039001f71ca5cae7d24b84ef344310f1f1607d`. Protocol SHA256: `f9bdcca7d003d7cfa8eca803a55f62ba0a4472559cbe55492cd758c00ebe9cae`. V4 adds one fixed condition to V3: source-cell area divided by the continuous convex-hull area of all unit-cell **corners** must be at least 0.82. The local disk gate, source pixels, source paths, seeds and other numeric conditions are unchanged. This criterion was developed after earlier failures; these unchanged examples are not a newly blinded validation set.

| Original 29 cases / 99 owners | Production | V3 | V4 |
| --- | ---: | ---: | ---: |
| Complete owners | 64 | 70 | 70 |
| Case176 owner losses | 970 / 650 / 808 | 0 / 0 / 0 | 0 / 0 / 0 |
| Newly lost pixels versus production | — | 0 | 0 |
| Negative cases emitting spans | 0/12 | 0/12 | 0/12 |

All original case176 owners retain all 1,400 source pixels, including the middle owner's full [218, 190, 609, 539] envelope. The filled positive at scale 0.5 also fully recovers. Filled scale 1 losses remain 1,081 / 1,031 / 994, and the hollow positives remain incomplete. Original four-core failures remain unchanged. V4 gives back the same 3,106 pixel observations relative to rejected V1 as V3 did; exact sets are retained rather than treating aggregate success as complete notation coverage.

No V3-owned pixel is newly lost or recovered: its crop/loss outcomes are preserved. All ordinary component multisets match production and V3, and all production/V3 alternatives remain present. No spurious whole-neighbor inclusion appears. Exactly two spans are emitted in this suite, with all raw body evidence retained even if a component would be deduplicated.

## Independent arithmetic check

`body-area-checks.json` checks all nine accepted body records across the original suite and [six-case addendum](../../musical-span-attached-addendum-2026-10-03/candidate-v4/README.md). It uses a separate gift-wrapping hull implementation; Native uses monotone chain. Both operate on all corners of every unique source pixel's unit square, followed by continuous shoelace area. Four fixed convention controls cover one cell, diagonal cells, a solid block and an L-shaped cell union. Holes are not filled in the numerator.

Every logged ink area, hull area and ratio matches within 1e-12. Case176 bodies each have area 102 over hull area 110 (0.9272727). The two true half-scale endpoint bodies measure 31/37 (0.8378378) and 33/38.5 (0.8571429). All nine pass the fixed 0.82 gate. Removing the three new area fields leaves all recorded V3 body/span evidence exactly unchanged.

The original source/disk checks also pass: disks lie within their recorded footprint/shaft union, centers remain offshaft, and restored shaft pixels stay inside observed attachment rows. All four full-resolution bodies are independently checked against exact original source bytes. Half-scale geometry is checked, but threshold pixels were not independently rerendered; that scope remains explicit.

Each unchanged suite ran once using the logging-only observer. It adds case labels and serialization of returned span records, with no classifier edits. Full frozen Core, observer patch, executable hash and comparison/area-check scripts are preserved. There is no separate uninstrumented duplicate execution. Original 29-case time was 0.149 seconds including serialization and excluding compilation; this is not an application responsiveness guarantee.

This reviewer did not duplicate the author's standalone case176/four-core or six real-page runs, and did not execute a new full score. Parent-owned real-score results and any later combined algorithm require separate evidence. All previous reports, source masks, known p35 guard failure, production and delivered outputs remain unchanged.
