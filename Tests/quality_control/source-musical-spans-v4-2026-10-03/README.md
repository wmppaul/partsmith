# Original-source musical spans V4 — bounded preservation layer

V4 retains full case176 recovery, rejects the previously observed crossing/slur/glyph/fermata false intervals, and leaves every component multiset and crop unchanged in the complete39-page corrected Brahms replay. This supports a separately controlled experiment with numbered-line cleanup. **It does not establish robust note identity, complete musical recall, or improved real-score crops by itself.** Production remains unchanged at this freeze.

Frozen Native SHA: `ab60944ddeb2bd428329d71877039001f71ca5cae7d24b84ef344310f1f1607d`. Protocol SHA: `f9bdcca7d003d7cfa8eca803a55f62ba0a4472559cbe55492cd758c00ebe9cae`. All prior rejected versions and source masks remain immutable.

## Added whole-body gate

V3's source paths, full footprint, original shaft restoration, local filled disk, attachment geometry and connected-head ownership remain unchanged. V4 adds one rejection condition: the whole measured body's ink area divided by its convex-hull area must be at least0.82.

The numerator counts unique original unit pixel cells in the residual footprint plus the same actual body-shaft pixels admitted by V3. The denominator is the **continuous area of the convex hull of all four corners of those cells**, computed by sorted monotone chain and integer shoelace/2. It is not a pixel-center lattice count, bounding-box fraction or hole-filled raster. Witnesses retain inkArea,hullArea,solidity alongside all previous exact source evidence.

The0.82 value is fixed for this version, carried from the earlier filled-body criterion and applied here to a complete measured shape. This was proposed after source diagnosis: p10, case176 and the half-scale heads are development evidence, not new blinded holdouts. No threshold changed after V4 results. The gate is conservative filled recognition; compact filled glyphs can remain ambiguous, while faint, hollow or damaged genuine heads can still abstain.

## Results and limits

| Frozen evidence | Result |
|---|---|
| Exact case176 | All three original source envelopes/pixel masks recovered |
| Original36 four-core cases/144 owners | Same losses as production;68 incomplete owners remain |
| Independent29 source observations/99 owners |70 complete; no new baseline/V3 lost pixels, ordinary changes, removed alternatives or negative spans |
| Addendum6/18 owners |15 complete; pp/flat false intervals absent; full-scale three-head source remains incomplete |
| Six targeted real pages, includingp10 | Component multisets and plans equal production; all known false intervals absent |
| Root fresh39-page/604-band replay | Zero added/removed components, unchanged staff geometry, zero changed crops, zero new spans |

The independent [29-case report](../musical-span-independent-2026-10-03/candidate-v4/README.md) and [six-case addendum](../musical-span-attached-addendum-2026-10-03/candidate-v4/README.md) preserve the remaining full-scale filled/hollow and three-head failures. These misses were not waived. This standalone version has not undergone the full796/297/336 composition checks; those belong to a separately frozen combined candidate.

All nine accepted body records were independently recomputed using a separate gift-wrapping hull implementation over unit-cell corners. Logged values match exactly: case176102/110=0.9272727; genuine half-scale examples31/37=0.8378378 and33/38.5=0.8571429. Previous body bounds, original pixels and other witness fields are unchanged fromV3. The rejected p10 arches had whole-shape fractions near0.50, as measured before this version; their local disks alone had been misleading.

## Complete real-score replay binding

Root executed the unchanged39 rasters, including the same nine saved rectifications at their existing scale. `full39-inputs.json` binds them; no higher-resolution or new rectification experiment is mixed in. The fresh native replay uses the exact frozen V4 source and the unchanged reviewed profile. Its complete16MB JSON result is included compressed in the archive, together with root's pre-result protocol, build/run log, replay source and comparator. Root's6.09s Release process timing is recorded; it is not a UI responsiveness guarantee.

The baseline inventory SHA is `db454e569c263318907464b23b6d53817bfbcc66c506f07cbf148484614b7c7d`; V4 result SHA is `3064c1afdf49b0190f16b563030563a787d36b7bab77163c9c621e56c9c5860a`. Exact component multisets are compared rather than unstable array order. Existing bad crops remain bad because this preservation layer creates no new interval on these39 pages. A zero-difference replay is a regression result, not a clean-part quality certificate.

The archive preserves the six compiled dependencies, exact control constructors, results, source hashes and whole39 replay. Rebuildable binaries and duplicated full-page rasters are omitted; the binary/input hashes are still bound. All archive members were verified. No source obligation or production file changed.
