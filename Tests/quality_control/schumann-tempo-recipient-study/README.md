# Schumann German/interstaff heading candidate — 3 October 2026

**Archived experiment; not promoted. Strict unchanged source-region recall is 14/15 tempo deliveries; all 15 song-index deliveries still fail. Three Voice duplicates remain.** Separately, visual inspection finds all 15 actual tempo words complete, and all 154 original music crops are preserved. A subsequent initial-override audit also reproduces automatic heading loss in current production and V3, with no validation of stale V3 recipient provenance. See [OVERRIDE-AUDIT.md](OVERRIDE-AUDIT.md). These are explicit promotion blockers; this is not a production-ready extraction workflow.

## Frozen source and scope

Original source: `sample_scores/lightly_skewed/05_schumann_frauenliebe_und_leben_op42_imslp_270922.pdf`, SHA-256 `d13fc3f4299dda634845b218222add8884ab9fd5257a9abb7cb2f9bcad4b9975`. The prior complete musical review is `Tests/quality_control/schumann270922-complete-review`.

`frozen-obligations.json` copies **all 30** independently source-inspected obligations before any experiment: 15 tempo deliveries and 15 song-index deliveries. It preserves their source regions exactly. All 77 systems and 154 original staff groups are retained. No source crop override, score-specific page rule, whiteout, erased ink, invented tempo text, or profile exception is used by final V3.

## Recognition and iteration

- Production runs genuine native Vision recognition over all 16 pages and delivers **3/15** frozen missing tempo obligations (Larghetto and two Adagios).
- V1 adds German vocabulary and instrument-first-staff regions. German-priority OCR harms confidence on some valid Italian text; incomplete regional success also suppresses useful full-page fallback. Exact region recall is 10/15 and it adds duplicate local copies.
- V2 keeps English recognition, adds common `Innig` OCR variants (`Iunig`, `lunig`), merges regional/full-page evidence, and joins vertically stacked Schneller/a tempo. It experiments with lower-edge separation at a blank raster row. This is **rejected for promotion**: trimming inside an OCR envelope is not a safe general source-preservation rule, and the Ave holdout receives an unwanted extra Soprano Adagio. V2 artifacts remain available; no observed missing Schumann tempo letter is claimed.
- Final V3 removes all lower-edge trimming and any profile-specific interstaff exception. It retains every existing production heading/copy rectangle unchanged, adds German phrases and full-page evidence, and scans the first staff of each actual instrument. It never treats interior piano-staff expressions as shared headings.
- New metadata records the actual source staff and allowed recipient part IDs. A recipient's correctly placed local heading must belong above its own first staff, have complete original-source ink inside its crop, and align at the same source x-position in the same system. An existing global heading supplies an equivalent repeated staff-group instruction without another copy. Equal text elsewhere, text below a target staff, missing ink evidence, or incomplete glyphs cannot substitute. Existing production globals are retained literally; no repeated-word glyph substitution occurs.

The source candidate is `candidate-v3.swift`; the model/planner candidate is `ScoreExtractionPlanner.swift`. `detector-candidate.patch` and `planner-candidate.patch` make the deltas reviewable. The source-staff/recipient policy is separately exercised by `recipient-controls.swift`.

## Complete native/output verification

Fresh V3 native recognition finishes **16/16 pages with zero OCR failures**. It identifies 19 printed tempo occurrences, including the already-local Noch schneller/Presto pair. That pair needs no new copies because each recipient retains its own correctly placed literal instruction. The native planner/exporter produces both complete parts: **Voice 77 systems/7 pages, Piano 77 systems/12 pages**. The 18 copied fragments comprise15 audited missing tempo deliveries plus3 disclosed Voice duplicates.

- **154/154** original source crop rectangles, staff IDs, staff-line coordinates, source pages and system identities exactly equal the previous complete musical-review exports. Every band is present once and in score order.
- **172/172** actual rendered fragments (154 original music crops +18 direction copies) match independently assembled original-source PDF references, including touched edge pixels: **22,560,544 compared pixels; zero different pixels at 144 dpi**. The music reference uses the previously frozen crop, not newly inferred text geometry. This verifies exported source ink, not just rectangles. `candidate-v3/actual-output-source-pixels.json` contains every fragment result.
- All18 source/copy pairs were visually inspected in `candidate-v3/review/directions-contact-1.png` through `-4.png`; all 19 output pages are also rendered there. No outside-page placement or inter-system overlap occurs. Page counts remain7+12; this is not a new comfortable-page-turn claim.
- **59** existing heading controls, **14** independent source-ink controls, and **14** new source-staff/recipient-position controls pass. These include faint gray254/alpha1 ink, actual Brahms cap-serif evidence, malformed/disjoint/legacy bounds, wrong x/system, below-target text, incomplete local glyphs and unchanged original crop geometry.

## Do not flatten the frozen-oracle result

The unmodified strict source-region metric is **14/15 tempo regions**, not 15/15. `opening-tempo-3` retains a 36-pixel failure. Source inspection in `mit-leidenschaft-bottom.png` shows that those pixels are the neighboring vocal **f** beneath “Mit Leidenschaft,” not missing tempo letters; all letters and punctuation of the tempo are visibly complete. That vocal dynamic remains complete in the unchanged original Voice crop. The original region, zero-tolerance rule, and numerical failure remain in `candidate-v3/evaluation.json`. This report separately states the musical 15/15 tempo-glyph observation; it does not move the oracle to produce a numerical pass.

