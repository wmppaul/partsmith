# Additional-only numbered staff-line removal: bounded implementation receipt

The private candidate fixes the three observed Brahms242312 regressions by preventing measured staff-line removal from restoring source pixels that the prior nominal eraser had removed. It adds one functional line to the reviewed e32b5a implementation: `ink = musicalFeatureInk` before the measured-line loop. No curve, crossing, connector, musical-body or ownership threshold changes. The same-owner legacy-envelope compatibility support is unchanged. Original/exported PDF pixels remain untouched.

Candidate Native SHA256: `95a958a328a729cf4c8d64421a96c1dd2533b3b38a68606fb1ead3c21cf780e0`.

The original [three-page source cause](../brahms-restored-endpoint-regression-2026-10-03/README.md) is frozen separately. Each offending ordinary component had extended just three rows into the next staff's nominal core. The new initialization makes measured removal additional-only, so a raw component cannot gain new membership or vertical reach through restored pixels.

## Own completed checks

| Check | Result |
|---|---|
| Unchanged permanent suite | 796 pass, including its explicitly printed pre-existing three-row-gap annotation limitation |
| Unchanged four-core musical source suite | 36 cases / 144 owners; every crop and exact owned-pixel loss set equals production baseline; 68 incomplete owners remain |
| Native original Brahms242312 pages 1, 2 and 16 | The three previously regressed recipient rectangles now equal production baseline exactly; no new whole-neighbor relation anywhere on these pages |
| Instrumented mask invariant | All six post-line/post-connector observations retain only pixels present in the legacy feature mask |
| Other 30 changed crops on those three pages | Root inspected all original-source contexts and observed no newly omitted intended notes or marks; exact source/bounds/context hashes in `root-three-page-review/review.json` |

The frozen native inventory/profile and same current planner are used on both sides. Source-observer changes are logging and preconditions only; the observer's original images match the baseline replay pixel-for-pixel. The source audit retains pre-existing contamination, including p16s1 ViolinII containing a whole ViolinI and p16s4 Viola containing a whole Cello. This is not a clean-part or musical-completeness claim.

The subset invariant applies to raw analysis masks and raw connected components. It does **not** establish monotonicity of all published components or final crops: thin-connector filtering, detached-mark association and compatibility alternatives can affect later decisions. Exact owned-source-pixel tests and full-corpus source review remain separate gates. The [independent static audit](../monotone-line-mask-independent-2026-10-03/review.json) explicitly makes that distinction. Independent 297/336 and 29+6 observations and parent corrected39/full36 measurements are separately owned evidence, not included in this receipt's test counts.

No production source, source oracle, existing mask, reviewed crop obligation or open user document was modified. This receipt supports further regression/source review of the private candidate, not publication by itself. The unsuccessful actual document worker with the previous e32 candidate is separately recorded in [the locked-session receipt](../envelope-compatibility-locked-workflow-2026-10-03/README.md); it is not a successful export of this candidate.

## Reproduction

`prepare.py` captures the one-line change, source hashes and protocol before results. `build-run.sh candidate existing795` and `build-run.sh candidate fourcore` compile the uninstrumented frozen candidate; `compare-fourcore-exact.py` checks full pixel-cell containment against unchanged owner masks. `prepare-source-observer.py` and `run-source-observer.sh` replay only the three original pages with frozen staff observations and the same profile. `compare-source.py` checks the mask/input bindings, assignments, crops and whole-neighbor relations. The archive preserves sources, constructors, masks, results, observational diffs and raw logs; rebuildable binaries and duplicate contact sheets are omitted.
