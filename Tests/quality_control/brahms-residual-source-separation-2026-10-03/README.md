# Brahms 93521: seven remaining whole-neighbor rows

The current reviewed four-part delivery has **seven** full neighboring-staff inclusions, on pages **24, 28, 31 and 38**. There is no new crop candidate, detector run or production change in this study. All four original full-width systems and their current corrected counterparts, plus six original-source detail renders, were directly inspected. The seven target envelopes were frozen for future trials without shrinking earlier obligations.

| Current row | Current vertical crop, pt | Frozen target envelope, pt | Source cause |
|---|---:|---:|---|
| p24 s2 Viola | 241.138–311.753 | 243–281.5 | Right boundary joins local branches of Viola and Cello |
| p24 s2 Cello | 241.138–316.497 | 272.5–315.5 | Same ordinary shared component |
| p28 s1 Violin I | 17.592–93.570 | 24–64 | Internal measureline and staff-line residue join violin phrases |
| p28 s1 Violin II | 21.591–107.566 | 66–98.5 | Same ordinary shared component |
| p31 s1 Violin II | 41.435–110.864 | 69–105.5 | Leaning right boundary with damaged line junctions |
| p38 s1 Viola | 87.969–159.549 | 90–133 | False musical-preservation alternative at a Cello tie/barline |
| p38 s1 Cello | 91.568–165.147 | 132.5–163 | Same outward alternative |

Coordinates are current saved-corrected top-down PDF points. The p31 target guard's horizontal interval is 35–394 pt; the other full envelopes span 0–427 pt. These are conservative source regions, not per-pixel musical ownership masks. Whole-staff containment identifies the review queue only; it is not proof of correct ownership.

## Source and causal distinctions

The original PDF SHA is `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`. The current corrected PDF SHA is `be1074d1436da4737bab07e360d1f6b4fda8b011db7b3a598e60cd62891cf8b4`. Although this differs from the historical manual benchmark's PDF container hash, all four relevant pages rasterize **byte-identically at 4 px/pt**. Pages 24/31 are unrectified originals; pages 28/38 use saved corrections. The nine correction records are bound independently. Earlier ten full guards and thirteen local obligations are copied byte-for-byte; the historical p35 strict-guard failure is not reclassified or waived.

The exact current inventory has one shared component for each pair. Pages 24/28/31 are ordinary components; page 38 is explicitly `isOwnershipAlternative=true`. Their native rectangles are respectively `[285,1042,1643,1306]`, `[132,69,969,229]`, `[1641,200,1651,350]`, and `[135,244,971,394]`. Pages 24/31 use 1800×2593 analysis pixels, while corrected pages 28/38 use 1068×1538. These coordinate spaces must not be mixed.

The prior source-bound logging study, using the unchanged Native analyzer hash `9f8d7ef8…`, explains the ordinary cases: p24 lower core supports 49/57 rows and p28 upper core 29/34, both failing the existing 88% proof; p31 fails the final ordered-line tracking window before connector proof. Current source inspection agrees with damaged/curved print. This study reuses those logged causes and independently checks current component identity; it does not pretend to have rerun instrumentation.

On p31 the 448-pixel shared component is only the right boundary and short staff-line stubs. The final Violin I beam and Violin II flagged notes, lower slur and crescendo lie separately to its left. This is the clearest structural-separation target. Its thinness alone is insufficient: previous steep musical curves defeated that shortcut.

On p38 the accepted compact patch `[411,374,414,376]` is on a Cello tie where it meets the continuing measureline `[409,411)`, not a separate head. The current native code retains the musical interpretation as an outward alternative; the planner expands both contacted owners to its entire bounds. A structural classification fix for pages 24/28 would not itself remove this false alternative.

## Conservative reusable rules to test

These are evidence requirements for a future candidate, not a claimed working classifier.

1. **Bind roles to source intervals.** Preserve original pixel runs, ordered staff-line identities, actual line thickness/curvature, missing segments and every branch contact. A barline's role may change along its length. A whole connected component or vertical shaft must not receive one blanket structural or musical label.
2. **Separate structural transport from note attachment.** A common system edge or repeated aligned measure boundary can establish a structural hypothesis. It does not establish exclusive ownership. Numbered staff-line channels may explain long horizontal residue only where actual source fragments support that identity; a gap must remain uncertain. Preserve crossings, note bodies, stem continuations, ledger lines and ties as separate payloads.
3. **Require a complete branch account before a cut.** An analysis-only cut through a source-isolated structural gap is eligible only when its two sides are explained by the same boundary and every non-staff-line branch retains its original payload and evidenced owner. For p31, test this certificate on the isolated right-boundary interval first. Do not require fabricated intact staff lines, and do not accept a width/edge-location or three-other-staves shortcut. Those shortcuts already have musical counterexamples.
4. **Do not propagate ownership along structural coincidence.** A head or tie touching a barline does not give it every staff crossed by that barline. For p38, classify the complete original curve and both its note endpoints, including continuation beyond the small accepted patch. Preserve the complete Cello tie locally. If a genuine cross-staff shaft, shared beam or unresolved attached musical branch remains, keep its shared interval. Neither a blanket branch veto nor a compact/filled-body score proves exclusive ownership; tied heads, glyphs and heads at barline junctions are known counterexamples.
5. **Keep detached source envelopes independently.** Detached dynamics, articulations, slur crowns and text cannot be reconstructed from surviving staff cores alone. Preserve existing source-owned evidence while replacing only a certified structural attribution edge. Do not union entire old band rectangles, and do not discard old single-owner evidence merely because component splitting changes its box.
6. **Validate ownership and preservation separately.** Future trials must retain unchanged source-owned pixel masks/envelopes and also reject new foreign-staff ownership. Exact source binding and deterministic branch partition are prerequisites. Any unaccounted branch, missing geometry or ambiguous mixed musical/structural corridor must abstain. The original four-core shared-chord, real tied/hollow heads, nearby-but-unattached heads, line-break/ledger aliases, and `headAtJunction` controls remain unchanged gates.

The narrow next experiment should emit a **separation certificate for p31**, retaining all original source pixels and branch roles, before allowing the planner to tighten its envelope. In parallel, p38 needs evidence-specific suppression of a false shared alternative rather than stronger connector erasure. Pages 24/28 require the harder per-line residue and branch assignment; a relaxed core threshold cannot substitute for that work. I found no safe drop-in bounding-box rule that solves all seven.

## What rectangles can and cannot achieve

Every current relation admits a source-faithful rectangle that excludes the complete foreign staff core, as the separately reviewed manual benchmark demonstrates on pixel-equivalent sources. This does not require perfect separation of all foreign marks.

On p24, Viola's low dynamics/hairpins and Cello's high closing notes/slurs occupy overlapping y ranges. On p38, Viola's high final arcs share y ranges with Violin II's lower markings; some Cello beam tips may remain under conservative lower clearance. Removing all these fragments with full-width horizontal edges would remove target ink. Page 28 Violin II also needs its low flagged note, slur, hairpin and forte even where nearby Viola high-note/slur fragments remain. A reusable rule should remove unrelated complete cores while preserving these overlaps, not enforce one non-overlapping band per staff.

`source-obligations-before-future-trials.json` binds the preserved envelopes and fresh visual judgments. `current-whole-neighbor-relations.json` and `shared-components.json` identify the authoritative current rows. `causal-findings.json` separates current inspection from historical instrumentation. No new proposed crop was rendered or tested, no source pixels were edited, and the current published draft remains unchanged.