**0/15 song-index obligations** are repaired. They remain frozen and reported rather than silently removed from the denominator.

## Holdouts and remaining defects

V3 and current production both ran fresh native recognition on **all 72 holdout pages**: Ave 4, Mozart KV498 29, Brahms 93521 39 (using the recorded corrected review source for Brahms). There are **zero OCR failures** and **zero differences in all 1,073 complete assignment/copy records**: Ave 64, KV498 405, Brahms 604. Ave's second Adagio remains recorded as a real source occurrence with an empty recipient list; it creates no new Soprano copy and does not replace the existing global source. KV498/Brahms heading metadata are unchanged. These are fresh inventory/plan comparisons, not a claim that all holdout PDFs were re-exported again. See `holdout-v3-*.json` and `summary.json`.

No recognized Schumann or holdout lyric/dynamic is newly classified as a tempo heading. However, **padded source copies still carry incidental neighboring notation**, which is a real output-quality limitation: `Lust!` over Langsamer, p dynamics below Etwas langsamer/Langsam, and rests beside the postlude Adagio are conspicuous examples. No clean isolation is claimed. Voice now repeats Lebhafter(p12s1), Adagio(p12s5), and Langsamer(p14s4), whose letters already appear below its staff in the original broad crops. These are disclosed rather than removed by uncertain cleanup. The complete-score review's page-turn and neighboring-staff concerns remain unresolved.

## Reproduction and provenance

Native Vision calls require ordinary macOS graphics access. Run the frozen binaries:

```
.build/schumann-directions/candidate-probe-v3 .build/schumann-directions/candidate-v3
.build/schumann-directions/holdout-probe-v3
.build/schumann-directions/export-score-plan-v3 --inventory .build/schumann-directions/candidate-v3/inventory.json --profile .build/schumann-directions/profile.json --title 'Schumann Directions Candidate' --out .build/schumann-directions/candidate-v3/parts
.build/extraction-venv/bin/python .build/schumann-directions/evaluate.py candidate-v3
.build/schumann-directions/verify-output .build/schumann-directions/candidate-v3
```

`provenance.json` hashes frozen inputs, source files, binaries, native OCR records, output PDFs, source-pixel comparisons and visual artifacts. `freeze-hashes.json` records the pre-experiment state; its original planner is preserved as `ScoreExtractionPlanner-baseline.swift`. Production, prior reviews and original PDFs were read-only throughout.

## Durable archive and fresh reproduction

This directory contains the exact final detector and planner candidates, their patches, all 30 frozen obligations, the original independent music manifest, the complete native OCR/plan and holdout comparison records, all 19 output-page images and 18 source/copy comparisons, runnable control/harness sources, and frozen exporter/current-production audit source snapshots. Rejected V1/V2 and profile-scoped experiments are clearly retained as history; `candidate-v3.swift` is the final candidate. The four `directions-contact-*.png` sheets show original-source crops alongside actual rendered copies, including the disclosed extra ink.

Large PDFs, 7.7 MB native inventories and native binaries remain under `.build/schumann-directions`; `external-artifacts.json` binds them by path/hash/size. `provenance.json` retains the original scratch record unchanged. `report-hashes.json` binds the current durable README and summary, including the follow-up initial-override audit; all nine historical candidate, frozen-assertion, provenance and evidence hashes remain unchanged. The original scratch report and its manifest remain in `.build/schumann-directions`. `archive-sha256.json` binds every durable file except itself. Current initial-override audit results are separate from the historical 59+14+14 passing controls. The negative audit intentionally exits 1: V3 has seven failed requirements and production has five; the explicit empty/nonempty marking controls pass in each.

From the repository root, use:

```
python3 Tests/quality_control/schumann-tempo-recipient-study/reproduce.py verify
python3 Tests/quality_control/schumann-tempo-recipient-study/reproduce.py controls
python3 Tests/quality_control/schumann-tempo-recipient-study/reproduce.py overrides
python3 Tests/quality_control/schumann-tempo-recipient-study/reproduce.py full
```

`verify` checks durable hashes without compiling. `controls` rebuilds/runs the 59 heading, 14 independent ink and 14 recipient tests plus the deliberately negative override audits; `overrides` runs only that separate audit. `full` also rebuilds both complete 16-page native recognizers, exports both parts, reruns the untouched 30-obligation region oracle and all 172 actual-output pixel comparisons, and runs fresh native baseline/candidate comparison on all 72 holdout pages. It writes a fresh directory (`.build/schumann-tempo-recipient-reproduction` by default), never overwrites the archived study, and verifies retained inputs against their recorded hashes. Native Vision requires normal macOS graphics access; full evaluation also requires the existing extraction Python environment or an explicit `--python` interpreter with PyMuPDF, NumPy and Pillow. Full reproduction remains dependent on the hash-bound retained input inventories and source PDFs. Rebuilt native OCR can vary by macOS; differences must be inspected, not silently accepted.
