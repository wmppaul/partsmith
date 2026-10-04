# Independent Notte local-count compatibility review

The three new proposals in `notte-changed-profile-count` are correct for the original first page. The old **no-suggestions** expectation still fails and remains unchanged. The historical suite is **31/32 passing**; this receipt explains the intentional behavioral difference rather than converting it into a historical pass.

The challenge changes the global Piano default to three staves while preserving explicit reviewed examples with two Piano staves. The new matcher learns those local counts. I directly viewed the hash-bound original page and compared every returned source ID and derived part group against the frozen independent source golden:

| Physical system | Original source grouping | Returned candidate IDs | Local counts |
|---|---|---|---|
| 2, beginning at printed 5 | Piano only | Piano `[2, 3]` | Piano 2 |
| 4, beginning at printed 15 | Voice above Piano | Voice `[7]`; Piano `[8, 9]` | Voice 1; Piano 2 |
| 5, beginning at printed 20 | Voice above Piano | Voice `[10]`; Piano `[11, 12]` | Voice 1; Piano 2 |

All 13 detected staff positions agree with the original PDF line geometry within one native pixel; the largest distance is 0.15917 pt. The Piano-only proposal still requires its own confirmed measure count for the absent Voice. Every proposal leaves both starting measure and measure count unset.

The unchanged historical harness does not serialize the new `staffCounts` property. This audit derives the counts from each result's linked reviewed seed and verifies the frozen matcher construction and UI forwarding code. The separate [49-control native review](../system-staff-count-independent-2026-10-03/README.md) tests actual count forwarding. No additional matcher or detector execution was performed here.

Comparing all existing old/new result records while excluding elapsed time gives **30 exact semantic matches**, one diagnostic-only change, and the intentional Notte proposal change. The diagnostic-only Mendelssohn subgroup case still produces no suggestions; it now reports the incomplete source connection explicitly. Thus 31 assignment outcomes remain unchanged, not 31 exact JSON records.

This is a bounded source-identity and compatibility review. It does not certify all source recognition, crop quality or output layout. The earlier independent staff-count report remains frozen and unchanged.
