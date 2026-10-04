# Literal scale, gap and alignment regression review

The independent reviewer updated the existing layout and native scale/export harnesses to the requested behavior. All 7,157 layout assertions and 411 native export checks pass. The tests retain strict aspect, source-order, vertical-layout and complete-source pixel checks while replacing the old enforced width cap and automatic gap reduction with checks for requested enlargement, visible overflow metadata and literal spacing.

Coverage includes exact gaps from 4 through 200 points with balancing on/off; linear 1.3× to 1.4× growth; common source-position alignment with unequal ink envelopes, narrow stored crops and translated PDF page boxes; saved settings and Undo; copied markings and rests; separate bar-number rows for oversized music; visible ink within margins and clipping at physical page edges; native preview/export parity. One crop taller than a complete page still fits vertically.

The reviewer made no production edits. Source hashes bind the checked production code and two test files, and logs preserve final results. Root copied this compact receipt unchanged from the private review folder. Actual Brahms source/output comparison and the native Inspector review are recorded separately.
