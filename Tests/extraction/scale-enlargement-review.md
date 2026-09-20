# Scale above 1: native export review

Run `bash tools/test_scale_exports.sh` on macOS. Its Core Image rectification
cases need normal macOS graphics access; a restricted agent sandbox can compile
with `--build-only` and run `.build/test_scale_exports` with native graphics
access. Test images and PDFs are temporary QA artifacts in
`.build/scale-export-tests/`, not complete extracted parts.

## Source and controls

The real scan is `Tests/extraction/sources/beethoven-op67-pages-7-8.pdf`.
Its provenance, source hash, and pixel-identical page-copy verification are in
`beethoven-op67-pages-7-8.json`. The test uses the complete horizontal source
width and the following top-down crop fractions:

| Original PDF page | Top | Bottom | Retained content |
| --- | ---: | ---: | --- |
| 7 | 0.307 | 0.367 | Opening flute, printed name, tempo, fermatas, all 13 bars |
| 8 | 0.016 | 0.090 | First-system flute notes and the existing broad crop's neighboring ink |
| 8 | 0.516 | 0.550 | Second-system flute's 12 rests |

These are fixed preservation fixtures, not new claims about automatic staff
assignment, multi-rest recognition, or complete Beethoven part extraction.
All top and bottom crop edges remain unchanged.

Synthetic native PDF controls contain staff lines, noteheads, stems, a part
label, a separately copied direction extending left of the staff, a tiny edge
dot, and a thin edge ledger line. A perspective-corrected version verifies
analysis and rendering in corrected coordinates. The upper direction and
lower music have deliberately different horizontal bounds to expose vertical
coordinate inversion. Whiteouts must not change the source ink analysis.

## Independent comparison

For every scale (0.8, 1, 1.25, 1.4), the production exporter is compared against
an independently assembled PDF that draws the **entire original crop** through
the chosen affine transform. The reference does not use the proposed side trim.
Both PDFs are rendered at 144 dpi and compared over the entire output page,
including outside the proposed retained crop. Copied directions are also
included. This detects omitted margin notation as well as altered source ink.
Scales at or below 1 additionally retain their prior geometry exactly.

The reviewed run's saved actual and reference PNGs are bit-identical in every
fixture, including the scanned and corrected pages. The automated assertion
requires exact pixels at or below 1 and allows at most two channel levels above
1 for platform antialiasing variation; the reviewed run required no tolerance.

## Observed results

- Spacious native and corrected music actually enlarge to 1.25 and 1.4.
- The three Beethoven strips enlarge to **1.1273** at requests of either 1.25
  or 1.4. The widest retained strip limits consistent scale, and feedback
  correctly reports the limit. This figure applies to these three strips,
  not every strip in the full 106-page score.
- Tiny deliberate edge ink limits its control to **1.0081**. It survives intact.
- Reducing the part's output side margins from 48 to 12 points provides visibly
  more music width without changing source crops or another part's settings.
  Saving/reopening preserves explicit 12-point and zero-point overrides as well
  as inherited margins. Undo, Redo, and Reset restore the original geometry;
  older projects with no override retain asymmetric project margins.
- Three Beethoven strips require exactly two page analyses. Subsequent scale
  and spacing changes reuse those results. Changed source data or rectification
  invalidates the appropriate analysis; scale 1 needs no side-space analysis.
- A 120-strip scanned part completes its enlarged background preview in about
  **0.69 seconds** on the test Mac; a subsequent cached spacing change takes
  about **0.04 seconds**. These are observations, not fixed timing requirements.
  The main queue remains responsive, superseded work cannot publish, and a
  cancelled analysis never caches partial bounds.

## Native app interaction

A separate two-page Beethoven test project was opened in the Release app.
Increasing Scale from 1.00 to 1.10 visibly enlarged the music. At 1.25 the
Inspector reported the width limit. Reducing Side Margins from 48 to 24 points
visibly widened the notation again. Saving the project retained `scale: 1.25`
and `sideMarginPoints: 24`; the test window was then closed. The user's restored
106-page document was left unchanged. This UI fixture used slightly different
vertical crops from the pixel-comparison fixtures and reported a 1.12 limit.
