# Independent review of seven manual Brahms93521 trims

All seven new crop edges preserve the intended notation in direct original-source, corrected-source and final-native-output comparisons. No crop correction is required for these seven edits. All 35 changed output-page layouts were also viewed; no new composed-strip collision, split system or footer/title boundary loss was found.

This is explicit manual assistance. It does not establish a new automatic crop result, clean engraving, performance-ready page turns or a fresh all-604-band source review.

## Source and final binding

Original source SHA256: `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`.

Saved corrected review source SHA256: `be1074d1436da4737bab07e360d1f6b4fda8b011db7b3a598e60cd62891cf8b4`. Pages 28/38 use this corrected coordinate space; pages 24/31 are unrectified and independently rendered identical in both sources. I also viewed all four uncorrected source contexts directly.

Final manifest SHA256: `18c4fdcc0db49db1350af235c184668dbb4392fafa0e676d53f558f6af499282`. PDF hashes, final placement rectangles, output detail PNG hashes and source page evidence are bound in `seven-row-receipt.json`. Every changed page is bound in `changed-page-receipt.json`.

## Seven source comparisons

| Source band | New edge, corrected top-down points | Independent preservation result |
|---|---:|---|
| p28s1 Violin I | bottom 65.5 | High ledger notes/phrase arcs, lower clef dot, crescendo and complete forte retained. |
| p28s1 Violin II | top 64.5 | Clef crown, upper staccato dots, lower flagged note, slurs, hairpin and forte retained. |
| p31s1 Violin II | top 67.5 | Rest, sharp accidentals, all flags/dots, p, low slurs and closing crescendo retained; damaged source staff segments are unchanged. |
| p24s2 Viola | bottom 283 | All articulation dots, slurs, lower cresc., f, closing half notes and hairpins retained. |
| p38s1 Viola | bottom 134.5 | Both voices/chords, triplet, upper/lower ties, lower tenutos, final high note/double arc and f retained. |
| p24s2 Cello | top 271 | Initial low ledger note/slur, all notes/accidentals, upper closing slur, lower cresc./f and hairpins retained. |
| p38s1 Cello | top 131 | Initial low accidental/ledger note, nested and long lower slurs, all tenutos, closing half note and f retained. |

Each shortened edge retains the frozen target envelope plus 1.5 source points. The opposite edge is unchanged. Visual review went beyond envelope containment: every named vulnerable mark was compared with source context and the actual final PDF detail. All seven edits remove the neighboring whole staff body in question. Partial neighboring ink still occupies the same vertical range as intended notation and remains.

## Independent saved-project audit

The separate `seven_trim_contract` reviewer found only the seven declared crop-edge fields plus `modifiedAt` changed. All 604 band identities and their order remain, 151 per instrument. Nine rectifications, the original source, corrected source, detection plan and source guard remain identical to the parent. All 42 copied markings retain their source rectangles; 25 destination rectangles move with layout. The previously reviewed Viola p8s2 in-tempo repair remains [0, 227.6901081916538, 427, 284]. See `native-contract-independent.json` for the exact check record.

Final page counts remain Violin I 17, Violin II 16, Viola 16, Cello 15 (64 total). Four Violin II bands and 20 Viola bands move between pages through reflow. All 35 changed pages were directly viewed: app_audit reviewed Violin I page 12 and all 16 Violin II pages; changed_page_layouts independently reviewed all 16 Viola pages and Cello pages 9/15. The parent comparison records the other 29 pages as pixel-identical; these were not re-reviewed as changed pages.

## Remaining presentation limits

Neighboring notes, dynamics, slurs, text and staff fragments remain conspicuous across many unchanged crop rows. The seven edits improve their local passages without cleaning the rest of the quartet. Specific residuals include preceding dolce text on p31s1 Violin II, following Viola high-note fragments under p28s1 Violin II, and overlapping Viola/Cello dynamic and note fragments at p24s2. Source publisher/page numbers remain in places.

Page turns are not optimized for performance. Violin II starts Andante near the bottom of page 6, and other movements/sections begin midpage. Viola first/second endings span pages 2–3. Continuous phrases often cross turns. Headings, ending brackets and intended last rows remain visibly inside the pages, but this should not be described as a performance-ready pagination pass.

The compact evidence archive contains source-context clips, seven final crop details, 35 changed-page PNGs and the review scripts. It does not duplicate the full original/corrected source PDFs or the four large part PDFs. No production code or delivered PDF was modified by this review.
