# Accepted heading source-region review

All 63 accepted baseline heading regions from the 16-case, 449-page native run were visually reviewed against their original source contexts. This is a positive-region audit, **not a recall certificate for all directions on 449 pages**, and not a complete exported-part/layout audit.

All 63 accepted labels are genuine tempo or sectional headings at the indicated physical source system. No accepted label substitutes a lyric or staff-local technique. There are nevertheless pre-existing crop defects: one clearly clipped initial letter, one tiny serif fringe, and the two mutually truncated Schumann title/tempo fragments already addressed by the current grouping change. The final candidate does not introduce these defects.

## Source-first method and binding

`frozen-source-obligations.json` records the 63 manually read original word/symbol obligations, with clean context-image hashes. These were frozen before exact accepted-box images were generated. Contexts were selected from physical staff coordinates, independently of accepted heading bounds. Every source PDF, instrumentation profile and baseline inventory is hash-bound in `inputs.json`/`index.json`. Original-PDF pages were rendered with Poppler at 216 dpi; exact boxes are visualized with outward pixel rounding and enlarged for inspection. This is a visual review, not a claim of subpixel-exact PDF raster equality.

The corrected Brahms 93521 regions use `rectified-review-source.pdf`, never corrected coordinates on the raw PDF. Its SHA256 is `3662202ac3e464b3587bcb2e40f4ebce9d5c08858b3e9753c243963522c4052f`; all nine stored rectifications exactly equal the baseline inventory and verified delivery manifest. Media-box sizes also match the inventory on every reviewed page.

`visual-verdicts.json` contains a verdict for every one of the 63 regions. The clean source contexts and accepted crops are retained as individual PNGs and contact sheets. `render.py` reproduces them using the immutable source bindings and requires the source-obligation file before producing accepted crops.

## Confirmed defects and responsible stage

**Item 32: Brahms quartet 09200, physical page 14, Agitato.** The left portion of the initial A is visibly missing in the accepted crop. The Vision observation begins at normalized x=0.22083333813664002; fixed horizontal padding changes that to x=0.21949627644531708, or 129.7222993791824 points. The manually isolated original A has clearly dark source pixels beginning at x=380 on the 216-dpi raster, about 126.6667 points. The accepted left edge is x=389.166898 pixels. The frozen left-letter guard contains 57 pixels below gray level 128 outside that edge (51 even below 64). See `edge-review-32.png`, `initial-A-left-loss-32.png` and `frozen-initial-A-guards.json`.

This originates in the Vision envelope plus insufficient fixed left padding in `ScoreSharedHeadingDetector.select`. `measuredInkBounds` measures only **inside** the padded box; it does not search for missing ink outside it or shrink this copy. The planner then supplies that same exact rectangle to Violin II, Viola and Cello. `clipping-stage-trace.json` preserves the original Vision observations, accepted/ink bounds and recipient rectangles. Baseline and final-candidate bounds, ink bounds, text and anchors are identical. It is not a regression from coalescing or the override repair.

**Item 18: Brahms quartet 242312, physical page 14.** The corresponding A grazes the accepted left edge at a much smaller scale: one pixel below 128 lies outside the edge at 216 dpi, and three at 432 dpi. No pixel below 64 is lost in the 216-dpi guard. This is recorded as a tiny serif/antialias fringe risk, separately from the conspicuous 09200 failure. It is also unchanged in the final candidate. The complete primary phrase is readable, but strict all-source-ink preservation should not count this as a clean success.

**Items 3 and 4: Schumann quintet 06822, physical page 26.** SCHERZO and Molto vivace plus its dotted-note metronome equation form one printed block. Each baseline rectangle preserves its own primary text while cutting through its companion line. The baseline planner's horizontal-overlap rule then drops the tempo copy. The current candidate joins the original overlapping source boxes, retaining both lines. This is the sole physical page with a changed heading source block in the final 16-case inventories; the other 61 accepted regions have identical bounds, measured ink and text after ignoring new provenance fields. See the separate `heading-block-independent` and parent native-output studies for the complete candidate delivery proof.

## Collateral ink and unresolved directions

Neighboring slur, beam, clef, brace and note-stem fragments occur in many accepted boxes. These are listed individually, including faint source traces; they are not silently counted as clean crops. Item 43 (Mozart KV387 Trio) also includes bar number 94 and a complete local forte. The heading classification is correct, but the copied block carries that collateral local dynamic. The user's preservation-first policy permits neighboring ink; its appearance and possible ambiguity remain disclosed.

Source pixels correctly retain Schumann p39's metronome **126**, although its OCR label says 128. No text is re-engraved from that OCR label.

The source contexts also expose separate song indices 1/8, later a-tempo events, and movement numerals I/II. This accepted-region review does not certify their delivery. The unresolved German-tempo, song-index and separated-line issues in the earlier Schumann study remain unresolved; no V3 experiment was integrated by this audit.

## Next bounded improvement

Use the frozen original-A guards to test an outward source-ink continuation check around heading glyphs, rather than trusting Vision's word envelope or increasing every margin indiscriminately. Keep source staff/recipient identity and each heading's musical horizontal position fixed. Test the faint 242312 serif and the severe 09200 initial A alongside complete metronome symbols, punctuation and neighboring note stems. Do not trim local contamination until the complete intended source region is retained. No production fix or threshold change was made during this audit.
