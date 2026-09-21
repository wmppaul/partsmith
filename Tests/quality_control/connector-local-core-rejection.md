# Rejected local staff-core translation

A local scan bend explains one remaining false join in Brahms Quartet IMSLP93521, page 31, system 1. At the interior barline near x297 pt, the actual upper staff lines are approximately y196, 210, 224, 238, 252 in the 1800px raster. The detector's page-center upper core is y189–245. The intact barline therefore receives 49/56=87.5% core support and fails the existing 88% requirement.

The archived candidate used sustained horizontal ink at all five locally translated staff lines to adjust only the connector's core test. It retained the 88% threshold and did not change the staff detector, planner inputs or source pixels. On that one page it reduced multi-owner components 2→1, foreign staff-line centers 20→18 and whole neighboring staves 2→1. A separate narrow right barline still caused contamination.

**The candidate was rejected because it split genuine musical notation.** Existing 82 controls passed, but a new curved-staff fixture containing a near-full cross-staff stem and two noteheads failed at local bow −7px, page tilt −1.5°, raster scale 0.6. The production analyzer preserves the same source figure. Better crop metrics do not justify losing target notation.

`tools/test_crop_quality.swift` now retains all 82 original assertions and adds 18 preservation controls covering both bow directions, three skews and three raster scales. The fixture defines source pixels independently of analyzer output; a connected figure must remain ambiguously owned by both staves. The archived patch is diagnostic evidence and must not be treated as a production fix.

Exact before/after geometry, source and code hashes, test conditions and final production test status are recorded in `connector-local-core-rejection.json`. The rejected patch is `connector-local-core-rejected.patch`. No further algorithm experiment was performed for this checkpoint.
