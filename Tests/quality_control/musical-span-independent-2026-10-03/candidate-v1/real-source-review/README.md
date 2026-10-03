# Independent original-source verdict

All five unannotated source contexts were inspected first, followed by all eight interval details and all sixteen raw fitted-body regions. The original source is Brahms Quartet Op. 67, IMSLP93521 (SHA256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`), with the same nine saved rectifications. `bindings.json` binds the five original grayscale rasters and the author's corresponding raw witness logs. The parent’s input manifest binds all 39 source renders; this reviewer did not rerun that full score.

The eight new intervals do not identify shared musical shafts between instrument parts:

| Source | New intervals | Observed source at the accepted bodies |
| --- | ---: | --- |
| p23, system 4 | 2 | Two fits of the same ordinary barline. The upper body is a slur/staff-line pocket, and the lower body is a staff/barline cross. Both are labeled filled. |
| p28, system 3 | 1 | Ordinary Coda barline crossing a tie/staff-line pocket above and a slur below; both bodies are labeled filled. |
| p29, system 4 | 1 | Right terminal double barline with staff-line T junctions; neither filled fit is a notehead. |
| p38, system 4 | 2 | The first interval fits plain staff/barline crosses. The second follows the right system edge and accepts a filled junction above and an incomplete open corner as hollow below. |
| p39, system 2 | 2 | Separate local slurs crossing ordinary barlines; three bodies are labeled filled and the first upper body hollow. No cross-instrument note stem is present. |

`all-raw-body-fits.png` shows original grayscale samples enlarged by nearest-neighbor sampling, with accepted body rectangles outlined. It includes every body from the eight raw records, without masking staff lines or removing inconvenient source marks. This confirms that the false positives arise in the body classifier itself; they are not merely actual noteheads connected to a barline through a long staff line.

The parent’s complete 39-page, 604-band comparison reports 13 outward crop expansions on these five pages. Ten changed crops newly contain a complete foreign staff core, totaling 14 new crop/foreign-core relations. All previous ordinary components and alternatives are retained and no crop contracts according to that comparator. These are parent-run results, independently checked here for counts and visually assessed at the source; they are not a second full native run by this reviewer. The author's logging-only five-page replay has exact plans and equal normalized component multisets; p23 and p29 differ only in component array order.

The candidate is rejected for crop quality. Preservation-only additions avoid new clipping in the measured comparisons but create unsupported shared ownership and extra neighboring staves. This review does not certify all 604 musical crops, produce new parts, or rerun/change the ten immutable source guards. The existing p35 guard failure remains unchanged and outside this candidate's five changed pages.
