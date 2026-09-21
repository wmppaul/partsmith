# Complete input corpus quality control

`corpus.json` inventories every PDF under `sample_scores/` and the lossless regression excerpts under `Tests/extraction/sources/`. It currently contains **36 PDFs and 1,477 physical PDF pages**: 34 separately downloaded source files (1,474 pages) and two excerpts (three pages). No input files have identical SHA-256 hashes. Different scan/edition IDs of the same work remain separate evaluation inputs; the lightly/medium skewed collections are not artificial distortions of a single source.

Generated outputs, exported parts, `.build` artifacts and copies embedded in saved projects are excluded. They are results or duplicates to verify against the corpus, not additional independent source scores.

`inventory_corpus.py` refreshes source metadata without modifying PDFs:

```sh
.build/extraction-venv/bin/python Tests/quality_control/inventory_corpus.py
```

The script requires PyMuPDF. The runner itself uses only Python's standard library.

## Run every page

Build the native analyzer into an immutable location first. The script below compiles the same production detector and planner used by the existing `tools/score_extraction_batch.sh` command:

```sh
bash tools/score_extraction_batch.sh --build-only
mkdir -p .build/auto-qc/baseline
cp .build/score_extraction_batch .build/auto-qc/baseline/score_extraction_batch
python3 Tests/quality_control/run_corpus.py \
  --executable .build/auto-qc/baseline/score_extraction_batch \
  --out .build/auto-qc/baseline --jobs 2 --inventory-only
```

The runner includes unsupported or not-yet-profiled scores in raw detection. It continues after a per-file failure and records the failure. Every physical page is required, including covers and blanks. `--id` can be repeated for a focused rerun; omit it for the full corpus.

Re-running the same command resumes completed inputs only when source hash, native executable hash and inventory JSON hash agree, and native page indices cover the complete input. A new native executable invalidates detection caches. Keep baseline and candidate executables/output roots separate when comparing algorithm versions. An existing process is inspected before a resumed invocation can overwrite its work. A corpus-directory advisory lock prevents simultaneous runners in the same directory.

`--adopt-inventory PATH` is an explicit assertion that an externally started, now completed inventory came from the selected executable. It checks source hash and full page coverage, then records this attestation; the old native inventory format does not itself store an executable hash. Do not use it for old inventories of uncertain provenance.

Each input has a stable directory named by its corpus ID, with `progress.json` (native PID and latest completed page), `inventory.log`, cache metadata and `result.json`. The top-level `aggregate.json` is updated atomically and preserves corpus order with pending/error entries. Zero exit status means the requested diagnostics ran without a process/file error; it does **not** mean extraction quality passed. Exit 2 means an orphaned native worker was verified still running and was left untouched.

## Plan, export and review

Omit `--inventory-only` to additionally run the native planner for sources with a profile. All36 sources now have at least an initialization profile; the original baseline used nine. `corpus-profile-additions.json` records source hashes, profile hashes, sampled pages and known exceptions for chamber/vocal scores and the corrected variable-layout Notte setup. `profile-additions-2.json` adds16 orchestra/choir/excerpt profiles:14 require explicit system assignment, and La Bohème has only an incomplete opening-role roster. A profile's existence does not prove complete instrumentation or authorize fixed cadence. The supplied compact profiles do not reuse historical crop rectangles or page overrides. Source OCR name discovery is not tested by these initialized profiles.

Planning records one of `missing_verified_instrument_profile`, `unresolved_native_plan`, `native_plan_error` or `planned_visual_review_pending`. Staff-count divisibility and `canApply` are insufficient evidence that assignments are right. Missing profiles and changing instrumentation remain explicit unfinished work, not passes or excluded samples. The Mozart concerto profile deliberately requires system assignment, since fixed cadence could assign silent omitted instruments to the wrong visible staves.

For a source with a reconciled instrument profile, the existing export path exercises the app's apply transaction and production layout/exporter:

```sh
tools/export_score_plan.sh \
  --inventory PATH/TO/inventory.json --profile PATH/TO/profile.json \
  --title 'Work title' --composer 'Composer' --out .build/auto-qc/outputs/score-id
```

Optional `--overrides` are manually reviewed corrections and must be reported separately from Auto results. Use `tools/review_score_output.py OUTPUT --map INDEPENDENT_SOURCE_MAP --pixels` for source/system coverage and pixel preservation, then independent visual comparison of all extracted parts and difficult crop edges. Reviewed maps need a matching source hash and actual staff/notation coverage; reusing a map generated from the same unverified detector is not independent evidence.

The corpus runner uses raw source pages with internal analysis skew handling. Separately run the native inventory command with `--deskew` to exercise Magic Wand's optional rectification first, at the same analysis raster scale. That inventory records the correction geometry. The exporter saves those corrections in the editable project and includes a hashed full-page `rectified-review-source.pdf` for comparison in corrected coordinates. Raw source maps must not be reused for corrected crops; corrected maps must explicitly record the same rectifications. Inspect the immutable original as well to verify the correction itself. A raw baseline cannot establish the optional rectified workflow. Name detection, page selection, rectification, silent omitted instruments, printed rest counts, source headers, output pagination and practical page turns need their own checks where applicable.

The experimental `headings --inventory JSON --profile JSON --out JSON` command adds locally recognized printed movement/tempo headings to a copy of an inventory. It preserves source pixels through the existing shared-marking export mechanism. It does not recognize all rehearsal letters, endings, repeat directions, or omitted rests, and is not yet enabled in the app. Compare its complete result against independent source-direction oracles before enabling it.

`compare_corpus.py BEFORE_AGGREGATE AFTER_AGGREGATE --out JSON` records staff geometry changes and component ownership across complete runs. These counts diagnose missed structural separation but do not establish musical preservation. `test_review_coordinate_binding.py` rejects mismatched source hashes, raw/corrected coordinate swaps and truncated or resized corrected reference PDFs.

## Completion requirements

For every original input, establish the printed roster/order through the complete work, including movement changes and omitted staves. Reconcile all physical staves and every intended musical system against the source; preserve outlying notes, stems, ledger lines, slurs, lyrics and shared directions. Count omitted silent spans rather than silently skipping time. Render every output part and have another reviewer inspect the actual result. Excerpt successes, source metadata, raw staff totals, green process exits and legacy reports are narrower evidence and cannot establish complete-corpus quality.
