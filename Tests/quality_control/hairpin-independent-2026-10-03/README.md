# Detached hairpin candidate: independent bounded review

**Keep this candidate outside production.** Its outward-only integration preserves existing evidence, but the recognition rule is too fragile to call robust. In the independently frozen 12-case challenge, all three source-defined musical positives remain clipped by 484 pixels each. All nine negatives leave crops unchanged. The negative result is narrow: these shapes did not activate the new ownership path, so it cannot establish footer precision or successful reassignment under reordered staff IDs. No production, release, prior fixture, or candidate code was edited.

The reviewed Native candidate is `ef10b25ae7c9c6b1220bd7ea7fcfc8c061360ef24cafbd23c7515329e889081c`. The baseline is `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`. Both analyzers were compiled into one harness with the candidate's unchanged planner. The baseline alias was verified as an exact enum-name-only replacement. `frozen-protocol.json` binds the independent fixture before its first execution.

## Source-owned challenge

The 12 cases include diminuendo, crescendo, reordered/nonsequential observed staff IDs, an identically shaped footer, left/right margin chevrons, nearby/distant footer wedges, a narrow chevron, a closed diamond, a between-staff wedge, and an explicitly incomplete staff inventory. Each original source and its target mask are saved. The musical/footer pair intentionally has identical source pixels but different source-authored ownership; it tests what pixel shape alone can establish, not whether all real wedges are footer ornaments.

All original components remain equal, every prior crop is contained, and disabling musical-evidence additions matches the baseline in all 12 cases. No new component is appended in this challenge. All three musical positives retain their preexisting 484-pixel omission. A separate PIL/NumPy recount verifies all 24 before/after owner observations and all decoded source/mask hashes.

The positive source has 10-pixel staff spaces and two genuine two-pixel hairpin arms. Their converging tip naturally forms a four-pixel connected run. The new maximum thickness is 3.5 pixels, so it rejects the source before fitting the arms. The candidate's other initial geometric limits pass: the source box is `[300,535,425,553]`, 125 pixels wide, 18 high, and 45 below the last staff's lowest line. `source-proof.json` binds every original column exceeding the thickness gate. The viewed `source-positive-and-footer.png` shows the source pixels and unchanged crop edge.

The candidate author's separate 90 shape controls, preserved here as reference evidence, retain 10/18 musical positives and miss eight; all 72 shape negatives stay unchanged. We did not rerun or relabel those cases. Their misses occur for both crescendo and diminuendo at 0.5× and 1.5×, for zero and positive 1.5-degree tilt. Our additional 12 cases use one full-resolution raster only. Neither set establishes score-wide recall.

## Code review

The integration retains ordinary components and appends a typed `isOwnershipAlternative` owned by `ordered.last.id`; it does not reassign old components. The existing planner handles such evidence only by expanding matching staff crops. The source search is limited to an unowned component below the final detected staff, within six spaces, with bounded width/depth, at most two thin runs per column, approximately straight converging arms, and a closing-tip constraint. It checks cancellation during component and column traversal, and the enclosing analyzer checks again before returning.

Using the final sorted staff's actual ID is correct by inspection; it does not assume IDs equal array indices. Our reordered-ID positive fails recognition before this branch, so this test does **not** prove accepted-copy identity handling. An upstream missing staff can also make the final detected staff different from the true final physical staff; the added rule supplies no independent validation of that assumption.

The source geometry proves a wedge shape, not its musical ownership. It uses neither the horizontal extent of the staff nor an independent footer or instrument association. A same-sized footer ornament can be observationally identical to an accepted hairpin. This challenge observed no false expansion because its candidates were rejected earlier; the [main study](../erlkonig-detached-hairpin-2026-10-03/README.md) records separate accepted footer classifications and real-score expansion evidence. Those results are not counted as this harness's independent cases.

Eight serial baseline calls followed by eight candidate calls per case total 96 calls each. Observed times were 0.1693 seconds baseline and 0.1654 seconds candidate; the difference is noise-sized. This measures small rejected-shape fixtures, not accepted-copy performance, large scores, or cancellation latency. The added scan is bounded by the analyzer's raster dimensions and component geometry, with linear per-column fitting and an additional ordinary-component array snapshot.

## Evidence and reproduction

`results.json`, source PNGs, masks, `source-proof.json`, build/run logs, frozen rule, reference 90-case results, and the source archive are hash-bound in `report-hashes.json`. The exact patch is the `candidate.patch` member **inside `sources.zip`**, not a separate directory file; `archive-members.json` binds its original bytes. The same archive contains the exact six candidate Core compilation files, baseline alias, harness and build script. The binary stays private at `.build/hairpin-independent-2026-10-03/challenge`, with its hash in `bindings.json`. Use the archived sources and `build.sh` in an isolated directory, then invoke the binary with an output JSON path and source-image directory. The source checker requires PIL and NumPy.

No thresholds were changed after seeing either result set. There was no additional corpus run, no claim of complete real-score retention, and no change to the released application.
