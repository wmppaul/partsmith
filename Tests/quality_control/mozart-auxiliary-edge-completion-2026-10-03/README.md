# Rejected: complete small ink intersecting a crop edge

**Do not promote this candidate.** It repairs the Mozart Piano “earliest edition” label but also retains more notation belonging to neighboring instruments. It completes unrelated footer text and scan scratches. Nearest-staff geometry is insufficient evidence of ownership for these detached marks.

The rule was frozen before execution in `rule-before-results.json`: after automatic compact cropping, make one outward-only pass over small ordinary unowned components that cross the initial edge. Limit height to two staff spaces and width to eight; require horizontal crop overlap, no foreign staff-core intersection, and strictly nearer target-staff geometry. Complete the component plus existing clearance. No recursive chaining, new vocabulary, per-page exceptions, assignment changes or explicit-crop changes.

The only private Core change is in `ScoreExtractionPlanner.swift`, SHA256 `9dea331dabc1cf8b319fb866633d7d0de630c3ab35b8d9135e8a466c2bbc2e51`. `candidate.patch` is the reproducible 30-line addition. Production and delivered parts were not changed.

| Check | Result |
| --- | --- |
| Positive/negative candidate controls | 15 pass; baseline also passes its 15 expected controls |
| Existing native planner tests | 111 pass |
| Existing system-boundary tests | 423 pass |
| Existing crop-quality tests | 765 pass; existing three-row-gap limitation remains |
| Entire native Mozart inventory | 30 pages, 476 bands, 6 direction copies; 7 crops expand |
| Entire native Brahms inventory | 39 pages, 604 bands, 42 direction copies; 9 crops expand |
| Crop shrinking / other band-field changes | 0 / 0 |
| Newly included complete foreign staff cores | 0 |
| Visual source ownership check | Fails: 7 crops add more neighboring music |

All 16 changed full-width source contexts were inspected before their before/after pairs. `source-classification.json` records each case. The expansions comprise one useful editorial label, one completed composer/work line, seven additions of neighboring music, four publisher/footer expansions, one original page number and two scan scratches. Several added fragments remain clipped because completing one component expands a full-width rectangle across other unrelated ink.

The motivating Piano crop moves from bottom 733.7186 to 737.0411. It retains the complete observed label, whose nonwhite ink reaches 735, and the already present small staff. The original conservative label guard ends at 738 and still fails; `guard-results.json` preserves that failure. No guard was weakened.

Planning elapsed times in this concurrent run were Mozart 0.316→0.323 seconds and Brahms 0.477→0.498 seconds. These are single-run measurements, not performance guarantees. Both use the same previously generated native inventories, without new OCR. The low-level Brahms replay retains the title-page unresolved status on page 1 because it lacks the document coordinator's recorded automatic nonmusic-page handling; that status is identical in both variants. All 604 music bands and 42 source copies are compared. This was not a new complete app Auto run or a revised PDF delivery.

The related original source audit is [mozart-auxiliary-review-2026-10-03](../mozart-auxiliary-review-2026-10-03/README.md). The next useful mechanism needs evidence that a detached annotation block belongs to this staff, rather than merely completing anything cut by a rectangle. This candidate was stopped after the source regressions; no threshold retuning was attempted.

`evidence.zip` contains both frozen Core snapshots, controls, bound source inventories/profiles, plans/logs and all 16 source contexts and before/after images. It excludes executable binaries and original PDF duplication. The production source has since received separate parent-owned bar-number changes; those are outside this frozen crop-only experiment. `report-hashes.json` hashes every other report file.
