# Parzen template matching: two rejected private anchor trials

Production recognizes 6 of 24 unseeded full systems. All 26 source systems form the correct complete connected groups, and all 542 inter-staff connections pass. The 18 abstentions arise from clef-patch similarity. Some patch origins include a bracket or instrument label; the opening Trombone III/Tuba patch lands on notes after the F clef.

| Run | Reviewed seeds | Correct suggestions | Remaining abstentions | Previously suggested pages lost |
| --- | --- | --- | --- | --- |
| Shipping production | 2, 4 | 6/24 | 18 | — |
| Production with extra manual seeds | 2, 3, 4, 19 | 11/22 | 11 | Not comparable denominator |
| Private v1 | 2, 4 | 15/24 | 9 | 8 |
| Private v2 | 2, 4 | 11/24 | 13 | 16 |

Every v1/v2 suggestion has the exact frozen source candidate IDs, present parts, and actual per-part staffCounts. V1 averages two distinct structures at a bracket. V2 measures all five horizontal ridges and local phase, but a true thick/double boundary has different left and right edges; treating it as one point rejects useful patches. Neither trial is promoted.

All 32 historical comparable outputs are byte-equivalent after excluding elapsed time and the newly serialized staffCounts field. The unchanged original assessor reports 31 passes and the existing `notte-changed-profile-count` conflict: the released per-system grouping API now honors reviewed counts. That failure is preserved, not waived. Parzen grouping is independently checked using the new actual staffCounts field.

The archive preserves exact inputs, expected source maps, current Core snapshot with observation-only instrumentation, both private Core snapshots, protocols frozen before results, complete result/event JSON, per-staff score vectors, build/run logs, source panels, and six native render-only pages used for the failed-gate measurements. Eight production patches reproduce all 1,792 pixels each from those original rasters. Source PDF is hash-linked and is not duplicated. Instrument guesses, missing bar counts, crop algorithms, and production files were not changed.

Future work should represent the whole observed boundary band, keeping its horizontal-line intersection separate from the right edge used to sample the clef. It must reject bracket-only paths, preserve old rejection behavior, and avoid comparing a normalized seed against an unnormalized target without compatible evidence. This is a proposal, not validated code.
