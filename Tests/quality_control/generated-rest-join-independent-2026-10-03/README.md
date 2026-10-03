# Independent generated-rest joining and Erlkönig export review

The opt-in joining change passes **33 independent checks**, including the existing complete Erlkönig project, direction/page-break boundaries, mixed rest types, legacy documents and extreme measure numbers. The resulting Voice introduction is one **12-bar rest covering bars 1–12**, with the original *Schnell* / quarter-note = 152 source copy and a clearly editorial `[4/4]` label. The printed Voice system starting at bar 13 remains intact. All eight Piano pages are independently verified pixel-identical to the previous complete output.

This review changes no production file or output. The original seven-Brahms-case source report remains untouched.

## Source truth frozen before the candidate export

The original embedded PDF is byte-identical to the reviewed Schubert source, SHA256 `dfd76c0ddb804d0587048c61e4edec8dcd7a75b6e39e27420087ed510d89046b`. Its first page prints a plain common-time C on both Piano staves; there is no cut-time stroke. `[4/4]` accurately explains this meter as editorial text, not a claim of copied source notation. The source page and exact glyph/tempo detail are retained in this report.

The first four Piano-only systems begin at bars 1, 4, 7 and 10 and each contain three measures. The absent Voice therefore has twelve bars of confirmed silence. Voice's printed staff returns at bar 13, retaining written rests before the first sung pickup within bar 15. Joining must stop at 12, not swallow the printed 13–15 system merely because its opening contains rests. This was recorded in `protocol.json` before candidate-output comparison.

## Independent behavior checks

The frozen-Core harness checks real project reopening, original rest records, source-band order, tempo-copy coordinates and every retained Voice source rectangle using the actual source PDF page bounds. Four stored rest records remain four records, each with its original count, starting number and system identity; only the render placement combines them. Reversing the stored array does not change physical source order. The complete project is unchanged by layout.

Additional boundary cases exercise two separated six-bar groups with different directions on different source pages; a below-rest direction that must remain after bars 7–9; a page break producing two distinct six-bar pages; an excluded intervening printed cue that cannot be bridged even when supplied numbers appear consecutive; and both orderings of generated rests next to printed-rest replacements. Source references and direction positions remain attached to their own intervals.

Three single-bar omissions combine to three. A 998+1+1 chain splits at 999+1 without dropping the final bar. Valid one-, two- and 999-bar intervals ending exactly at `Int.max`, and a valid 998+1 join ending there, pass without overflow. Invalid counts and unknown-band edits leave the document unchanged. Explicit false preferences and legacy missing preferences remain unjoined after full-project decoding.

The parent reported that an initial sandbox/environment suspicion was incorrect; the actual failure was arithmetic. The parent had already fixed this pre-existing integer overflow before our source snapshot: `startBarNumber + barCount - 1` could overflow transiently for a valid interval ending at `Int.max`; the tested expression is `startBarNumber + (barCount - 1)`. We independently validate the repaired boundary cases, but do not claim to have rerun the earlier crash. The frozen snapshot and four current modified production files match exactly in `final-bindings.json`.

`GeneratedRestEditor` was inspected for count validation, saving both count and join preference, and reloading on selection/rest changes. This is code review, not automated Inspector interaction. The parent's separate generated-rest join suite and Undo tests are additional evidence, not included in our count of 33.

## Complete export comparison

The reviewed candidate is `.build/erlkonig-rest-finish-2026-10-03/parts`. Exact project comparison finds only these requested changes: `joinWithPrevious = true` on the rests beginning at bars 4, 7 and 10; `[4/4]` on the first rest; and the project modification date. All source crops, original durations, direction records, source-system identities, exclusions, explicit breaks, part settings and other fields remain exact.

| Part | Stored original bands | Output rows | Pages | Independent result |
|---|---:|---:|---:|---|
| Voice | 48 | 45 | 4 | Four opening rests combine into one; all 44 printed source rows remain |
| Piano | 48 | 48 | 8 | Every page pixel-identical to the original output |

Every one of the 96 original band references appears exactly once across the output placements. The joined rest lists its four source IDs in score order. Its tempo copy still uses the exact original rectangle `[121.6,136.5,220.1,155.5]` in the original first-page source frame. No cue, marking or new count is inferred from matching notation.

Both complete PDF sets were independently rendered with PDFKit at 144 dpi using the retained renderer. All eight Piano pages match pixel-for-pixel. All four changed Voice pages were visually inspected: the twelve-bar count, editorial meter, tempo/metronome copy, transition to the original bar-13 strip, final recitative/Andante, and retained lyrics are visible without a new row overlap or page-edge clipping. No source music was erased or re-engraved.

The Voice page turns now fall at 39→40, 75→76 and 112→113. The first splits “Ge-/sicht”; the second splits “du / nicht” within a phrase. The last leads into rests. These are not certified performance turns. Existing neighboring fragments, duplicated source/manual bar numbers and previously documented crop limitations remain. The new rest layout improves the introduction, not every aspect of the complete part.

## Reproduction and evidence

`independent-results.json` records all 33 checks. `export-metadata-comparison.json` binds the baseline and candidate projects/PDFs and exact permitted edits. `independent-page-pixel-comparison.json` records all twelve page comparisons. The four newly rendered Voice pages are directly available here; `independent-renders.zip` preserves all 24 baseline/candidate page renders and extracted text. `archive-members.json` binds every archive member.

`frozen-core-and-ui.zip` retains the exact 26 source files used or inspected. Native executables and the source PDF remain in scratch/repository with recorded hashes. For replay, restore `Core/`, `InspectorView.swift`, the source PDF, baseline project, harness and scripts under `.build/generated-rest-join-independent-2026-10-03`, then run `build.sh`. The exported-project/PDF comparison script reads the recorded original/candidate paths and does not mutate them.

The first independent harness compile failed because its fixture constructor exceeded Swift's type-checking limits and two throwing expressions needed intermediate values; that diagnostic is preserved. A first successful 33-check run used generic page dimensions. The final recorded run repeats those checks with actual source-PDF bounds for the real project. Both earlier records are retained and are not presented as production failures or as the final geometry result. No assertions or source expectations were weakened.
