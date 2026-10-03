# Independent numbered-line ownership controls — frozen setup

This is an evaluation setup frozen before inspecting or executing the next crop candidate. It contains source rasters, independent musical ownership masks, a native evaluator, and comparison tools. **No candidate result or crop improvement is claimed.** Production and existing outputs are unchanged.

The motivating risk is specific: a numbered staff-line path can pass through a notehead, stem, beam or tie. Explaining that row as a staff line does not establish that its pixels or attached branch are exclusively structural. The [lossless spine-and-branch study](../brahms-spine-branches-2026-10-03/README.md) preserves these competing roles; its source reconstruction alone does not establish correct final crops.

## Frozen inputs

| Family | Source images | Ownership | Analysis scales planned |
|---|---:|---|---|
| Original four-core filled/hollow/tied/stem controls | 12 | All 48 original owner masks copied byte-exact | 1.0 |
| New mixed musical/structural contacts | 8 | Full chord owned by both upper staff views; independent barlines continue across four cores | 0.5, 1.0, 1.5 |
| New genuine structural controls | 4 | Notes, stems and ties stay local; barline carries no musical owner | 0.5, 1.0, 1.5 |

The new musical sources place filled or hollow heads on numbered lines 1, 2, 4 or 5. The inner-line cases also have a curved tie contacting the upper line at its endpoints. Two independent aligned measure columns coexist with the mixed chord corridor, so their presence cannot by itself authorize removing its musical ownership. Structural controls use single, double, interrupted and bowed-line cases. Their notation remains separated from the vertical barline corridor except through horizontal staff pixels.

There are 24 source images, 96 masks, and 48 planned source/scale observations covering 192 owner observations. Every owned pixel is verified to be black ink in its source. Original PNG files and decoded pixels are separately bound. Representative new filled/hollow and interrupted/bowed sources were viewed directly; the original p35 context and detail were inspected before setup.

The real-source binding retains all nine saved Brahms corrections, the immutable ten full target guards, and all thirteen local obligations. The existing p35 Violin I bottom-68 guard failure remains a failure. The final p35 Violin II local region begins at x337.5; the older narrower local oracle is not used. Source p35’s last beams, ledger notes, stems, dots and lower slur remain protected. Local visible-ink clearance cannot replace a failed full-target guard.

Protocol SHA256: `1743e4101ce9f0ae66c8778c20fa24779e1cd75195d96ab92bb1db4f62d9f5fd`.

Input manifest SHA256: `7a525cfdf73b1b5d7b47875f6b1723a5e2d22c025fbaa7de3aa22f0dfad909d5`.

These hashes were sent to root before any new candidate inspection. No outcomes were disclosed to a candidate author.

## Evaluation contract

The evaluator runs actual notation analysis and crop planning against fixed source pixels and fixed staff geometry. It records each final crop, exact lost owner-pixel indices, assignments and neighboring complete staff cores. Original full-resolution pixel cells define containment even when the analysis raster is scaled.

The comparison uses lost-pixel **sets**. Losing a new note pixel while recovering an unrelated pixel is still a regression, even when the total loss count stays constant. Every previously lossless owner must remain lossless. Existing omissions stay recorded against the unchanged source masks; the test does not silently restrict results to the previously passing upper owners.

A structural positive requires both complete own-notation preservation and exclusion of every whole neighboring core. Merely retaining a broad shared component is not a successful separation. If a candidate exposes typed graph payloads, their source reconstruction and musical ownership must be audited separately. Crop containment does not prove that internal channel labels are correct.

The native evaluator type-checks against the frozen production analysis/planner dependencies. Four artificial result-record checks verify unchanged inputs, equal-count pixel substitution, mismatched source binding, and wrong assignment detection. Those checks do **not** execute the analyzer or establish crop performance. The first type-check needed an explicit Swift `[Double]` annotation; both logs are retained and no input changed.

## Running a later evaluation

Extract `frozen-inputs-and-harness.zip` into a private directory. It contains the complete input tree, scripts, frozen baseline dependencies, real-source bindings, and the metric self-check records. Then use separate output directories:

```sh
bash run.sh /path/to/frozen/baseline/Core inputs baseline-run
bash run.sh /path/to/frozen/candidate/Core inputs candidate-run
python3 compare.py baseline-run/results.json candidate-run/results.json comparison.json
```

The bundled `baseline-core` can also be passed directly as the first argument. `check-real-guards.py` accepts baseline inventory/plan, candidate inventory/plan, and a result path. Missing bands are explicitly reported. `archive-manifest.json` binds all archive members; `input-manifest.json` binds the 241 input files independently.

No broad corpus run, permanent-suite rerun, full Auto workflow, PDF export, or new candidate test has occurred at this freeze. These are bounded adversarial controls, not a universal musical ownership proof. Later results should be stored separately without changing this protocol or its source masks.
