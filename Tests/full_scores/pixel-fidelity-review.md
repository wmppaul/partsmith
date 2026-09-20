# Full-score pixel fidelity review

All five final score sets pass **1,326 protected/source-cue regions and 382,119,104 compared pixels with zero canonical differences**. This is exact 216-dpi grayscale comparison with zero pixel tolerance; it supplements the independently reviewed musical maps and visual page checks.

| Score | Regions | Pixels | Raw MuPDF differences | Canonical differences |
| --- | ---: | ---: | ---: | ---: |
| Ave verum corpus | 64 | 14,419,515 | 4,687 | 0 |
| Notte e giorno | 40 | 16,094,162 | 5,288 | 0 |
| Frauenliebe und Leben | 175 | 59,121,204 | 0 | 0 |
| Quartet Op.67 | 640 | 143,419,895 | 0 | 0 |
| Clarinet Trio Op.114 | 407 | 149,064,328 | 0 | 0 |

`tools/review_score_output.py` verifies source/output hashes, system coverage/order, proportional placement, staff inclusion, page bounds, nonoverlapping strips and source-guard containment. Both `geometry.json` and `pixel-fidelity.json` bind the exact parsed map bytes as `sourceMapSHA256` and the reviewed manifest metadata as `normalizedManifestSHA256`. The latter hashes UTF-8 JSON after removing only top-level `status` and `reviewRecord`, with `sort_keys=True`, `separators=(',',':')`, and `ensure_ascii=False`. Final review stamps therefore remain valid; source-map or placement changes invalidate the binding. Each main protected region is compared against the **untrimmed original source page** at the manifest's checked transform. Its reference matrix is serialized to 12 decimal places: PyMuPDF's default five-decimal matrix rounding changed bitonal resampling enough to produce false differences. The correction changes only the independent reference placement precision, not source ink or output PDFs.

Shared directions use their independently reviewed source-fragment rectangles as the reference extent. Matching the fragment clip is necessary because the renderer's bitonal resampling phase depends on visible image extent. Main staff guards retain the untrimmed reference. This distinction does not authorize shrinking a target guard or source cue to hide clipping.

For vector-only source pages, CoreGraphics rewrites path/glyph transforms during PDF serialization. Direct MuPDF comparisons consequently retain the 9,975 raw edge-pixel differences above. The tool independently draws the complete original vector page at the checked placement into a separate reference PDF, then compares both PDFs with the same MuPDF renderer. That reference contains no Partsmith code, exported content, note reconstruction or cleanup masks. Its standalone Foundation/CoreGraphics Swift helper is embedded in the review tool and compiled into a temporary directory using local `swiftc`; no preexisting `.build` executable is required. Canonical equality means exact pixels after this documented serialization step, not identical PDF bytes. Source content/image dictionaries and final output files remain unchanged.

Negative controls used isolated copies of real outputs; original output hashes were unchanged:

| Control | Expected and observed result |
| --- | --- |
| Unchanged Trio Clarinet p2s1 | Pass; 0 differing pixels |
| Remove the first entering Clarinet triplet note at source p2 [248,79,257,91] | Fail; 285 differing pixels |
| Move that crop inside its independent protected region | Fail at guard containment, before pixel comparison |
| Remove Quartet Violin II p1s1 shared Vivace | Fail; 1,199 differing pixels |
| Unchanged Ave Soprano p1s1 vector control | Pass; 0 canonical differences |
| Erase that vector staff's protected region | Fail; 22,771 differing pixels |

The maintained harness is `Tests/full_scores/test_pixel_comparator.py`. Run `.build/extraction-venv/bin/python Tests/full_scores/test_pixel_comparator.py` from a checkout containing the final score sets. It recreates all six isolated controls, checks report bindings, confirms that a review-state stamp leaves the normalized digest unchanged and a placement change invalidates it, and records per-case `review.log` files without modifying production PDFs.

The durable record is `Tests/full_scores/pixel-comparator-regressions.json`, copied from `.build/pixel-comparator-regressions/full-corpus-result.json`. It preserves per-score output SHA-256 hashes, exact totals, control results/errors and original report filenames. Final detailed reports are `output/pdf/full-score-sets/{ave,notte,schumann,quartet,trio}/review/pixel-fidelity.json`; transient control reports remain named in the JSON under `.build/pixel-comparator-regressions/`. The deleted-note source context was visually confirmed in `removed-clarinet-note-source-context.png` in that transient directory. These generated files may disappear during build cleanup; the committed aggregate retains the reviewed results and hashes.
