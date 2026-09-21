# Restrict detached notation propagation at system boundaries

The final candidate requires competing next-system ownership evidence. This preserves all 64 Ave crop geometries and frozen source guards while retaining the four reviewed Quartet improvements. Full regenerated output review remains separate.

Some Cello crops grew into the next system's high Violin notes, rehearsal letters and ending brackets. The planner allowed a detached Cello hairpin to anchor another detached mark, which could anchor several more marks in four proximity rounds. A component's bounding box could contribute proximity even where its interior was blank.

The change requires direct target-owned support when discovering a detached lower mark near notation exclusively owned by the next system. It uses the existing local proximity thresholds and a cached list of following-system components. Without that competing evidence, detached annotation chains such as figured bass keep their original behavior. Automatic cadence or reviewed assignments establish that the target is the last staff before another printed system. It preserves all target-owned and ambiguous components, initial seeds, explicit lyrics, upward propagation, manual crop rectangles, other staves within a system and the final system on a page. It does not cap crops at staff midpoints or modify source pixels. The precomputed high-target-ink cache and shared-heading helper remain intact.

A broader rule for every staff was rejected because it worsened low dynamics/text within systems. The initial boundary-only version was also rejected: it cut actual lower continuo numbers and accidentals on the first system of all four Ave pages. Adding competing next-system evidence restores every Ave crop exactly; no instrument-name exception, lyrics flag, padding workaround or guard relaxation is used.

## Frozen native results

Native plans compare all 604 raw and 604 corrected current Quartet bands, all 480 historical Quartet bands and all 64 Ave bands. The corrected run uses the exact nine previously recorded transformations; no staff detection or rectification is rerun.

| Case | Changed bands | Foreign staff-line centers | Whole neighboring staves |
| --- | ---: | ---: | ---: |
| Current Quartet, raw | 33 / 604 | 708 → 688 | 23 → 23 |
| Current Quartet, exact corrected | 30 / 604 | 688 → 669 | 20 → 20 |
| Historical Quartet | 33 / 480 | 804 → 793 | 36 → 36 |

The remaining whole neighboring staves come from structural joins and require separate work. Neighbor-line counts measure context, not musical fidelity.

All four reported Cello cases retain their actual lower notation and seven independently identified landmarks. Bottoms change as follows:

| Source band | Before | After |
| --- | ---: | ---: |
| p17 s2 | 324 pt | 312.400 pt |
| p18 s1 | 182.546 pt | 172.345 pt |
| p22 s3 | 459.752 pt | 447.656 pt |
| p32 s3 | 469.002 pt | 442.438 pt |

Three new frozen lower envelopes fit completely. At p22s3, the independently frozen 448-point envelope remains unchanged: the candidate excludes 0.344 points from that frozen envelope. No target notation is excluded; the final output review separately records neighboring rehearsal ink in the surrounding full-width sliver. A 720dpi source check places the lowest target hairpin ink at 445.7 points, leaving about 1.956 points of clearance. Some next-system high slurs overlap the vertical range required by target Cello marks; full-width faithful crops can retain such fragments. An unrelated initial seed still enlarges p17s2 somewhat, so this is a bounded improvement.

Existing corrected source guard mismatches remain identical. Historical safety-envelope failures rise from 44 to 46, with two independently reviewed exceptions: p5s3's excluded 0.291-point sliver is blank; p22s2's excluded 0.773-point sliver contains only next-system Violin slur tips. Both complete target Cello passages remain above the edge. Original frozen guard files were not relaxed or refitted.

## Regression coverage

`bash tools/test_system_boundary_crops.sh` adds 423 checks using eight compact frozen source-component fixtures across the Quartet and Ave plus controls for target stems, genuine ambiguous crossings, explicit lyric rows, within-system low directions, final systems, grand staves, changing instrumentation, generated rests and explicit user crop rectangles. The baseline planner fails the first Quartet regression; the initial boundary-only version fails the first Ave figured-bass preservation regression. The final production source passes all 423 checks. The existing planner and structural crop suites pass another 83 and 82 checks. Hashes, exact conditions and guard exceptions are recorded in `system-boundary-ownership.json`.

Full regenerated output review remains a separate completion check. The second-source geometry comparison confirms all 64 Ave crops and frozen target envelopes are restored. No result here claims complete unattended extraction quality.
