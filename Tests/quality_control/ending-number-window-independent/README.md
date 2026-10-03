# Independent review of wider ending-number OCR

**Do not promote this exact candidate yet.** Six real ending pairs are recovered with complete source-mark copies, but native adversarial controls expose new acceptance of partly off-bracket numerals and clipped printed punctuation. A separate controlled merge test also confirms loss of later fallback evidence. No production or export input was edited by this reviewer.

The frozen candidate is SHA256 `71ef4695ed6f63230afdb33fe3560a6bab84a94c3d689bcd211a11eae35a26bc`, in `frozen-candidate-detector.swift`. It adds an accurate-only OCR retry from the left number cell to 4.8 staff spaces. The parent ran this exact detector over 381 pages of 14 scores; its retained comparison reports 65→73 candidates, 6→12 pairs, no missing original candidate/pair, and no OCR errors. Six additions pair; **the other two new candidates are false positives**, although neither produces an accepted pair. These counts are a corpus result, not a recall or general safety certificate.

## Source-first review

Original PDFs were rendered independently at 216 dpi. All seven full-width staff contexts and all twelve new paired-mark copy previews were inspected. Mark guards were constructed from manually selected original-source bracket, hook, numeral, and punctuation components, with 0.1-point allowance. Source pixels, not proposed copy rectangles, determine these guards. The source SHA256 and selected components are frozen in `frozen-source-guards.json`. This was not a fully blinded study: detector metadata had been visible earlier; final guards were frozen before the automated copy-containment comparison.

Initial source-only ROIs touching ink were enlarged before freezing. On the two p23 sources, dots directly below the bare 1 and 2 belong to staccato notes, not ending punctuation, as the wider source context shows. All adjacent printed punctuation in the other endings is included. The Schumann numeral 2 touches its bracket and is included with that connected component. Initial and final component tables are retained for audit.

| Source | Physical page / system | Source finding | Complete first + second guards |
|---|---|---|---|
| Brahms Quartet 242312 | 23 / 4 | Genuine 1 and 2, two closed brackets | Both pass |
| Brahms Quartet 242312 | 24 / 2 | Genuine 1. and 2., two closed brackets | Both pass |
| Schumann Quintet 06822 | 29 / 3 | Genuine 1. closed bracket and 2. open bracket | Both pass |
| Brahms Quartet 09200 | 21 / 3 | Genuine 1. and 2., two closed brackets | Both pass |
| Brahms Quartet 09200 | 23 / 4 | Genuine 1 and 2, two closed brackets | Both pass |
| Brahms Quartet 09200 | 24 / 2 | Genuine 1. and 2., two closed brackets | Both pass |

`source-copy-checks.json` contains all 12 exact comparisons and margins. The previews `copied-*-{first,second}.png` are cut from the independent original-source render at the returned copy bounds, not from the detector's number cell. They show complete numerals, hooks, and lines. Some returned rectangles also contain note-flag, slur, or adjacent-hook fragments; retaining those does not establish clean engraving. This task did not export or review final wider-window part pagination, recipient duplication, or every score note.

The missed light Brahms242312 p21s3 is genuine. Its second bracket starts at x482.333pt. The numeral's original dark ink spans x492.667…498.667pt and y338.667…345.667pt; its dot spans x499…500.667pt. With the measured staff space ≈3.14185pt, the numeral starts about 3.29 spaces from the bracket edge, ends at 5.20 spaces, and its dot ends at 5.83 spaces. A fixed 4.8-space reading window cuts the numeral. This is recorded from source components 2,4,5 of case0, not inferred from detector bounds. The existing first-ending copy passes its separate source guard; there is no newly accepted second copy to validate here.

## Two new false candidates

- **Brahms Clarinet Trio114012 p16s4:** the proposed "2" is a bass note/flat and slur at the bottom of the preceding Piano staff, around x545,y600. The number is not printed there. `negative-114012-context.png` and `negative-114012-detail.png` show the original source.
- **Brahms Quartet09200 p17s3:** the proposed "1" is part of a rising beam/stem above Violin I near x105,y333. There is no ending bracket or numeral. See `negative-09200-context.png` and detail.

The detector's source-system ownership gate and unique pairing checks leave both unpaired. Retain these source cases as negatives; do not describe the broad run as producing zero false candidates.

## Native short-bracket controls

