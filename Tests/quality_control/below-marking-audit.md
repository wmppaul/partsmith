# Independent below-system source marking audit

Reviewed the new placement field through `ProjectModels`, `PartLayoutEngine`, `PartsmithDocument`, planner models/conversions and `copySharedNavigation`, plus native export and review-manifest propagation. This audit intentionally excludes the crop-boundary algorithm, covered separately. Native OCR app integration remains disabled during this review.

## Concrete finding and fix

The first crop edit on an automatic plan converted every band to an override with `rect: nil`. Navigation propagation had enlarged the source owner's main crop and deliberately avoided a duplicate marking fragment. Replanning those nil rectangles did not reapply navigation, so editing a different band silently removed the owner's enlarged region.

Reproduced using the existing two-part/two-system navigation fixture: the owner's vertical crop was `[0.3775, 0.43]` before editing the recipient and `[0.3775, 0.4025]` afterward. The ordinary 73-check suite still passed because it checked recipient fragments but not the owner rectangle.

Fixed fresh override construction in `ScoreDetectionReview.setCrop` to store each current band's complete actual rectangle, matching the existing assignment-to-override conversion. Two independent regression cases now check all four owner crop edges after editing (1) the recipient and (2) a band in another system. All 75 review-initialization checks pass. This fix does not change planner geometry or manually selected edges.

## Other inspected paths

- `BandSourceMarking.isBelow` and `ScoreSourceMarking.isBelow` are optional Codable fields; absent legacy values keep above-system behavior. Override side arrays are optional and must match the rectangle count when supplied.
- Both assignment-to-override and crop-to-override conversions preserve the per-fragment side. Native apply copies it to the project model. An unchanged part/candidate assignment retains the previous override, including rectangles and side metadata.
- Prepared layout height includes the maximum above row, the music height, the maximum below row, and both fixed gaps. Pagination uses that full height, oversized fitting uses both rows, and the next band's cursor starts below the lowest below fragment.
- Same-side fragments with overlapping horizontal spans are rejected; opposite-side fragments may share a horizontal bar position. Each fragment keeps its source rectangle, its music scale and its horizontal source offset. Horizontal blank-edge trimming also retains both sets of source rectangles.
- PDF export draws the original source page at the computed rectangles, using the saved rectification. It does not replace instructions with OCR text. `SourceMarkingPlacement` and the manifest preserve the side; the output reviewer checks the expected side and whole music-plus-marking group against the next system.

No additional concrete layout, persistence, source-pixel or apply blocker was found in those paths.

## Separate follow-up owned by root

Resetting the owner's crop or rebuilding an assignment still needs navigation reapplied on reviewed pages. Root is implementing idempotent propagation there while respecting explicit user crop rectangles. This report does not claim that later planner change has been independently validated. Required checks are automatic owner reset, assignment rebuilding, preservation of explicit owner crops, and no duplicate fragments or spurious overlap warnings after repeated planning.

This is a code-path and targeted-regression review, not a visual pass of all extracted PDFs or of native OCR ownership on unseen scores.
