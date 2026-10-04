# Numbered-line V2 plus musical-span V4 — rejected ownership inference

This private combination is **rejected for promotion**. It passes the unchanged owned-pixel preservation checks, including full recovery of case176, but merges independent notes across a structural barline in all 27 original `headAtJunction` separation cases. Neither production nor the source oracles changed. The parent's subsequent 39-page real-score replay is diagnostic only; it cannot override this failure.

Frozen Native SHA256: `87e515434e671bc11f7c304342112401fcd0fc3d800015b8f93f7b29ab013487`. Pre-result protocol SHA256: `e2a31249983f182093c4eec093b36f942c1ab796fd6da3be7ed9bfa216ed767d`.

## Exact composition and controls

The candidate adds exactly the frozen source-span V4 helper, original interstaff seed capture, and final expansion-only ownership alternatives to numbered-line V2. Removing these four additions reconstructs byte-identical numbered-line V2; adding them to the shared production baseline reconstructs byte-identical standalone V4. Source-span calculation still reads original pixels and never uses the new erased-line mask. No thresholds, input scales, source corrections, planner rules or expectations were edited. The older aborted V3 composition remains separate and unexecuted.

| Unchanged evidence | Result |
| --- | --- |
| Current permanent crop suite | 796 checks pass; frozen harness byte-identical to current repository harness |
| Original 36 four-core cases / 144 owners | Zero newly lost or recovered pixels; the same 68 incomplete owners remain; 24 crop rectangles change |
| Isolated case176 | All three complete original source envelopes survive |
| Independent 297 cases / 891 owners | 297 complete cases and 891 complete owners; all 88,821 prior missing pixel observations recovered; zero new loss |
| Independent 336 fixed envelopes | All preserved; no new failures |
| Independent original 29 cases / 99 owners | 70 complete, exactly the standalone V4 loss sets |
| Independent six-case addendum / 18 owners | 15 complete, exactly the standalone V4 loss sets |
| Original junction separation negatives | **27 of 27 regress; 84 additional whole-neighbor relations** |

The 36-case comparison uses the unchanged original source masks and complete unit-pixel containment, independently recomputing each old/new lost-pixel set. The [independent review](../combined-span-v4-independent-2026-10-03/README.md) separately reproduces every original 297 baseline field, verifies all source bytes and masks, and compares lost-pixel sets even in previously failed cases. A better aggregate count was not accepted in place of individual preservation checks.

The known original four-core, hollow-head, full-size filled-head and full-size three-head misses remain. In the addendum, the full-size three-head source still loses 646 / 568 / 1,082 pixels. Numbered-line cleaning changes ordinary component multisets and some older alternative geometry; this combination does not claim standalone V4's component invariance. The permanent harness is stored under its historical `existing795.swift` filename but actually prints 796 assertions.

## Source-first diagnosis of the rejected inference

Both the [case202 original source](case202-original-source.png) and [case176 original source](case176-original-source.png) were reconstructed from unchanged structural source primitives and logged original musical pixels, then verified against the exact input raster SHA256. All originals and the three-owner panels were inspected. No candidate crop or component was used as the ownership oracle. [Case202 owner masks](case202-source-owners.png) and [case176 owner masks](case176-source-owners.png) show the crucial difference.

In case202, the structural barline occupies `[600,180,603,529]`. Each staff has a genuine filled head centered at `[596, top+24]` and its own musical stem `[600,top−22,603,top+26]`, for staff tops 180, 330 and 480. The long barline and each short local stem overlap in the raster. These are correctly recognized real noteheads; the failure is not an open fermata, false ellipse, disconnected neighboring note or uncertain filledness.

The candidate takes all accepted bodies on that physical corridor as one musical span, then assigns the full span to every staff whose core it intersects. Its added alternative is `[590,200,604,508]` with owners `[0,1,2]`. The crops expand from vertical intervals `[140,241]`, `[292,391]`, `[442,534]` to `[140,514]`, `[182,514]`, `[182,534]`. All three original 455-pixel owner masks were already complete in this example. This joins independent parts and introduces two complete foreign staff cores plus substantial neighboring notation. Across all 27 variants, 24 were already complete; three recover 24 source-pixel observations while also failing separation.

Case176 has a different frozen source contract: its entire interrupted head-to-head shaft and both heads belong to all three owners. Its alternative `[593,190,609,539]` correctly restores all three 1,400-pixel masks, including the eight-row source interruption. That success does not establish the ownership of another head-bearing vertical line.

The causal code is the final span formation in `sourceMusicalSpans`: all accepted bodies on one corridor become a first-to-last interval, followed by ownership based solely on intersected five-line cores and occupied shaft rows. Direct physical attachment and solidity establish that bodies exist on the line. They do **not** establish common musical ownership along the complete line. The expansion-only planner faithfully follows the incorrect ownership hypothesis.

## What would distinguish the cases

A further approach must keep structural-backbone evidence separate from local note-stem or beam ownership. A known barline can carry independently owned musical branches; local head identity cannot transfer the complete backbone to every touched staff. Conversely, the fixed four-core positives contain genuine shared musical ink on a continuing structural shaft, so a blanket barline or continuation veto would lose music.

Independent notation evidence—such as a local stem/beam or voice relationship that identifies the shared interval—is needed before assigning remote bodies to another part. This is a design requirement, not an implemented recognizer. Body size, head count, shaft position, interruption length, or a single geometric cutoff is not sufficient evidence. In source regions where labels overlap on identical pixels and the surrounding notation supplies no disambiguation, the correct result is explicit uncertainty and review, not a certified all-staff union. The original source ownership contracts are retained; no positive or negative was relabeled to fit this interpretation.

No new candidate, threshold adjustment or native rerun was performed for this diagnosis. The report preserves the exact source/control code, construction proof, six compiled dependencies, baseline/candidate four-core results, source masks, compiler/run logs and two source-owner comparisons. The complete independent 297/336/29/6 archive is bound by hash rather than duplicated. All archive members were verified; rebuildable binaries and caches are omitted. The full snapshot hash record contains 25 Core files, but these native runners compile only the six dependencies listed by `build-run.sh`.
