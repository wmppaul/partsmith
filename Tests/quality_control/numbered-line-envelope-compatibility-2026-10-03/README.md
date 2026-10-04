# Numbered-line cleanup with single-owner envelope compatibility

This private candidate passes the fixed preservation and staff-separation controls while retaining the source-defined existing failures. It restores case176's previous crop boundary without the rejected all-staff musical-span inference. **This receipt is a limited control result, not approval to ship or a complete musical-quality claim.** The parent's separate 39-page source review decides real-score usefulness. No production change occurred in this study.

Frozen Native SHA256: `e32b5a76928b505efbeba6fa5bc9aef4b58ed0e2b7d11ddeef3269b73570996f`. Pre-result protocol SHA256: `caced5d8a638510b906541cd02fb23141ac04582ecf6e9e37a318a088691de2f`.

## What the change preserves

The base is the exact frozen numbered-line V2 analyzer. This version contains **no source-musical-span helper, body search, new shape threshold or global head-to-head ownership hypothesis**. It keeps the existing legacy feature mask, already produced from nominal staff-line removal and mirrored structural connector cuts, and labels its connected components once. Actual same-row overlapping black runs establish correspondence to components after numbered-line cleanup. Bounding-box proximity never establishes correspondence.

A prior component qualifies only when it has exactly one staff owner and at least one retained child with that same sole owner. Every owner-bearing child must keep exactly that owner; conflicting or shared-owner descendants reject the match. Unowned children may exist, but are not assigned new owners. Prior multistaff components are never inherited.

If the prior component's top or bottom extends its current same-owner children, its prior rectangle is retained as an `isOwnershipAlternative` support for that one staff. It can enlarge the crop after ordinary attribution; it cannot compete with neighboring ink, seed detached-mark discovery or transfer ownership to another staff. This is per-component compatibility, not a union of complete previous band rectangles. It deliberately preserves some known old context, including staff-line residue; it does not claim that residue is musical ink.

The numbered-line ordinary component calculation and existing musical/local merge are unchanged in the diff. Supports are added after component measurement. In the existing recursive local interpretation, the same compatibility rule runs on that interpretation's own already-produced masks. It does not introduce another rasterization or structural detector invocation. Ordinary-component equality to numbered-line V2 follows from this insertion-only code path; a complete new runtime multiset comparison to V2 was not performed because its original 297 result records lacked full component lists. Changes from production are expected and recorded independently.

## Case176 correspondence and scope

The original [case176 diagnosis](../brahms-case176-ownership-2026-10-03/README.md) remains unchanged. The nine newly excluded pixels were never erased. The prior middle-owner component started at row230, with an18-pixel crop allowance giving top212. Better staff-line removal shifted its residue to row233, giving top215 and excluding three rows of the separate upper stem.

Source-pixel matching shows the old1470-pixel component, owners `[1]`, contains the new668-pixel driver plus four detached68-pixel staff-line fragments. All five children still have sole owner `[1]`; the driver is an exact subset with no newly introduced pixels. A strict one-child test would incorrectly reject this correspondence. The four extra children's source boxes are `[470,335,538,338]`, `[470,347,538,350]`, `[470,359,538,362]`, and `[470,371,538,374]`; none contains target musical pixels in the fixed mask. The actual compatibility rule does not need their semantic classification, only unchanged sole ownership.

Preserving the old component envelope restores the exact previous middle crop `[0,212,720,395]`. Its650 previously missing target pixels remain missing. The other two old losses970 and808 remain unchanged too. This avoids a regression; it does not solve the underlying shared-stem recognition problem or waive its source obligation. `case176-correspondence.json` binds the original masks and component maps; `case176-comparison.json` records the fresh result.

## Unchanged controls

| Evidence | Candidate result |
| --- | --- |
| Current permanent crop suite |796 assertions pass; harness byte-identical to repository version |
| Original36 four-core cases /144 owners |Same68 incomplete owners; exact lost-pixel sets unchanged;24 crop rectangles change |
|297 cases /891 original owner masks |Zero newly lost pixels;12 recovered pixels in case170 owner1;238 complete cases and732 complete owners remain |
| Case176 |All three source loss sets exactly baseline:970 /650 /808 |
| All27 original `headAtJunction` negatives |Zero whole-neighbor inclusions; no rejected global ownership union |
| Entire297 grid |No case increases its whole-neighbor count |
|336 fixed source-envelope cases |All preserved; no new failures |
| Independent29 cases /99 owners |Exact baseline loss sets;64 complete |
| Independent six-case addendum /18 owners |Exact baseline loss sets;12 complete; no spurious neighbor relation |

The [independent report](../numbered-envelope-independent-2026-10-03/README.md) binds every original source/mask hash and exact per-pixel comparison, including already-incomplete cases. The297 baseline had88,821 missing pixel observations; this version has88,809, with the reduction entirely the12 recovered pixels in one existing incomplete owner. Those counts do not imply complete score extraction. The original shared-musical, hollow-head and full-size three-head failures remain part of the evidence.

The rejected [numbered-line plus source-span V4 experiment](../numbered-lines-source-spans-v4-2026-10-03/README.md) remains separately frozen. Its tempting297 complete score came with27 ownership failures and84 new foreign-core relations. This candidate neither contains that method nor claims its full-span recoveries.

## Cost and reproduction

The added work is one legacy-mask run/component labeling pass and run-overlap correspondence per already-existing native branch. It reuses the legacy mask that numbered-line V2 already maintains. It does not allocate another full image raster or full per-pixel component-index array, trace connectors again, or run a body classifier. Memory is proportional to legacy runs, component bounds and correspondence sets; both existing musical/local branches may compute their own supports.

Independent Release wall times under concurrent compilation/testing were9.38 seconds for297 cases,9.27 seconds for336,0.439 seconds for29, and0.084 seconds for the addendum. These include the entire numbered-line algorithm and harness, not isolated compatibility overhead. The earlier production297 observation was3.62 seconds under a different run/load. No controlled marginal timing or UI responsiveness claim follows from this comparison. Parent-owned real-page timings belong to the separate real-source review.

The archive contains the exact six compiled dependencies, source diff, frozen protocol, unchanged constructors, baseline/candidate original36 results and masks, permanent-check log, case176 source evidence and comparisons. Independent297/336/29/6 raw evidence is bound by its separately verified report manifest rather than duplicated. Binaries and module caches are omitted. No fixture ownership, guard, scan resolution, saved correction, profile, padding or planner rule changed.
