# Exact reuse of corrected Brahms reviews for raw-source crops

**193 of the 253 pending raw Brahms 93521 crops can reuse existing source reviews. Sixty remain pending.** Every reused row has the same original PDF, complete decoded source pixels, staff geometry, intended assignment, baseline crop and candidate crop as an already reviewed corrected-workflow row. This is verified reuse of prior visual work, not a new visual certification of the whole score.

The thirty pages without a saved correction were freshly rendered using the actual `NativeScorePageAnalyzer.render` implementation used by the raw corpus worker. The harness calls rendering only; no analyzer or staff detection was run. All thirty complete images match the saved review rasters pixel for pixel after RGBA decoding. Their encoded PNG bytes also happen to match exactly, independently reinforcing the decoded-pixel check. Equality was not inferred from dimensions, file names, staff coordinates, threshold masks or apparent similarity. The render-only run took 2.93 seconds on this host.

For each of the 193 reused bands, both raw baseline/candidate crop rectangles and the part, system, staff IDs and page geometry match the corrected baseline/candidate. The proof identifies an actual source-review leaf, checks its hash and context image hash, and rechecks the coordinates in that receipt. Some leaves are direct monotone-candidate reviews; others come through the verified exact-plan chain from the prior combined candidate to the intermediate envelope candidate. An unchanged but never-reviewed crop is not treated as a reviewed source area.

The sixty remaining crops are all on pages with saved rectifications. They stay pending without guessed coordinate transforms:

| Physical page | Pending crops |
| --- | ---: |
| 2 | 5 |
| 7 | 8 |
| 17 | 9 |
| 19 | 4 |
| 23 | 8 |
| 28 | 9 |
| 34 | 9 |
| 38 | 5 |
| 39 | 3 |

`reused-reviewed-bands.json` lists every accepted ID, exact rectangles, original pixel proof and review receipt. `remaining-pending-bands.json` retains every unverified row with rejection reasons. `decoded-pixel-comparison.json` records all thirty native/saved PNG hashes, RGBA hashes, dimensions and zero differing-pixel counts. `review-leaf-coordinate-validation.json` records all 193 independently checked source contexts. Original renders remain in the private work directory and are byte-identical to the saved rasters bound by the archived original input manifest; duplicate image data is not archived again.

`evidence.zip` contains the render-only harness, frozen compiled source dependencies, executable hash, logs, input bindings, complete comparison scripts/results and source-review receipts. Every archive payload was read back and hash-verified. The exact source PDF hash remains `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. The monotone candidate remains `95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0`; production detector and all original guards remain unchanged.

This proof does not waive the three existing frozen corrected-score guard failures, certify unchanged omissions, review exported pages, or approve crop-algorithm promotion. It does not address the separately reported Coda and conditional-tempo omissions on other editions. The frozen [full-corpus report](../monotone-corpus-independent-2026-10-03/README.md) remains intact; this is a separate supplemental reduction of its review queue.
