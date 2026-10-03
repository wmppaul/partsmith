# Numbered staff-line separation: V1 and V2 rejected

Both private candidates remain rejected. V1 creates 18 new musical-envelope failures. V2 restores those cases but still removes **nine additional source-owned stem pixels** in an existing failing fixture. Production `NativeScorePageAnalyzer.swift` remains byte-identical to the starting implementation. No full-score corpus run, output export, or application promotion was performed.

The experiment tested whether source-measured line curves and thickness could remove the residual staff pixels connecting the broad Brahms p24/p28 components. It does establish that the old straight-line mask misses real scan geometry. It does **not** establish that replacing that representation preserves musical ownership.

## Source and implementation freeze

The original source cases, four-core musical masks, immutable target guards, dependency snapshot, and hypothesis were frozen before candidate results. See [input bindings](inputs-before-results.json), [hypothesis](hypothesis-before-results.json), and [exact V1 procedure](implementation-before-results.json). The saved nine Brahms page corrections were retained. Original p24 was measured at 1800×2593; corrected p28 at 1068×1538.

At p24's right spine, staff 6's sustained source lines lie roughly 3–4 pixels above the global straight-line predictions and occupy 3–4 rows. Near p28's interior spine, source lines occupy asymmetric 2–3-row runs around the predicted centers. A fixed removal strip can therefore leave genuine staff ink attached to notes or barlines. These observations motivated the change; neither source masks nor musical guards were changed afterward.

V1 measures thin original vertical runs within a numbered line's less-than-half-space corridor. A six-space window requires 80% support, with at least three agreeing numbered lines. Supported curves use measured run thickness and preserve the original crossing-stem veto. Unsupported columns retain the legacy separation. Connector tests, source pixels, staff identities, ownership rules, and the crop planner were unchanged.

V2 keeps V1's component representation and retains the exact old line-separation mask separately for the existing terminal-body feature check. Subsequent connector cuts are mirrored into both masks. It does not union crop results or loosen body/connector thresholds. Its [protocol](v2-protocol-before-results.json) was frozen before execution.

| Source | Native SHA256 |
|---|---|
| Starting production | `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01` |
| Rejected V1 | `48942112506f88d4804a673c4bee2610886bc944fab87853df2c2b596447c4a4` |
| Rejected V2 | `b5f86b6597f35d6507c1ffc5cd97efb5d8c5bacef9226e59b2e5616f9babbf09` |

## Unchanged controls and decisive failures

| Check | Baseline | V1 | V2 |
|---|---:|---:|---:|
| Current permanent crop checks | — | 796 pass | 796 pass |
| Frozen 336 musical envelopes | 336 complete | 318 complete | 336 complete |
| Frozen 297 source-envelope cases | 238 complete | 238 complete | 238 complete |
| Four-core controls, 36 cases | Existing losses retained | No worsened owner loss | No worsened owner loss |

The permanent suite still prints its existing limitation for a detached three-row-gap annotation outside the upper crop. The frozen 297 set still has 59 incomplete cases. Counts alone obscure the new damage within one of those cases.

**V1 changes the musical feature representation.** For scale 0.5, tilt 0, head style 1, inset 3, it erases no additional pixels and restores 48 original pixels. Those restored pixels include actual notehead rows. The old compact-body check rejects the fuller shape and changes the musical stem's decision from protected to structural. Both crops then lose the full cross-staff musical envelope. The source/mask panel and exact delta are [preserved here](failure38-endpoint-panel.png) and [here](failure38-mask-delta.json). V1 has 18 newly failing cases at scales 0.5 and 0.6. V2's separate legacy feature input restores all 336 envelopes without changing the real p24/p28 crop results.

**Both versions worsen an already failing broken-stem case.** Frozen 297 case 176 is `edgeMusicBroken`, scale 1, tilt 0, bow 10. Its middle owner already loses part of a source-authored musical stem across a scan break. The candidate raises that crop's top from 212 to 215, increasing exact lost owned pixels from 650 to 659. The nine newly excluded pixels are `x600..<603 × y212..<215`; no previously lost pixels are recovered. The untouched fixture assigns these stem pixels to all three musical owners. The source break is at rows 227–234, so the newly lost pixels are actual surviving stem ink above the break.

The one-case native replay exactly matches the corresponding full 297 result. Its rendered source and ownership mask verify every owned pixel is original black ink. See [source loss record](failure176-source-loss.json) and [source panel](failure176-source-panel.png). No failing expectation was changed or treated as exempt. This new loss is sufficient to reject V2 even though its complete-case count is unchanged.

The separate [numbered-line ownership evaluation](../numbered-line-ownership-independent-2026-10-03/README.md) also ran 48 frozen source/scale cases. Its zero-new-loss result is a bounded additional check and cannot override the case 176 regression. Its real-source checks cover only the four available p24/p28 full guards and nine local obligations; they do not imply p35 or complete-score coverage.

## Actual Brahms p24/p28 review

Both native replays retain the exact source staff geometry and assignment identities. Their plans and component multisets are identical to each other; component serialization order can differ. Twelve crop rectangles change from the production baseline. All twelve full-width source contexts were viewed, including neighboring notation on both sides of each changed edge. No newly omitted intended notation was observed in these twelve regions. Frozen p24/p28 guards remain satisfied. This local observation does not waive either synthetic musical regression.

| Crop | Baseline top–bottom, points | Candidate top–bottom, points |
|---|---:|---:|
| p24 s1 Cello | 125.396–170.633 | 127.056–170.633 |
| p24 s2 Violin I | 172.120–222.812 | 172.120–221.152 |
| p24 s2 Viola | 241.138–311.753 | 241.138–297.523 |
| p24 s2 Cello | 241.138–316.497 | 246.356–316.497 |
| p24 s4 Violin II | 492.309–539.443 | 492.309–538.257 |
| p24 s4 Viola | 521.719–562.686 | 524.328–562.686 |
| p28 s1 Violin I | 17.592–93.570 | 17.592–87.972 |
| p28 s1 Violin II | 21.591–107.566 | 43.184–107.566 |
| p28 s1 Viola | 79.172–139.155 | 81.572–139.155 |
| p28 s2 Violin I | 151.549–206.733 | 164.345–206.733 |
| p28 s3 Viola | 373.477–423.463 | 373.477–428.661 |
| p28 s4 Viola | 514.231–567.416 | 519.429–567.416 |

The four troublesome target crops remain broad, often retaining four or five neighboring staff lines. A reduction in a whole-core count would not establish clean output. The largest other tightening, p28 s2 Violin I, removes the previous system's Cello fragments while retaining the current high ledger notes, slurs, hairpins and forte. The p28 s3 Viola expansion retains its old source area and adds neighboring Cello residue. Individual findings and image hashes are in [real-crop-findings.json](real-crop-findings.json); all source strips are archived.

## Evidence and next requirement

[Summary](summary.json) records exact scope and decisions. `source-and-results.zip` contains frozen source snapshots, unchanged fixtures, comparison programs, all native results/logs, failure source masks, and twelve source-review images. It excludes rebuildable binaries. [archive-manifest.json](archive-manifest.json) binds all members; archive extraction and every member hash were verified. The scratch root is `.build/brahms-numbered-lines-2026-10-03`; `build-run.sh` runs a named frozen version/harness.

Before another line-separation change, musical ownership across source interruptions needs independent preservation. Cleaner staff removal can remove incidental line residue that currently enlarges a partly lost musical fragment. Preserving that source-owned stem requires more than a cleaner mask or a compact-body threshold adjustment. No further candidate was started after the nine-pixel failure was confirmed.
