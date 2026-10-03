# Independent original-source musical-span challenges — frozen setup

These challenges were frozen before viewing or executing the new musical-span prototype. They test whether original head/stem evidence survives scan breaks without treating nearby notation as a shared cross-staff phrase. No candidate performance or crop improvement is claimed. Production and existing source oracles remain unchanged.

## Inputs and ownership

| Family | Original source images | Analysis scales planned | Owner observations |
|---|---:|---|---:|
| Unchanged mixed four-core controls | 12 | 1.0 | 48 |
| Exact original case 176 | 1 | 1.0 | 3 |
| New filled/hollow broken musical stems | 2 | 0.5, 1.0 | 12 |
| New barline/head proximity and detached-symbol negatives | 6 | 0.5, 1.0 | 36 |
| Total | 21 | 29 source/scale observations | 99 |

All twelve original four-core sources and all 48 original owner masks are copied byte-exact. Their first-two-staff musical chord may share a physical corridor that continues structurally through two lower staves. That continuation does not give the lower two staves ownership of the chord. Existing losses remain recorded against the complete original masks.

The eight fresh sources add complementary cases without a large parameter grid. Two contain filled or hollow endpoint heads on a shared stem with two literal scan gaps. Four contain local filled/hollow notes near an intact or interrupted bare barline: a six-column white gap separates musical ink from the barline off the staff rows. Any remaining connection passes through horizontal staff pixels. Two others contain a detached p-shaped dynamic or sharp-shaped accidental at least three white columns from the barline. Those symbols belong only to the upper staff. None of the six negative sources permits a shared musical interval.

Source-only checks verify those gaps and that every owned pixel is actual source ink. The original case 176 source and representative new positive/negative sources were viewed directly. Source masks were not inferred from analyzer boxes or crop results.

## Case 176 requires full recovery

The exact original source PGM and middle-owner PGM are preserved from the rejected numbered-line V2 audit. The unmodified source constructor is reproduced without running an analyzer. Reconstructed source pixels equal the original source exactly; the middle mask equals its original exactly; all three owner envelopes agree with the original 297-case record.

The middle owner has **1,400 source pixels** and envelope **[218, 190, 609, 539]**. A successful claim must retain every one of those pixels and that full envelope. Recovering only V2's nine additional losses, or restoring the baseline crop with 650 missing pixels, is not success. The other two original owners are also evaluated without weakening their masks.

A metric self-check uses the exact original source mask to reproduce the 659→650 nine-pixel repair and confirms that the full-recovery claim still fails. A separate full-envelope example succeeds. These are checks of the comparator, not native algorithm results.

## Evaluation contract and readiness

The evaluator retains exact lost-pixel sets for every owner, so equal aggregate pass counts or loss counts cannot hide new omissions. It separately records complete neighboring cores and source-defined permitted shared groups. Spurious neighbors in the negative controls cannot be excused by successful recovery elsewhere.

For negative sources, the comparator also identifies newly exposed multi-owner `ScoreInkComponent` alternatives, even if existing padding hides their effect on final crops. If the prototype exposes musical-span evidence through another representation, its owners and endpoints need an additional logging audit against these same frozen sources; final crop containment alone is not sufficient.

The native evaluator type-checks. Six comparator checks cover unchanged records, nine-pixel-only repair, full case 176 recovery, latent false shared alternatives, new spurious neighbors, and mismatched source binding. No analyzer, candidate, broad corpus, full Auto workflow or export has run at this freeze. The ten existing Brahms full guards and thirteen local obligations remain hash-bound, including the prior p35 bottom-68 failure.

Protocol SHA256: `c9db2b2fe07950ab4b56b48dd5b555737f3801edd30696cf315d2ebca38032cc`.

Input-manifest SHA256: `106c6ce623585187f95a49a8327ffaa28323e2a988e77b86f73968d5b3101c21`.

Both hashes were sent to root before candidate inspection. Wait for an author-supplied frozen candidate hash. Extract the evidence archive into a private directory and use `run.sh FROZEN_CORE inputs OUTPUT_DIRECTORY`, followed by `compare.py BASELINE_RESULTS CANDIDATE_RESULTS COMPARISON_JSON`. The archive contains all inputs, original source references and constructors, self-check records, and evaluation code. Manifests verify every member. Later results must remain separate from this immutable setup.