`adversarial/run.swift` calls the public analyzer and pair selector with verified one-staff ownership, native Vision OCR, and explicit source images. The first bracket is a genuine closed 1. bracket. The second is a short blank bracket ending at x248 inclusive (right edge249), with a separately positioned numeral. Fixture glyph masks are independent of candidate bounds. All normal native runs reported no OCR errors.

The first 28 Times controls produced no recognized inside-bracket positive, so their lack of pairs is **inconclusive**. A further 20 dotted controls found a valid Helvetica18 positive. The final 70-case Helvetica grid uses font sizes10/12/14/16/18, literal `2`/`2.`, and x210/241/243/245/247/249/251. It includes ten inside-bracket positive attempts and sixty edge/outside cases. Native recognition is not assumed to succeed for every font/size. See the complete source PNGs, input rosters, native results, and replay rosters under `adversarial/`.

The exact same 70 images through the frozen pre-fallback detector (`a85fc99d998c8054ebd29f97c3efa2dd93edf574d5b1b707edebe8e60e74a395`) produce **one pair**. The candidate produces **eleven pairs**: three valid inside-bracket pairs and eight partly off-bracket pairs. Ten pairs are new; the original valid pair is retained. All eight partly off-bracket pairs were rejected by the baseline. Wholly outside numerals in this grid were rejected; this does not prove they are always rejected.

Three accepted copies do not enclose all printed punctuation ink:

| Fixture | Source glyph ink right edge | Copy right edge | Dark glyph pixels partly/fully outside |
|---|---:|---:|---:|
| Helvetica16 `2.` x245 |257|256.8|1|
| Helvetica18 `2.` x243 |257|256.8|2|
| Helvetica18 `2.` x245 |259|256.8|6|

In the last case, all six dark pixels of the dot lie partly or fully beyond the copy edge; native wide OCR reports `2`, accepts the pair, and the returned copy cuts the printed dot. The numeral itself also extends beyond the printed bracket endpoint, so it should not be automatically attached to that bracket merely because a wider OCR cell contains it. The marked source closeup is `adversarial/helvetica-size18-text2.-x245-copy-clip.png`. These are actual native analyzer outputs, not simulated OCR. `helvetica-source-checks.json` records every accepted fixture's source ink and copy bounds; `helvetica-comparison.json` binds the baseline comparison.

## Confirmed merge and provenance defects

The detector constructs candidate `c`, appends `accurate-wide` evidence to `c.evidence`, but on duplicate grouping executes `groups[i].evidence += evidence`, where `evidence` contains only the original narrow passes. The fallback evidence is lost whenever this is the later duplicate proposal.

`adversarial/grouping-control.swift` extracts the candidate/role definitions and exact unchanged merge block from the frozen detector, then injects controlled evidence into a pair of geometrically mergeable proposals. This is **a controlled merge reproduction, not a claim that a natural Vision duplicate case occurred in the corpus**. It confirms:

- Earlier no-role + later wide2 → actual no-role; expected second. The group counts two members but retains no evidence.
- Earlier narrow1 + later wide2 → actual first; expected conflict/no-role. The later contradiction is discarded.
- The earlier-wide2-only control and the separate later-narrow1 control behave as expected. Even later same-label fallback provenance is dropped, though its role happens to remain unchanged.

A second data issue remains: assigning the wider rectangle to `c.numberBounds` does not transform earlier narrow evidence boxes. Those boxes are normalized in different padded/resized OCR images, yet share one candidate rectangle. Merging can also combine differing proposal rectangles. Future containment checks must map **each** observation to an explicit source-page rectangle using its own OCR crop, scale, and padding; applying a shared numberBounds would give incorrect source coordinates.

The wider retry keeps the same vertical window and existing ownership/adjacency barriers; it does not by itself extend into another system. Nevertheless, the source negatives show that previous-staff notation and beams inside that window can resemble hooked lines and numbers. Pairing mitigates those particular cases; it does not validate that the recognized number belongs to the candidate bracket. The scratch diagnostic print also remains in the frozen detector and must not be shipped.

## Next bounded change and gates

Use explicit per-observation source boxes and preserve `c.evidence` when merging. Base the additional reading interval on the actual bracket's endpoints, with source numeral containment and full copied-ink checks, rather than another fixed staff-space width. Keep conflicting observations conservative. This must recover the p21 numeral without accepting nearby unrelated digits or silently cutting punctuation.

Re-run these native edge controls, the two real false candidates, all14 independent source guards, the original ending controls and the complete frozen corpus. Then export affected parts and independently check source placement, duplication, clipping, and pagination. Current six real recoveries and prior broad-corpus retention do not override the reproduced failures.
