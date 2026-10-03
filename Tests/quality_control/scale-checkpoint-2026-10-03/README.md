# Scale checkpoint — 3 October 2026

Fresh targeted verification of current source at `e6f592d07e82fcd634c8bcc653e41710afd07e62`. This verifies the existing scale fix from `cb75c1e`; it does not introduce another scale implementation. The original September review remains at `Tests/extraction/scale-enlargement-review.md`.

## Results

- `bash tools/test_layout_export.sh`: **5,389 layout assertions** and **169 native crop/export checks** pass.
- `bash tools/test_scale_exports.sh` compiled the current sources. Restricted execution stopped at the Core Image rectification fixture (`failedRectification(0)`, exit 133), the already documented native graphics limitation. Running the **same compiled** `.build/test_scale_exports` with macOS graphics access completed: **288 checks, zero failures**.
- Independent full-source PDF reference comparisons pass at scale **0.8, 1, 1.25, 1.4**, including scanned Beethoven, copied directions, tiny edge ink, and rectified music. Reference draws retain the entire original source crop rather than trusting proposed side trims. Above 1, the existing pixel assertion permits at most two channel levels of antialiasing variation; at/below 1 it requires exact pixels.
- The fixed three-strip Beethoven fixture achieves **1.1273×** at requests of either **1.25× or 1.4×**: about **12.73% actual notation growth** over scale 1. The widest retained source strip then reaches the page width. This result applies to this fixture, not to every band in the complete symphony.
- Spacious digital and rectified fixtures reach **1.25× and 1.4×**. The tiny edge dot/ledger control limits enlargement to **1.0081×** and retains that ink.
- Reducing Side Margins from **48 to 12 pt** adds **72 pt** of available width on Letter paper (516→588 pt, another **13.95%** at the same width-limited scale). The Beethoven output-width assertion and complete-source preservation comparison pass. Parent reviewer visually compared the generated scale-1 and narrow-margin images and confirmed growth with source fragments preserved; three fresh images are included here.
- Current 120-strip enlarged preview: **0.676 seconds**; cached spacing update: **0.041 seconds**. These are observed timings, not guarantees. Main-queue responsiveness, source/correction cache invalidation, cancellation, and latest-request publication checks pass.

## Remaining limits and practical use

The former `min(partScale, 1)` clamp is absent. The supported control range remains **0.6–1.4**. Above 1, independently verified blank source side space can be removed; visible source ink, including tiny marks and neighboring notation, constrains enlargement. With **Use Consistent Scale**, the widest retained strip limits all systems; with it off, each strip has its own limit. An individually over-height crop also fits down to a page, while page balancing itself preserves scale. Printed source headers have their own fit and are not enlarged by the part scale.

For the user's white-space case: increase Scale, then reduce **Side Margins** to widen music further when the Inspector reports a limit. The preview updates when the slider is released. This retains all source notation rather than enlarging beyond the page and clipping it. No new UI or production-code change was needed for this checkpoint.

`provenance.json` records the complete compiled core-source set, UI/test sources, fixture, binaries, and generated artifact SHA-256 hashes. The two successful run logs and the restricted-graphics attempt are kept separately. This checkpoint does not claim complete Beethoven extraction or new staff-assignment/rest-detection validation.
