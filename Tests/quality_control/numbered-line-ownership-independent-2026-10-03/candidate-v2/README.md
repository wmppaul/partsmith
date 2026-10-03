# Candidate v2 — bounded preservation passes, broader regression rejects it

**V2 is rejected.** The author verified nine newly excluded stem pixels in a separate, already failing source fixture. Its total lost pixels increase from 650 to 659, even though the larger suite's aggregate pass count remains unchanged. The [source-mask proof](author-case176-source-loss.json) and [author's source panel](author-case176-source-panel.png) are copied and hash-bound here; this reviewer did not independently rerun that fixture. The independent passing subset below does not override that loss.

The tested Native analyzer SHA256 is `b5f86b6597f35d6507c1ffc5cd97efb5d8c5bacef9226e59b2e5616f9babbf09`. It is the only file differing from the supplied frozen baseline Core. All frozen sources, ownership masks, evaluator, comparison code and input hashes are unchanged. The original baseline results were reused without rerunning or redefining them.

## Independent checks

Across the same **48 source/scale cases and 192 owner observations**, V2 preserves exactly the baseline lost-pixel sets. No pixel is newly lost or recovered; complete owner observations remain **124 / 192**. All 68 incomplete observations remain failures against their unchanged ownership masks. All twelve genuine structural cases preserve their own source pixels and exclude whole neighboring staff cores. Plan and assignment invariants pass.

There are 36 changed crop/neighbor observations across 34 cases, without changed loss sets. The exact comparison JSON equals V1's comparison byte-for-byte. V2's native evaluation measured 0.956 seconds versus the saved baseline's 0.261 seconds, excluding compilation. These are individual measurements under concurrent work, not a performance guarantee.

The fresh p24/p28 replay is bound to SHA256 `c81a854460359846b62a565b6ab7f847f3c7980408403c79551494555db010c5`. Its source rasters, staff geometry, dimensions and nine saved corrections agree with the frozen source binding. All **four available full target guards** and **nine available local source/ink envelopes** pass unchanged. This guard output also equals V1's output byte-for-byte. Complete visual review of the changed real crops belongs to the crop agent's separate report.

P29, p31 and p35 were not replayed. Their six full guards and four local obligations remain untested for V2. The earlier p35 Violin I bottom-68 failure remains preserved as baseline evidence. As in V1, the frozen helper's raw aggregate arrays treat missing bands as false containment; `real/guard-scope.json` explicitly separates available passes from missing pages using the unchanged per-record availability flags. Missing pages are not certified passes or observed candidate regressions.

## Why the broader result prevents promotion

The author reports recovery to 336/336 in the larger source-envelope grid. That does not establish preservation in every previously failing case of the separate 297-case grid. In case 176 (`edgeMusicBroken`, scale 1, tilt 0, bow 10), the crop top moves from 212 to 215. The unchanged source owner mask contains previously retained stem ink at **x600–602, y212–214**. Those nine pixels are lost, with no recovered pixels. This is precisely the kind of worsening that aggregate pass counts can hide.

The copied proof has SHA256 `5433786a32c164db3bf4ac79ab264eeeaa9c2d924201a3aed84caf3ee49f91b4`. It is author evidence, distinct from this reviewer's 48-case run. No expected crop, source envelope or loss tolerance was changed in response.

## Evidence and scope

`results.json` retains every exact owner loss set, crop, component and source binding. `comparison.json` contains all geometry changes. `source-and-replay-evidence.zip` preserves the frozen candidate Core, source replay, original referenced inventory, saved rasters, bindings and derived guard inputs. Manifests verify every artifact; executables are excluded while their hashes are recorded.

No new baseline run, broad corpus worker, full Auto extraction, part export or production change was performed. These controls provide bounded preservation evidence, not universal safety for numbered-line erasure or branch ownership. V1 and V2 remain separate rejected experiments; the immutable baseline and test inputs are preserved.
