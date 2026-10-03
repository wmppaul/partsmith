# Terminal-body continuation study — rejected candidate

**No analyzer change is promoted.** This study is frozen against `d2a43e1689bc35525f4ca88529f9cc652c4db772`. Candidate v1 reduces unwanted neighboring notation on seven targeted source pages, but creates **21 new musical-envelope failures and 103 worsened owner envelopes** in the unchanged 297-case source controls. The user's requirement to retain intended notes takes precedence over cleaner crops. Production and all frozen source oracles are unchanged.

The study addresses the two extra whole-neighbor crops on corrected Brahms 93521 page 38 and the 20 expanded diagnostic rows in the prior corpus review (18 added a whole neighboring staff core). It does not recertify either full score or the corpus. The preserved baseline already has 59 failing cases in the 297 controls, plus additional limitations in the newly authored controls; these failures remain explicit.

## Mechanism and exact source evidence

The current terminal-head witness accepts a compact off-spine patch and checks the attached **analysis-mask** component on the selected side of the physical stroke. Source staff-line erasure can detach part of a long curve, and a compact tip on one side can hide a long attachment on the opposite side. The planner correctly treats the resulting ownership alternative as outward-only evidence, but the witness can incorrectly assign a whole neighbor to the target.

All **13 exact witness panels on 12 source pages** were inspected; see `source-review.json`, `source-review-images/`, compressed `results/diagnostic-witnesses.json.gz`, and `branch-summary.json`. Logging-only baseline analysis reproduces each frozen component multiset exactly. Candidate replay uses the identical source PDF bytes and native raster bytes. The corrected p38 image is saved with this report: its re-encoded diagnostic PNG has identical decoded RGBA pixels to the frozen rectified raster. Corrected coordinates were never applied to raw PDF pixels.

On corrected p38, the physical stroke is x `[409,411)`. The accepted source patch is `[411,374,414,376]`, at roughly 8.116 pixels per staff space. The right analysis branch contains only **9 pixels**, while the directly attached left branch continues through `[361,336,409,379]` with **704 pixels**. The red witness is a small end of a Cello curve crossing a barline, not a notehead belonging to both Viola and Cello. Broken staff fragments account for the source witnesses on Schumann 51506 p3 and Beethoven 52624 p30/p32. Other inspected witnesses occur where slurs/ties meet a barline; several become compact only after line erasure.

V1 changes only the initial flood seeds: it follows the entire directly connected original horizontal run on each witness row and checks both off-spine sides. There is no white-pixel bridging and no changed threshold, crop margin, planner rule, or fixture. The rejected diff is `candidate-v1.patch`; both 23-file Core snapshots are in `frozen-core.zip`.

## Results and rejection

| Check | Frozen production | Rejected v1 | Interpretation |
|---|---:|---:|---|
| Current permanent crop checks | Existing checkpoint | 765/765 pass | Includes the outward-only native-raster regression. The third detached annotation `[610,295,620,304]` remains a printed known limit. |
| 297 independent source envelopes | 238/297 pass | 217/297 pass | **21 newly failing cases**, zero repairs; **103 worsened owner envelopes**, including already failing cases. |
| 336 expanded source fixtures | 336/336 pass | 336/336 pass | Every decoded result, including crop bounds, is exactly unchanged. |
| New independent terminal-body controls | 122/180 pass | 122/180 pass | All crops unchanged; 58 existing failures remain, including hollow-head failures. All 72 pure structural cases retain local music and avoid a whole neighbor. |
| New tied-head supplement | 12/36 pass | 12/36 pass | All crops unchanged; 24 existing failures remain. |
| Targeted native source replay | 12 cached pages | 7 changed pages | Seven ownership alternatives removed, no ordinary component changed, 13 bands changed. |

The 21 newly failing earlier controls comprise nine `edgeMusicNearEdge` and twelve `ledgerAliases` cases. Full source envelopes, transforms, raster sizes and owner identities were verified unchanged. Opposite-side source staff/ledger fragments can become part of the analysis-component compactness test and wrongly reject the genuine notehead. More generally, the full extent of a connected branch cannot define a notehead: a real head can have a long attached tie.

