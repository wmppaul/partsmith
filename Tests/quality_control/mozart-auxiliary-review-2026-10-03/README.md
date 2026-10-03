# Mozart K. 478: auxiliary-staff coverage review

The current Piano part **retains the small editorial alternative on source page 1**, including its notes, staff lines and dotted connections. It clips the bottom of the accompanying English “earliest edition” label by about 1.2 source points. This is an annotation-preservation defect, not an omitted instrument or missing auxiliary notes.

All 30 original source pages were visually reviewed for separate auxiliary staves. Only this passage was observed. The source has 119 normal systems: three on page 1 and four on each remaining page. This bounded overview does not certify every normal-size note, grace note or cue, nor establish general auxiliary-staff detector recall.

## Source-defined obligation

Original: `sample_scores/medium_skewed/01_mozart_piano_quartet_k478_imslp_86903.pdf`, SHA256 `33ba263af431caa89d16530adcce3bf230b9c8b2e2367b737835c112fcfc99c8`.

The original last Piano system on physical page 1 labels its main bass reading “Autograph / MS” and a smaller reading below it “Älteste Ausgabe / earliest edition.” Dotted barline extensions align the alternative with the parent bass passage. It belongs with Piano as an editorial alternative; it does not establish a new simultaneous instrument, new independent system or an inferred rest duration.

The full original page and enlarged source context were inspected before current crop bounds. `p01-frozen-source-obligations.json` freezes four conservative source rectangles; `p01-precomparison-hash.json` binds that precomparison evidence. These rectangles have not been changed to fit the result. They include some surrounding white space and are not pixel-level ownership masks.

| Obligation | Frozen source rectangle, points | Current result |
| --- | --- | --- |
| Small staff, notes and ledger strokes | [354, 715.5, 454, 733.5] | Contained; measured nonwhite ink reaches y731.75 |
| Two-line alternative label | [278, 716, 352, 738] | Fails containment; actual ink reaches y735 and is clipped |
| Dotted connections and aligned passage | [354, 684, 454, 733.5] | Contained |
| Main-reading label | [308, 662, 356, 684] | Contained |

`all-pages-source-review.json` records every original page, overview verdict and original rendered-image hash. Five source contact sheets preserve the overview; the enlarged original page-1 context preserves the positive passage.

## Current exported output

Reviewed delivery: `output/pdf/auto-qc-2026-09-21/mozart-k478-86903-preservation`.

All four parts remain unchanged: Violin 8 pages, Viola 8, Violoncello 9 and Piano 18, totaling 43 pages. Each has 119 main bands. The complete set has 476 bands and six copied shared directions. No copied direction is responsible for preserving the editorial alternative: `p1-s3-piano` has no source-marking copies.

The relevant crop is source page 1, system 3, Piano, candidate IDs 13 and 14:

- Source rectangle: [0, 616.6748997212229, 543.6, 733.7185798677548].
- Piano output page 1, destination rectangle: [48, 357.681730968362, 564, 468.7827960081163].
- Piano PDF SHA256: `256f35f9736a4a8db0e477a6dd6c618947a3236ce906370bfbe66c47e58e9640`.

The complete small staff and notes are visible in the actual exported PDF. The English line's bottom is visibly cut even when the PDF is rendered beyond the band's destination rectangle, so this is not an artifact of cropping a review image. Bounds use all nonwhite pixels (gray <255). Original-source measurement at eight pixels per point finds 186 dark pixels below the delivered source boundary within the frozen label guard; no such pixels occur below that boundary in the frozen small-staff guard. This count is raster-resolution dependent, not a count of musical symbols.

See `original-p01-piano-edition-context.png`, `current-piano-output-p01-system3.png`, `original-p01-edition-label.png` and `current-piano-output-p01-label-with-surroundings.png`. `p01-initial-output-comparison.json` preserves measurements and exact placement data.

## Mechanism and bounded next experiment

The source-bound native inventory detects 15 regular staves on page 1. The small alternative is not a main staff candidate. It survives as a detached ink component, with native bounds [355.454, 717.0682750301569, 451.792, 731.5667068757539]. Its bottom plus the ordinary 2.151872992-point clearance exactly equals the delivered crop bottom, 733.7185798677548.

The nearby alternative label is disconnected. The nearest gap from its rightmost component to the small staff is about 8.456 points; the planner's detached-mark relay allows about 4.304 points horizontally. Thirteen existing unowned English-label components intersect the final crop boundary and extend below it, up to y734.8892641737033 in the native analysis. The final crop does not complete those intersected components. `p01-mechanism.json` binds the exact inventory, component bounds and arithmetic.

The smallest general experiment justified by this evidence is **outward completion of small, detached components already intersected by the final crop edge**, after ordinary ownership planning. It would use the initial final edge rather than repeatedly growing through new detached rows, require evidence that the component belongs with this staff region, and preserve existing owned/ambiguous music. This is a proposal, not an implemented or validated correction. A naïve closure over every intersecting component can add neighboring notation; proximity alone is not sufficient at inter-staff or inter-system boundaries. The existing neighboring-staff and detached-direction controls must remain unchanged.

A useful regression would bind this original source and all four frozen obligations, retain the complete small staff and both label lines, and verify unchanged staff assignment, source-copy inventory and non-target crops. It should also challenge a nearby following staff, a footer or page number, long connected components, disconnected punctuation, and auxiliary staves above or between parent staves. A full auxiliary-staff model could later encode ownership explicitly, but adding a sixth instrument or a page-specific crop override would not address the general defect.

No candidate was implemented. Existing conservative guards remain in force; the failing label guard is retained. No native OCR rerun was needed for this investigation.

## Scope and evidence

Known duplicate Piano headings and neighboring fragments in these draft parts are unchanged and outside this auxiliary-staff review. No production source, project, PDF or prior report was modified. `input-bindings.json` binds the original, source-bound native inventory, current Core files, embedded project and all current PDF hashes. `source-review-evidence.zip` preserves the original full-page renderings, existing native page-1 analysis, relevant output metadata and reproducible measurement scripts. `report-hashes.json` hashes every other report file.
