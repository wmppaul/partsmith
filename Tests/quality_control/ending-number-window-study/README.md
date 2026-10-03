# Ending number window study — not promoted

The native ending reader uses a number window ending 3.3 staff spaces after the left bracket hook. Source review found that this window cuts off the printed second-ending numeral in several scanned passages. A wider window recovers six of seven previously recorded misses, but **the candidate is rejected for promotion**: independent native controls find newly accepted off-bracket numbers and clipped punctuation. Source-window provenance, numeral containment and duplicate-proposal evidence need a different repair.

The seven cases were frozen by the earlier corpus review: Brahms editions IMSLP242312 and IMSLP09200 on physical pages 21, 23 and 24, and Schumann IMSLP06822 on page 29. The initial unconditional 4.8-space window experiment recovers six pairs. The subsequent candidate retries only geometry with no existing numeric role, uses accurate OCR, and accepts only a literal 1 or 2. Existing recognized candidates retain their exact evidence and source-copy rectangles. Brahms242312 page 21 remains missed.

Fresh native recognition over all **14 fixed-layout scores / 381 pages** finishes with zero recognition errors. All **65 original numeral candidates and six original pairs are exactly preserved**. Eight numeral candidates are added; six produce the same six recovered pairs from the frozen missed-case list. Independent source review identifies the other two as notation fragments: a preceding Piano bass chord/slur in Brahms Trio114012 p16/system4 and a Violin I beam/stem in Brahms09200 p17/system3. Both remain unpaired. These are bounded corpus results, not a whole-score recall claim.

The 69 existing ending checks pass, including fresh native image controls. Independent testing adds a 70-image native grid: accepted pairs increase from one to eleven, including eight newly accepted partly off-bracket numerals that the baseline rejects. Three cases clip printed punctuation. There are no OCR execution errors. A controlled-evidence replay of the unchanged grouping block also demonstrates loss of a later wide success and loss of a conflicting numeral; that is separate from naturally observed corpus evidence. The prior Brahms93521/K.498 68-page detector holdout was not freshly rerun for this candidate; the existing test replays frozen evidence for those positives. Complete part PDFs with the six added pairs have not been exported in this study.

## Open issues

- Duplicate-proposal grouping appends the original narrow evidence, so a later member's successful wide reading may be lost.
- OCR observation rectangles refer to differently sized reading images. Each wide observation needs its own source-window coordinates before those rectangles can be used for geometric validation.
- The wider window can extend beyond a short bracket. Acceptance needs evidence that the numeral belongs inside the proposed bracket, rather than to neighboring notation.
- The final missed page remains unresolved. Increasing another fixed width without source constraints is not a validated repair.

The independent source and adversarial review is recorded in `../ending-number-window-independent`. All twelve marks in the six real recovered pairs contain its independently measured source-ink guards. Those positives do not override the new adversarial failures. Production detection and the packaged app are unchanged by this experiment.

## Evidence

`candidate.patch` contains the exact delta from committed baseline3e203c2. It also includes diagnostic printing for page index20, which does not change recognition. `seven-*.json` freezes the targeted experiment. `results.json` records every broader page; `broad-comparison.json` compares complete source candidates and pair evidence without tolerance. Unknown and blank-page pairing barriers come from the original native review of the same immutable sources and staff inventory; no-staff recognition is not treated as proof of a blank page.

The narrow/wide example images illustrate the truncated numeral; their small reading boxes are reconstructed from source geometry and are not independent copy-completeness guards. Source PDF/profile/inventory hashes are in `broad-inputs.json`. `provenance.json` binds the complete compiled Core and four scratch binaries. `main.swift` and `compare.swift` reproduce recognition and the comparison using the frozen scratch roster. Larger runtime logs remain under `.build/ending-number-window-2026-10-03`.
