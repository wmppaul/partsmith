# Independent source review: numbered lines V2 + source spans V4

The combined candidate preserves all 57 frozen rectangle-check outcomes: **54 pass, three unchanged failures, zero new failures**. I independently inspected all **125 changed crops on physical pages 1–19**, including all 102 with a contracted edge, against the full-width original source. I found **no newly omitted intended music or source heading** in those contexts. Root separately reviews pages 20–39.

This is diagnostic evidence, not a claim that the combination is robust or ready for production. The separate synthetic review found 27 `headAtJunction` cases gaining false shared ownership and 84 foreign cores. The author's 297-fixture preservation recovery and the real score's 7→5 whole-neighbor count are preservation/cleanliness observations with different meanings. The user explicitly values keeping target music above eliminating neighboring ink; those results must remain separate and none of the prior test gates has been silently changed.

## Frozen source obligations

`requirements-before-results.json` was frozen before inspecting the candidate. It retains all 56 prior envelopes/landmarks unchanged and adds the actual printed **Vivace** ink envelope measured from the published saved-correction source. Some obligations overlap; these are 57 checks, not 57 distinct notes.

The three unchanged failures are:

- p35 system 1 Violin I: old broad guard ends at 68pt, current and candidate crop at 66.382421pt.
- p22 system 3 Cello: lower envelope ends at 448pt, both crops at 447.655611pt.
- The nested p22 rightmost lower-beam/hairpin landmark also ends at 448pt.

These failures are not waived or relabeled as passes. Their source envelopes remain frozen.

The complete Vivace envelope `[137.25,131.25,173.166667,140.416667]` is inside the **unchanged** p2 system 1 Violin I crop `[0,125.2,427,176.8]`. Its upper serifs and final period are visible in `vivace-source-only.png`. This combination does not include the separate high-resolution experiment that cut those serifs.

## Visual findings

Every reviewed band and context hash is recorded in `review.json`. The review covered notes/heads, stems and beams, ledger lines, accidentals, articulation dots and accents, slurs/ties, dynamics and hairpins, local text and visible source headings. This is direct visual review, not a complete pixel oracle or a new export/pagination test.

Notable source checks include:

- p8 system 2 Violin I: the 19.69pt top contraction retains rehearsal F, *in tempo*, high ledger notes and their slurs.
- p6 system 4 Violin I: second-ending bracket/2., *sotto voce*, lower p/hairpins and upper slur are retained.
- p7 system 4 Violin II: low slurs and both hairpins stay inside the 7.2pt bottom contraction.
- p10 system 1: each lower part's own fermata and *dim. e rit. poco a poco* remain complete.
- p17 system 3 Violin I: rehearsal B and the high notes/slurs remain inside an 8.8pt top contraction.
- p19 system 3 Violin I: *rit. un poco*, rehearsal D, *in tempo* and *dol. e grazioso* remain complete.

The p4 system 1 Violin I top edge now bisects the original printed page number **4**. It is source pagination, not a measure number or target music. Many partial adjacent staves and notation fragments remain, including next-system cues; this review does not claim clean extraction.

## Provenance and coordinates

`source-bindings.json` binds the candidate, baseline, replay protocol and every frozen input. All **41 input-manifest entries match**, including all **39 source rasters**. The replay uses the original saved nine corrections at their original 2.5-scale raster resolution; it excludes the rejected larger-resolution experiment. The full candidate has 604 bands with identical IDs, staff records and assignment identities, every observed staff assigned once, and no new unresolved page.

Candidate JSON intentionally has only `pages` and `plan`. The comparison therefore leaves source-hash/corrections equality fields null instead of inventing metadata. Source provenance is established by the frozen replay/input-manifest hashes, not these absent fields.

All rectangles use top-down PDF points and each page's actual physical width/height. In particular, no constant 615pt page height was substituted. `rightFraction` is treated as the right inset. Original source context paths and hashes are retained in the per-band record for reproducibility.

Root archives all 252 original-source contexts with the complete replay; this report deliberately omits a duplicate image archive. `review-sheet-manifest.json` records how the 125 contexts were grouped for the independent visual inspection.
