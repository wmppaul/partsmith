# Independent Brahms 93521 quality evidence

**The candidate1 outputs remain drafts and fail crop readability and shared-direction completeness.** This folder records independent source evidence for the 39-page IMSLP93521 edition, not the different 25-page quartet scan.

`shared-directions-raw.json` contains 49 source regions from all 151 systems: 41 shared-copy obligations (123 target-part assignments), plus 8 controls already printed on every staff. `shared-directions-corrected.json` binds the companion to the exact full-page derivative and all nine recorded page rectifications. Nine cue regions change coordinates; forty retain raw coordinates. All 49 derivative fragments were visually checked at 360 DPI; the nine changed regions were also compared side by side with the original. Three combined rehearsal/tempo labels have separate rehearsal-letter fragments to prevent duplicating tempo words already on lower staves. No oracle was fitted to detector output.

The corrected boxes are envelopes of the raw boxes transformed using the recorded renderer homography, rounded outward to 0.1 point with a 0.2-point interpolation allowance. One raw Agitato bound was expanded upward by 1 point after source-fragment review to retain the parenthesis contour. No cue was shrunk to OCR. Coordinates are top-down PDF points; page/system numbers are one-based. Exact hashes, corrections, counts and artifact paths are in `evidence.json`.

| Artifact | SHA-256 |
|---|---|
| Immutable original source | `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a` |
| Corrected full-page reference | `49fc54096ebcb15658bc35914d5224f048abda2a90bb0ca387387c2258742a82` |
| Candidate1 Violin I, 24 pages | `1f0d933362fc24285f391fb0ed1d4557939cec39310838d5f11ecbd845ac03ac` |
| Candidate1 Violin II, 21 pages | `25fd0f429258b2230aab4f9ca32a806dc955d6ba5767c2c28ed8743a638f11d1` |

All 45 violin output pages were inspected; observations and hashes are in `candidate1-violin-page-review.json`. Structural checks found each part's 151 systems in order, with no duplicate/missing placements, out-of-page placements or layout overlaps. Nevertheless, numerous strips contain whole neighboring staves or quartets. The first Violin I crop slices source composer text. Violin II omits Vivace, Andante, Agitato, Trio, and Poco Allegretto con Variazioni; Coda and Doppio Movimento are sliced. All copied-source-marking lists were empty. An output overview is not a full source-context preservation review of all 302 violin bands.

Detector priorities include rehearsal letters among high notes, first/second ending brackets, the p26s2 return cross, and p31s4 fermata above the repeat barline. Page 28's D.C. instruction is below cello and belongs to **system 2**, while Coda belongs to **system 3**. Repeated tempo text should not be copied again. Nearby technique marks such as con Sord., pizzicato and arco must not be indiscriminately applied to other instruments. Some cue rectangles contain adjacent musical ink because the engraving overlaps; these are detection/preservation goldens, not permission to erase pixels or a promise of a clean pasted rectangle.

`corrected-source-cue-comparison.png` preserves side-by-side evidence for the nine transformed regions. Full source/context/fragment sheets and draft page renders remain under `.build/qc-quartet-review/`. A seven-heading recognizer can be measured against the seven large headings in this oracle, but succeeding there does not satisfy the remaining shared-direction obligations or establish a whole-score pass.
