# Local staff ownership, private V1 rejected

The x-aware affine ownership experiment recovers the complete raw page 34 Viola **f**, but **introduces 408 lost source-owned pixels in an unchanged scanned-stem control**. It is rejected. Production, existing guards and fixtures are unchanged; there was no corpus run.

The single code change measures each retained component run in the detected affine staff coordinate frame before assigning staff IDs. Actual component bounds, source pixels, line masks, connector cuts and crop padding are unchanged. This uses the page-wide detected skew; it does not measure local curvature.

The original source and independently frozen f mask are documented in `../brahms-p34-dynamic-2026-10-03/`. All 372 nonwhite f pixels are fully retained by the candidate, compared with 181 fully retained, seven edge-intersected and 184 excluded by production. The crop bottom grows from 560.721020 to 567.601236 PDF points. The fresh one-page baseline exactly reproduces the frozen original page geometry and semantic components. Sixteen source assignments stay unchanged; five crop edges change. All five full-width source contexts were viewed: no new own-note omission was observed there, and neighboring fragments remain.

The permanent 796 checks and all 336 low-resolution filled/hollow envelope checks pass. The 297-case exact-source test still has 238 fully preserved cases, but that aggregate conceals a regression. Case 164 (`edgeMusicBroken`, scale 0.5, tilt −1.5°, bow +10) changes a retained component's owners from `[0,1]` to `[1]`. The upper crop bottom contracts from y386 to y250. The new losses are exactly the 408 musical stem pixels in x600..<603, y250..<386. The owner already had 517 missing pixels; the candidate has 925. No recovered pixels offset this owner's loss. Full preservation of the old failing cases remains unfinished.

Across all 891 owners the candidate recovers 2,841 pixels and newly loses 408. There are no new failures among the separation-designated cases, but three other cases gain whole neighbors. Improvements elsewhere do not excuse the regression. `failure164.json` preserves its exact loss set; the source-only reconstruction produces bytes matching the immutable original image and owner masks and makes no detector call. Its source and overlay were independently viewed.

One-page native render/analyze/plan measurements were 0.2183 seconds for baseline and 0.2064 for candidate under concurrent checks, not performance guarantees. The permanent/297/336 executions measured 1.88/3.75/1.51 seconds respectively. No new full-output or release claim follows.

A further hypothesis would need actual locally supported numbered staff-line geometry and must retain nominal ownership when local evidence is unsupported or ambiguous. Global skew alone is insufficient. This V1 remains frozen; any later experiment requires a separate snapshot and unchanged source-loss comparisons.

`evidence.zip` contains the two Core snapshots, unchanged test constructors, raw test results, one-page analyses/plans and logs. `archive-payloads.json` binds every payload. Source-defined f obligations remain in their independent report; no earlier oracle was modified.
