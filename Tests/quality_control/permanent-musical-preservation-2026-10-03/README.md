# Permanent musical preservation regressions

The current production analyzer passes **796 crop-quality checks**: every original line and all 765 previous assertions remain unchanged, plus 31 new checks. Both rejected geometry shortcuts fail their corresponding new focused mode. No production code changed for these tests.

The new assertions retain only source obligations that already passed before the rejected changes:

- Three complete diagonal/curved musical cases, with both source-defined physical-staff owners retained: straight stroke at 1× and 1.5×, curved stroke at 1.5×.
- Four full-resolution damaged, four-core cases with filled/hollow and tied/untied noteheads. **Only the previously lossless upper owner is asserted.** Other owners have known omissions, so these are not whole-case passing claims.
- Fourteen SHA256 checks bind the exact decoded gray source pixels and ownership masks, seven checks require valid complete plans, and ten checks retain the full source-owned pixel envelopes.

`validation.json` preserves the original test run and every source, test, binary, and log hash. `current.log` records the 796-check success and the preexisting three-row-gap annotation limitation. The rejected row-width candidate fails on the 1× diagonal upper owner; the rejected four-core candidate fails on the filled outer-line upper owner. The failure is a musical source-pixel assertion, after its source/mask hash checks have passed.

The positive run uses the current rest-heading planner (`77212ba8…`). Each negative run uses its exact rejected prototype snapshot, including its earlier frozen planner. These fixture cases contain no generated rests or heading copies; the original paired baseline/candidate studies establish the analyzer-only cause. The source archive retains all three exact six-file compilation inputs, the before/after test file, and the two independent fixture constructors. No executable is duplicated here; the retained private binaries are bound by hash.

Reproduce the current full suite with `bash tools/test_crop_quality.sh`. Focused modes are `--thin-musical-regression` and `--four-core-upper-regression`. For historical snapshots, extract `sources.zip` into an isolated directory and use its `build.sh CORE test_crop_quality.swift OUTPUT`, then invoke the produced binary with the respective focused argument. The archive member manifest binds all inputs. No existing source mask, source guard, candidate snapshot, or original report was changed.

The [four-core study](../four-core-independent-2026-10-03/README.md) includes complete results and viewed source panels. The independent row-width study remains bound at `.build/brahms-remaining-2026-10-03/thin-independent`; its exact source constructor is preserved in this archive. These regressions prevent two demonstrated omissions; they do not establish complete musical recall.
