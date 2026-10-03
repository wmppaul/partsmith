# Direct symbol contacts and three-head shafts: prospective addendum

**V1 fails this source-ownership challenge.** A pp-shaped dynamic touching a structural barline is misread as two hollow heads sharing a musical shaft. At scale 1, it emits one false interval and causes two crops to include a complete neighboring staff. The three-head musical shaft also remains incomplete for its outer owners.

This small addendum is explicitly informed by inspected V1 code and its original 29-case results. Its three source images, ownership masks, expectations and metrics were frozen before these addendum results and before a combined candidate. It is not blinded evidence and does not alter the original suite. Protocol SHA256: `45cf50a72c236247bdd0cd440b57b82446cfaab59b1f7aeedf6299215a002bc7`; input manifest SHA256: `3cae7888ada1cbd4c06741dd300c9f9bd881965c13f99e55392c7e09eb6abc6d`.

The six source/scale cases contain 18 owner observations. The pp collision has visible companion letters, upright strokes and descenders. The flat collision has tall ascenders and separate following stemmed notes. These are deliberately difficult synthetic contacts with genuine distinguishing context, not byte-identical musical positives assigned different labels. The third source has three actual filled heads on a broken shared shaft, and each original owner requires all 1,625 source pixels of that shared notation. All sources were viewed before execution.

| Finding | Result |
| --- | --- |
| Newly lost source pixels relative to baseline | 0 |
| Complete owner observations | 12/18 → 14/18 |
| Three-head owners fully recovered | 2/6 (middle owner at both scales) |
| New false shared-span observations | 1/4 negative source/scale cases |
| New whole-neighbor owner observations | 2 |

The pp false interval is [487, 195, 505, 558], with owners [1, 2]. Both fitted bodies are labeled hollow. The bare source barline is structural; its local glyph bowls do not establish cross-staff musical ownership. The scale 0.5 pp case and both flat cases emit no new spans. Raw internal witnesses are recorded, including every candidate body and source gap; logging-only results match the uninstrumented output exactly apart from elapsed time.

The three-head case emits adjacent intervals [0, 1] and [1, 2]. The middle owner covers all three heads, but the outer owners still lose 631/565 pixels at scale 0.5 and 637/577 at scale 1. These are improved but still incomplete crops; aggregate preservation gains do not satisfy the source-defined full-span obligation.

`comparison.json` preserves every newly lost/recovered pixel set, remaining loss, source envelope, spurious neighbor and raw span. The frozen native executables were reused from the [independent original suite](../musical-span-independent-2026-10-03/candidate-v1/README.md); their hashes and full source snapshot bindings are retained. Measured evaluation times were 0.046 seconds baseline and 0.022 seconds candidate for these six cases; no performance conclusion is drawn from such short runs.

The original 29-case inputs and all existing real-source guards remain unchanged. No new classifier threshold, production change or output publication was attempted. Full inputs and ownership masks are in `source-inputs-and-harness.zip`.
