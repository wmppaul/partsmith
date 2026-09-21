# Strong-line spacing recovery for Bohème page 167

The candidate recovers all six actual piano staves on Bohème885132 PDF page 167. Its 30 staff-line positions agree with independently measured source positions within 0.995 px in the native 1800×2401 render. Source IDs and expected counts are test inputs only; the detector uses image evidence.

The page's 62 ordinary row peaks include repeated piano beams and prose. Their adjacent-spacing mode is 7.40 px, which previously vetoed the stronger true staff patterns at about 15 px spacing. The 30 real line peaks are much stronger than the interline beam peaks. Computing a separate interval mode from strong, horizontally distributed peaks resolves that ambiguity.

The change runs after existing detection and recovery. It retains every established candidate with compatible spacing and exact line coordinates. It replaces an overlapping half-spacing candidate only when its intervening peaks are explicitly weak. A larger rescued candidate must have all five strong peaks and match the strong-peak spacing mode. Existing continuity and local-recall checks remain intact.

## Validation

All 36 source files / 1,477 physical pages completed with zero errors. The sole changed page is Bohème 167: three erroneous half-staves become six complete staves. Every five-line array on the other 1,476 pages is exactly equal to the frozen continuity baseline. Corpus pattern count changes 23,798→23,801; this does not certify every pattern as a true staff.

Focused tests pass for both prior source recall fixes; real title, blank, prose and ledger negatives; tilted, bowed, faint and interrupted staff positives; cancellation; weak interline beams; genuine mixed engraving sizes; and false double-spacing harmonics. An additional test ensures two genuine small staves cannot be swallowed by a larger harmonic even when the rest of the page has larger staves. The existing staff/document suite also passes, including grouping, undo/redo, background detection and stale-result guards.

The earlier broad candidate moved otherwise correct coordinates through anchor selection; it was not promoted. The final candidate avoids those changes. A loaded-page microbenchmark measured roughly 34 ms before versus 39 ms after; this is an informal detector-only observation under concurrent corpus work, not a controlled end-to-end performance claim.

## Reproduction and bounds

- Focused suite: `tools/test_staff_harmonics.sh`.
- Full corpus harness: `tools/test_staff_harmonics.swift --corpus`, with frozen inventories and per-worker paths recorded in `staff-harmonic-validation.json`.
- Exact tested patch: `staff-harmonic-candidate.patch`.
- Independent source oracle: `staff-anomaly-source-oracle.json`.
- Before/after source overlay: `staff-harmonic-boheme-comparison.png`.

Short, faded or strongly curved staves that lack five strong global peaks may still be unresolved. Beethoven52624's ornamental cover false detections are unchanged. This validates detector geometry, not instrument assignment, crop boundaries, omitted rests or complete extracted-part quality. Exact hashes and all changed coordinates are in the JSON report.
