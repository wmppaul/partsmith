# Correction to real-score crop identities

The first README and agent status messages incorrectly reused V1’s p26 pair when describing V2/V3. All three had two changed crops and nine whole-neighbor occurrences, but the crop identities were different. The stored native results and comparison JSON already contained the correct identities and hashes. This was a reporting/review error, not a code, source-raster, or guard change.

The earlier README and 81-file manifest are preserved unchanged under `erratum-2026-10-03/`. Their historical manifest hash was `c860e956140ed8c89dfbe4f6842963e9550d6d56f7a8c378483fcb59ce675b66`.

| Version | Actual changed bands | Detail |
| --- | --- | --- |
| Source witness V1 | `p26-s1-violin1`, `p26-s1-violin2` | The source-witness patch inside a sharp touching the barline joins Violin I/II. The p26 source images and original diagnosis apply to this version. |
| Source witness V2 | `p38-s1-viola`, `p38-s1-cello` | The complete-branch check removes p26’s wider crops. A different accepted witness joins Viola/Cello on p38. V2 also raises the Viola crop top from87.9694408323 to88.3693107932pt. |
| Additive evidence V3 | `p38-s1-viola`, `p38-s1-cello` | V3 retains the wider lower/upper extents but restores the old Viola top. Both final crops are strict supersets of the baseline. |

`native-crop-identities.json` records every complete before/after rectangle and the bound native-result hashes. Neither the source controls nor the source guards were adjusted. The 297/336/755 numerical outcomes remain as reported. The complete-branch experiment has a real tradeoff: it removes the p26 sharp ambiguity but introduces a different p38 ambiguity while preserving three fewer near-edge synthetic cases than V1.

The combined geometry/preservation experiment therefore changes the p35 Violin I/II pair and the p38 Viola/Cello pair. It does not change p26. The optimized logging-only complete native39 run records exactly one musical separator veto: corrected physical p38, staff index2, x405–415. The optimized and unoptimized assignment records and component multisets are identical.

The corrected p38 source review is complete in `p38-source-review.json` and `evidence/p38-*`: the new witness is a local Cello curved tie/slur at a barline. Both V3 crops strictly contain their original source rectangles. A later independent native-raster omission counterexample blocks promotion of the untyped V3 union; see the README follow-up.
