# Case 176: the nine pixels survive analysis but lose crop coverage

This is a read-only diagnosis of the regression that rejects the [numbered-line V2 candidate](../brahms-numbered-lines-2026-10-03/README.md). No detector or planner change is proposed or applied here. Instrumented single-case baseline and V2 results exactly match their corresponding frozen 297-case results.

The fixture is `edgeMusicBroken`, scale 1, tilt 0, bow 10. Its untouched source assigns the long musical stem and both terminal heads to all three staff views. At `x600..<603`, the source shaft is interrupted at `y227..<235`.

All nine newly excluded stem pixels (`x600..<603 × y212..<215`) remain black after both line removal and connector separation in **both** implementations. They belong to an ordinary component with inferred staff owner `[0]`. The middle part excludes that component in both versions. Thus the regression is not direct pixel erasure.

## Exact component-to-crop path

| Evidence driving the middle part | Baseline | V2 |
|---|---:|---:|
| Component box, native pixels | `[396,230,603,385]` | `[470,233,603,385]` |
| Component area | 1,470 pixels | 668 pixels |
| Inferred staff owners | `[1]` | `[1]` |
| Highest pixels | x396–419, y230 | x470–491, y233 |
| Musical ownership of those highest pixels | None | None |
| Planner top clearance | 18 pixels | 18 pixels |
| Resulting crop top | 212 | 215 |

Those highest pixels are residual pieces of the **upper staff's curved bottom line**, attached to the lower surviving shaft segment. V2 removes more of that line. The component's inferred staff identity stays `[1]`, but its top moves down three pixels. The compact planner selects it for the middle part and applies its unchanged 1.5-space top margin: `230−18=212` versus `233−18=215`.

The resulting margin previously happened to cover nine pixels in the separate upper musical component. After the change it no longer does. Exact lost owned pixels increase from 650 to 659, with no recovered pixels. The old crop was already substantially incomplete.

Native component ownership follows bounding-box intersection with the supplied staff cores. The upper stem/head component remains above the middle core and owns `[0]`; the lower piece begins below the upper core and owns `[1]`. In `ScoreExtractionPlanner.cropBounds`, the latter is selected by matching owner. The former has a foreign, nonempty owner set and cannot be imported by the detached-mark traversal. No musical ownership alternative is present.

[The complete mapping](component-ownership-map.json) records every affected pixel, its presence at both analysis stages, inferred component owners, component extrema and actual crop. The [baseline source map](baseline-component-source-map.png) and [V2 source map](candidate-v2-component-source-map.png) show the selected component in blue, unchanged source in gray, nine musical pixels in pink, component top in green, and crop top in red.

## Why the existing musical check misses the span

Logging and direct source-row measurements agree:

- For the upper/middle pair, the upper core has 37/49 supported rows at the unshifted estimate and 40/49 after the chosen +9-pixel local shift. It fails the unchanged 88% test. Processing skips that connector **before** calling the terminal-body check.
- For the middle/lower pair, both nominal cores have 49/49 supported rows. Its endpoint check sees the shaft continuing above the middle staff and below the nominal lower boundary. It reports `musical=false` and separates the lower interstaff shaft.
- The real top head lies outside the accepted lower pair's local endpoint search. The source-owned musical relation across the upper scan break is never represented.

This establishes a prerequisite for another experiment: a musical-span hypothesis must be measured from original source shaft/body evidence before adjacent-pair structural decisions, and must survive a supported scan interruption. It should carry the relevant head and shaft branches as outward-preservation evidence, rather than unioning whole legacy component boxes and their foreign staff-line residue. Whether original pixels distinguish a real musical shaft from a barline sharing a notehead remains a separate ambiguity to test; aligned columns or a compact nearby blob are not sufficient proof.

`diagnostic-evidence.zip` contains the unchanged fixture adapter, native stage masks, components, plans, source/owner masks, component tracing program, diagnostic source copies, and logs. It excludes executables. `archive-manifest.json` binds all members, and `bindings.json` binds production and the preceding rejection report. Production Native and planner remain unchanged.
