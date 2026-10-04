# Completed outputs behind unresolved raw profiles

All three examined scores have complete, source-hash-bound **assisted** project/PDF sets. Their raw Auto profiles still stop at changing instrument layouts. This distinction accounts for four of the 19 zero-band raw profiles: full Mozart K488 and its one-page excerpt are two profiles of the same score. The remaining 15 profiles were not audited for later outputs here.

| Provided score | Source scope | Complete delivered set | Initialization and remaining limits |
| --- | --- | --- | --- |
| Notte e giorno | 4 pages, 20 systems, bars 1–73 | 2 parts, 40 rows, 7 PDF pages | Reviewed instrument setup. The Voice's nine introductory bars use two explicitly labeled Piano cues, not synthesized rests. Neighboring fragments and duplicated text remain; practical page turns are unverified. |
| Erlkönig | 11 pages, 48 systems, bars 1–148 | 2 parts, 96 original band references, 12 PDF pages | Reviewed identities/counts, five crop corrections and four source directions. Latest Voice output joins its four introductory records into a 12-bar rest with editorial [4/4]. Two phrase-splitting Voice turns and continuous-playing Piano turns remain. |
| Mozart K488, first movement | 36 pages, 78 systems, bars 1–314 | 9 printed parts, 702 items, 57 PDF pages | Reviewed identities/counts, 603 source crops, 99 generated rest passages and 180 initialized direction copies. Full independent edge/copy review, practical turns and internal cue placement within some generated rests remain unfinished. |

Authoritative delivery directories:

- `output/pdf/full-score-sets/notte/`
- `output/pdf/auto-qc-2026-10-03/erlkonig-joined-rest-draft/`
- `output/pdf/auto-qc-2026-10-03/mozart-k488-variable-layout-draft/`

`coverage-ledger.json` binds original and embedded PDFs, editable project JSON, source maps, manifests and every part PDF. All 22 Erlkönig delivery-hash entries and all 18 K488 entries match. Notte's original source, manifest and both PDFs match its existing review record. Source page counts and per-part band counts were checked directly. Erlkönig's 96 original references each occur exactly once in the joined output. K488's 702 plan rows agree with the reviewed source map's staff identities, starts and durations; both complete measure timelines are contiguous. These checks validate the recorded assignments and timing, not automatic music recognition.

`raw-profile-binding.json` independently confirms zero raw bands in the current-planner replan of production inventories for all four focus profiles. The K488 excerpt's original page is pixel-identical at 144 dpi to physical page 17 of the full source. It must not count as a second completed score.

## New independent Notte review

All four original source pages and all seven delivered output pages were freshly rendered from the hash-bound PDFs at 144 dpi and visually examined. All 40 rows were followed in source order: 18 vocal music rows, two labeled Piano introduction cues in the Voice part, and 20 complete Piano grandstaff rows. No intended target notation omission was observed. Both printed lyric languages, stage directions, fermatas, instrumental cue text, dynamics, ledger notes, slurs and final source material remain visible. All 40 previously frozen source envelopes remain contained; none was changed.

This is a preservation review, not a clean-part approval. The opening rows duplicate source cue text and pieces of adjoining systems. Several Voice rows retain partial Piano staffs; Piano rows retain chopped vocal lyrics or staff fragments. The opening Piano footer includes part of the Mutopia imprint. These are plainly visible on the current PDFs and recorded separately from target preservation. Page turns occur at system boundaries but were not certified as practical; no print or performance trial was made. “Complete” refers to all four supplied source pages, not an entire opera.

`notte-per-band-review.json` contains the individual source interpretations for all 40 rows. All 11 inspected page renders and their input/output hashes are retained. Existing historical visual reports were consulted for context; the new inspection did not substitute their pass flags for viewing these pages.

## Current app compatibility

The old Notte project also passed the current model codec, `PartsmithDocument` initialization, layout engine and PDF exporter, using all 25 Core files from the independently audited numbered-volta snapshot. Every Core file still matched the current project at this check. No staff analysis, identity reassignment, crop edit or source rewrite was performed. Both complete parts re-exported successfully; all 40 destination rectangles are exact, and all seven whole-page renders are **pixel-identical at 144 dpi** to the delivered set. The project model remained unchanged. This is a native compatibility test, not an app-window click test or unattended Auto result.

A comparison-harness coordinate issue is retained in `coordinate-convention-diagnostic.json`: PyMuPDF's floating-point page rectangle reports height 841.8900146484375, while the PDF's literal MediaBox and native code use 841.89. Using the actual MediaBox removes the artificial 0.00001465-point top-down conversion offset. The seven-page pixel comparison was exact before and after that correction. No crop or tolerance was changed to resolve it.

The reviewed-template feature is separate. Its current frozen matcher covers all 48 Erlkönig systems from two reviewed examples, with silent durations supplied independently; its test export intentionally lacks later crop/direction corrections. Notte's two examples plus eight suggestions cover only 10 of 20 systems, with conservative abstention on the others. Notte's complete older project already includes explicit reviewed assignment work. K488's complete map is manually initialized and has no demonstrated complete template-matching run. These outputs therefore resolve complete-scope **assisted extraction**, while fully automatic identity and universal crop quality remain open.

Evidence sources: [K488 complete workflow](../k488-complete-workflow-2026-10-03/README.md), [independent template study](../system-template-independent-2026-10-03/README.md), [complete template workflow](../system-template-workflow-2026-10-03/README.md), and the latest Erlkönig joined-rest delivery review. The archive excludes binaries and duplicate source PDFs. No delivered file or user app was modified.
