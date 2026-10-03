# Original-source musical spans V1 — rejected

V1 recovers the complete source-owned interrupted shaft in case176, but it also invents musical ownership at real barlines. **Do not promote or combine this version with the numbered-line eraser.** Production Native remains `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`.

The final private Native is `00749e09b47ed1740feeab4d53aa77e7ce17658edb3d5a0f81fe60a51bf81fe1`. Only Native changes among the six compiled dependencies. Frozen hypothesis and implementation records predate results. The final snapshot adds cancellation checks to the original V1 implementation without changing its classification rules. The archive preserves both versions, the exact compiled dependencies, test constructors, original source masks, output records and logging-only observer.

## What was tested

| Evidence | Result | Limit |
|---|---|---|
| Exact case176, all three original owners | All full source envelopes recovered, including original scan gap227..<235 | This is full source recovery, not merely the nine-pixel regression repair |
| Original36 four-core cases,144 owners | Incomplete68→60; eight complete repairs; no newly lost source pixels through noncontracting crops | Repairs only hollowOuter/hollowTiedOuter at0.5 scale; substantial original omissions remain |
| Independent frozen29 cases,99 owners | Complete64→73; no newly lost pixels; all36 negative owners remain complete | Hollow shared-stem observations remain incomplete |
| Prospective attached-glyph/three-head addendum,6 cases | Attached pp at1× creates a false shared interval; three-head shaft remains incomplete for outer owners | This addendum was frozen before execution, but is separate from the original blinded29 |
| Root full39 corrected Brahms pages,604 crops | Ordinary components and old alternatives exact;13 crops expand from8 new intervals;14 new crop/foreign-core relations | All8 intervals are false on original-source review;10 crops gain complete foreign cores |
| Logging-only real5-page replay | Every normalized analysis and every plan page equal root's full39 output | p23/p29 component array ordering differs; component multisets do not |

The permanent796 suite and full297/336 replay were not run on this rejected source-span version. The standalone layer's expansion-only contract is verified in the tested cases; it does not establish complete music extraction. No1477-page or combined numbered-line run was started.

Independent results are frozen separately in [the29-case review](../musical-span-independent-2026-10-03/candidate-v1/README.md) and [the attached-glyph addendum](../musical-span-attached-addendum-2026-10-03/README.md). Their final manifests and root's full39 output are hash-bound in `bindings.json`. Root owns the full39 report and original full-page raster archive; this compact archive retains exact local source patches and changed-page native analyses instead of duplicating those rasters.

## Source diagnosis

Every proposed body was checked on the unmodified original/corrected source raster, first in its system context and then in the actual fitted window. The five page panels and `real-source-verdicts.json` cover all16 body fits:

- p23: a slur crest and a staff/barline crossing on one ordinary barline, proposed twice by adjacent seed columns.
- p28: two separate tie/slur arcs crossing the Coda's barline.
- p29: staff lines meeting the terminal double line.
- p38: plain staff/barline crosses and an open broken-staff corner at the terminal line.
- p39: separate slur arcs crossing two ordinary measurelines.

Fourteen fits classify as **filled**; two classify open corners as **hollow**. The main failure is not restricted to hollow cavities. A one-pixel neighborhood around a small ellipse can collect boundary support from the arms of a thick cross. Its interior includes shaft pixels, and the exterior white test excludes the shaft. This allows a window over structural strokes to pass without demonstrating a complete notehead footprint. Direct contact along two original rows does not establish the identity of the attached shape. The attached pp addendum further shows that even a plausible closed bowl can belong to a text glyph.

The observer preserves exact centers, radii, orientations, boundary/interior/exterior scores, attachment rows, physical shaft columns, traced rows and scan gaps. `real-witness-panels/body-index.json` maps every panel to its original raster hash and exact source coordinates. Exact unscaled source patches are in the archive. These are diagnostic fitted windows, not newly declared source ownership guards.

V1's body pairing also loses information: with three or more heads on the same shaft, only adjacent pairs become alternatives. An outer staff can therefore receive only its nearest pair rather than the full connected musical span. This limitation was identified before the addendum and then reproduced independently.

## Integration and timing

New source evidence is discovered before structural-core rejection, only on the musical-retention path. Alternatives are appended after the existing local/musical merge. They never enter ordinary ownership, the legacy body classifier or the recursive false path. Existing ordinary components and alternatives remain exact; crops can only expand. That useful invariant prevented new target loss here, but it cannot make false ownership acceptable: real-score readability worsens substantially.

One exact case176 run, including fixture file output and excluding compilation, took0.01s in Release and0.44s in Debug. Both returned identical results. Root's complete39-page native Release replay took5.14s. These are bounded process timings, not measurements of UI responsiveness. Cancellation is checked in seed, corridor, row-proposal, group and template loops.

## Next bounded design, not implemented here

A replacement needs original-source **body footprint** evidence, rather than ellipse support inside a chosen window. Independently trace thin staff/slur paths entering from outside the proposed body and retain their provenance. A filled body must require a compact thick off-shaft region that those continuing paths cannot explain. A hollow body must have an actual closed cavity and off-shaft arc evidence; an open cross corner is insufficient. A tied note must retain its compact head while its thin tie continues. Connected text descenders/companion glyphs require explicit ambiguity handling; local bowl shape alone is insufficient.

Build accepted heads on one physical shaft into a connected head-to-head interval for every actually contacted owner, excluding bare continuing shaft beyond the outer heads. This should repair the three-head association independently of the body recognizer. Any V2 must freeze its exact rules before results, preserve all original controls and target masks, reject these eight real false spans plus attached glyphs, and retain full case176. Passing that bounded test would justify a later combined experiment, not promotion.

`implementation-and-evidence.zip` contains176 members and is independently verified against `archive-manifest.json`. Rebuildable executables and duplicate full-score rasters are omitted. No source obligations were moved or weakened.
