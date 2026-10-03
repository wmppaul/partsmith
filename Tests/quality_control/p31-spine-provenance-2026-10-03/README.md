# Brahms p31 boundary attribution and p24/p28 gate diagnosis

**No candidate or production change.** Current native analysis was replayed on the exact frozen source rasters. Logging-only and uninstrumented results match each other and every baseline component signature: page24 **1,877**, page28 **821**, page31 **2,351**. Original bounds, owners and optional preservation-alternative identity are unchanged. All 32 files of the prior independent seven-case source report were reverified; no source guard was changed.

## P31: the component and actual source

The oversized `p31-s1-violin2` crop is `[0,41.4354030081,427,110.8642499036]` in original top-down PDF points. Its causal ordinary shared component has owners0/1, native bounds `[1641,200,1651,350]`, and **448 actual pixels**. Its PDF bounds are `[389.281667,47.435403,391.653889,83.011955]`. The ordinary shared envelope pulls ViolinII's top six points above this component, including ViolinI's complete staff. This is not an outward-only alternative or an endpoint-notehead veto.

I inspected the original full system, untouched native close-up and exact component overlay. The component is the narrow leaning right system boundary with short staff-line remnants; it contains no ViolinI beam/note or ViolinII note, slur or hairpin. The two flagged ViolinII notes, lower slur and crescendo lie separately to its left. The independent original-source target envelope `[35,69,394,105.5]`, final-note/slur/crescendo guard `[353,73,389.5,102]`, and existing detached-piano/low-slur obligation remain unchanged.

In the source-only interior gap `y270..<309`, the boundary has ink on **all39 rows**, only **2–4 pixels per row**, with at least **391 blank columns** between it and the nearest other source ink to its left. This region maps to about y64.04–73.29pt. A split of structural connectivity here would not intersect a target note, slur or direction in this case. Such a split is analysis-only: original PDF engraving must remain unchanged, including retained local barline portions. Merely deleting source ink or dropping an arbitrary shared box is not recommended.

The full component is10 pixels wide because its center drifts and junction remnants extend sideways. Its row spans are mostly2–4 pixels, with three rows7–8 pixels wide. This explains why a row-width shortcut removed this case, but **does not validate that shortcut**: the previously frozen steep diagonal/curved musical negatives still forbid it.

## Exact current rejection stage

The initial gap corridor is x`1642..<1653`, y`253..<309`, with a nominal upper/lower-core check returning false. The upper staff's global top estimate is y189.003; source near the boundary lies roughly11–13 pixels lower because of local bowing. The local trace follows shifts10/11/12 through the penultimate interior window, then fails at its final42-pixel window centered **x1614**, segment34.

Best final shift12 has five line-support fractions **[0.2619,0.8571,0.5952,0.6667,0.6190]**. Only one line reaches80%; current code requires at least three. The trace becomes empty and returns nil before `connectorProof` or musical endpoint handling is reached. This is damaged horizontal print, not an absent continuous interstaff boundary.

The native coordinate grid is useful counterevidence to an overly strong boundary claim: the upper staff's first three horizontal lines do **not** all physically reach the spine with long clean runs. They end as broken fragments/stubs. A proposed “five long staff lines directly terminate at one spine” rule cannot simply declare this page proven. Independently tracked line identity, the common right boundary across the other staves, source-supported junction fragments and actual branch ownership would need to be combined, while preserving any attached music. Boundary position or thinness alone is insufficient.

## P24 and p28: different, confirmed gates

These two pages received fresh exact gate replay, not a new independent whole-page musical review in this study.

| Case | Local geometry result | Failing core support |
| --- | --- | --- |
| p24s2 Viola/Cello, right boundary x1634..<1646 | Local shifts are accepted: upper−6.3913px, lower−5.3913px including slope | Lower staff7 rows1204..<1261: **49/57**, below required50.16 (88%) |
| p28s1 ViolinI/II, interior boundary x242..<252 | Local shifts accepted: upper−1px, lower0px | Upper staff0 rows103..<137: **29/34**, below required29.92 (88%) |
| p31s1 ViolinII, right boundary | Final five-line identity trace fails | No local connector proof is reached |

Thus a single relaxation of local tracing cannot solve all three causes. Nor do accepted shifts establish all junction/branch requirements: p24/p28 return at their core-support guard before those later checks can certify the connector. The trace records exact computed rows and support values rather than inferring the cause from crop size.

## Algorithmic implication and limits

Useful source evidence would be a typed structural-spine graph retaining row-run coordinates, physical junction fragments, actual horizontal-line identity and attached local branches. A source-isolated gap segment can sever attribution through a recognized measure/system boundary while keeping note/slur branches assigned to their actual staves. Genuine filled/hollow/tied heads, shared musical stems, broken staff fragments and near-but-disconnected notes must remain independent negative/positive controls. The prior row-width and four-core shortcuts failed those obligations; they were not revived here.

The current component model retains only boxes/owner IDs, so it cannot recover this source distinction in the planner alone. Prior component ablation demonstrated causality but is not a crop proposal: removing p31's shared component would still leave the automatic upper edge at58.512pt, broader than the manually reviewed67.5pt edge. Resolving this connector alone therefore does not certify a fully clean output. No output was regenerated, no automatic musical completeness claim is made, and no new classifier is proposed for promotion.

## Reproduction and bindings

`gate-summary.json` and `trace.jsonl` contain the source-bound gate observations; `canonical-comparison.json` verifies every component signature. `measurements.json` contains the exact448-pixel component's row spans and the source-only bridge measurements. The coordinate grid and overlay retain the original pixels; magenta is an explanatory overlay only.

`native-evidence.zip` stores frozen current Core, the three exact native source rasters, original/staff-erased/separated diagnostic masks, and complete component records. `archive-members.json` binds all entries. Source PDFs, baseline inventory, old ablation and untouched guards remain at the paths/hashes in `input-bindings.json`. The private binary is hash-bound there.

The final `build.sh`, `main.swift` and `ProbeNativeScorePageAnalyzer.swift` reproduce the three-page logging run after restoring the archived Core under `.build/p31-spine-provenance-2026-10-03/`. `prepare.py` preserves the initial p31-only preparation; the final retained harness additionally scopes p24/p28 and core-support diagnostics. It should not be rerun over the final probe when reproducing the three-page study. There are no source-threshold, component-classification or planner changes in this work.
