# Frozen baseline evaluation

The frozen evaluator was run against the author-supplied baseline at `.build/brahms-numbered-lines-2026-10-03/baseline/Core`. All 25 source hashes and all 241 input hashes were verified before and after execution. The original protocol, sources, owner masks and real-source guards are unchanged. No candidate has been inspected or evaluated in this run.

| Family | Source/scale cases | Complete owner observations | Lost pixel observations |
|---|---:|---:|---:|
| Original musical controls | 12 | 28 / 48 | 3,682 |
| Fresh musical contacts | 24 | 48 / 96 | 8,852 |
| Genuine structural controls | 12 | 48 / 48 | 0 |
| Total | 48 | 124 / 192 | 12,534 |

All 48 plans apply and retain four assigned physical staff views. All 12 structural cases preserve every owned pixel and exclude all complete neighboring staff cores. None of the musical cases preserves all four owners: the exact baseline losses remain failures against their independent source masks. They are not removed from the evaluation or used to narrow its oracle.

`results.json` preserves every component, band, owner envelope, exact lost-pixel index, neighboring core and source binding. `summary.json` lists each case’s four owner loss counts and neighbor IDs. The comparison will reject any newly lost source pixel, including a substitution that leaves the aggregate loss count unchanged. Recovering existing losses and avoiding new losses remain separate reported outcomes.

The native evaluation measured 0.261 seconds, excluding compilation, on this host under concurrent work. This is a measurement, not a performance guarantee. The recorded run-log value includes subsequent result writing. No full score, real p35 analysis, permanent suite, full Auto workflow or PDF export was rerun here. The original p35 guard failure remains frozen for the separate real-source comparison.

Result SHA256: `1ad7b67dc204ef1a8750bbad4bc369f30c70616947978a6370905b06205cb990`.

Input manifest SHA256: `7a525cfdf73b1b5d7b47875f6b1723a5e2d22c025fbaa7de3aa22f0dfad909d5`.

The complete baseline Core is archived without executables. `source-hashes.json`, `run-bindings.json`, build/run logs and the unchanged frozen evaluator make the run reproducible. Candidate evaluation is held until its author supplies the frozen source hash.
