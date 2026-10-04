# Monotone crop source-review coverage

**398 of 1,282 changed crops are covered by a source-review receipt; 884 remain pending.** This is coverage accounting, not a pass. The tested cleanup candidate remains ineligible for production promotion.

The immutable original queue had 1,125 pending rows and 157 previously reviewed rows. Exact score-plus-band membership adds 241 distinct rows:

| Review receipt | Added rows |
| --- | ---: |
| Brahms 242312, audit review | 4 |
| Brahms 09200, root review | 12 |
| Schumann 06822, source review version 2 | 32 |
| Brahms 93521, exact reuse of corrected-source review | 193 |
| Total added | 241 |

Every new ID belongs to the original queue. None overlaps another added group or the prior 157. The original queue was read from the hash-verified frozen comparison archive; source bytes, inventory hashes and complete available source-review input records were checked against that queue. The 193 reused rows retain the previous decoded-pixel, staff-assignment and exact old/new rectangle proof. No images were rendered and no native analysis or musical review was rerun here. The Schumann receipt records all 32 context views; its individual `fullSourceViewed` flags are preserved without upgrading context-only observations into whole-page review.

Three reviewed raw-plan rows report lost shared instructions: Coda in Brahms 242312 `p18-s4-violin2`, Andante in Brahms 09200 `p10-s1-violin2`, and the numbered tempo instruction in Brahms 09200 `p22-s1-violin2`. Covered rows include these failures. Crop-only plans, and the path with optional shared-direction recognition off by default, still block cleanup promotion; a separate opt-in recognition fix does not establish safe source preservation for that path.

The broader extraction goal remains open. Nineteen initialized profiles yield no planned bands and need system assignment; 15,712 detected staves remain unassigned across the corpus. Existing neighboring fragments, source omissions and unresolved pages remain. Complete final parts and page turns are not certified by this bookkeeping.

`remaining-ids-by-score.json` is the exact 884-row remaining queue grouped by score. `newly-covered-ids.json` names all 241 added rows with their receipt hashes and recorded verdicts. `previously-covered-ids.json` preserves the 157-row starting partition. `input-bindings.json` and `validation.json` record the source and membership checks; original reports remain unchanged. `aggregate.py` reproduces the accounting from those existing inputs.