The independent review is bound in `evidence-bindings.json` to `../terminal-body-independent-2026-10-03/candidate-v1-review.json` and both unchanged-mask comparison results. Passing the new 216 cases as a nonregression subset does not override the earlier 297 failures. No v2 source rule was implemented merely to improve the counts.

## Actual source replay and p38 visual comparison

The seven changed pages are Brahms 317803 p9/p24/p28, Schumann 291222 p41/p47, Beethoven 52624 p32, and corrected Brahms 93521 p38. The five unchanged pages are Brahms 317803 p10, Schumann 51506 p3/p44/p63, and Beethoven 52624 p30. `component-changes.json` stores all seven removed alternatives; `targeted-plan-comparison.json` stores every changed band. The eleven diagnostic pages use one physical staff per neutral part. Corrected p38 uses the existing four-part quartet profile. This is cached-staff native component replay plus replanning, not a fresh full-document staff-detection run.

For corrected p38 system 1, Viola's bottom changes from `0.25942888557624194` to `0.21846659688963602` (displayed native rows 399→336). Cello's top changes from `0.14889149671730786` to `0.19505534587205428` (229→300). The whole first-system source and both before/after source crops were visually inspected. The displayed intended notes, ledger lines, slurs, tenutos and final *f* remain visible in this local comparison; both crops still contain neighboring fragments. This observation is **not** a new pixel-level target oracle or a whole-score preservation pass. It cannot excuse v1's known source losses elsewhere.

No full 39-page worker, 36-score corpus run, PDF export or pagination review was spent on this already rejected candidate. None of the study images are new published part PDFs.

## Why a thickness threshold is not the next fix

`source-body-profiles.json` measures unchanged source pixels: local filled-square thickness outside the physical spine, ink area, and bounded white regions. It covers all 13 real witnesses plus 72 full-resolution independent source images (24 source geometries × three transforms). These measurements are diagnostic; their boxes do not define or weaken any musical source mask. The profiles use native scale-1 fixture pixels and do not claim equivalence to the native 0.5/1.5 resampling. Fixture boxes are anchored at authored endpoints; real-source measurements explicitly retain both observed-witness and outer-line anchors.

Observed false-body windows contain 2–6-pixel filled squares, roughly 0.24–0.73 staff spaces. The straight filled-head fixture contains a 10-pixel square at 14-pixel spacing (0.71); the hollow head contains only 3 pixels (0.21). Six of the 13 false-witness body windows also contain closed white regions. Staff/curve intersections and nearby true notes can supply local mass, and intersections can create cavities. Thus neither thickness nor the existence of a white enclosure establishes that this particular barline endpoint owns a notehead. The measurements show feature overlap, not an impossibility proof for all future recognition.

The next defensible approach needs source provenance connecting a compact filled or hollow body to its actual musical stem endpoint, separately identifying a continuing structural spine and thin curve. Evidence lost through analysis erasure must remain recoverable. True tied heads, hollow heads, interruptions and low-resolution ambiguity need explicit source controls before changing the preservation decision. The no-new-or-worsened-loss requirement and the outward-only planner semantics remain mandatory.

## Evidence and reproduction

`evidence-bindings.json` binds all frozen source files, binaries, original PDFs, native images and independent reports. `report-hashes.json` binds every durable file below this directory. Large original PDFs and native binaries remain in their recorded locations; full JSON is gzip-compressed without content changes. The corrected p38 native raster is included to retain the nine-rectification coordinate binding.

From the repository root on the same Mac with Xcode, run:

```sh
bash Tests/quality_control/terminal-body-continuation-2026-10-03/reproduction/reproduce.sh .build/terminal-body-reproduction-new
```

The script requires a new output directory, verifies/extracts the frozen Core, runs the 765/297/336 checks, and replays/replans all 12 targeted pages. It was syntax-checked; the component commands were individually run for the recorded evidence. It deliberately does not use current production Core or rerun the known-rejected candidate across the entire corpus. The independent report's `build.sh`, `build-tied.sh` and `compare.py` reproduce the additional 180/36 comparisons using the extracted candidate Core. Logging-only `diagnose.swift` and its exact diagnostic analyzer are included; replacing only the baseline analyzer with that diagnostic copy reproduces the witness capture. Analysis/profile and source-crop rendering scripts are included for inspection, with their original scratch-layout paths explicit.
