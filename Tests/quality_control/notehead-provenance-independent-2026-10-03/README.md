# Independent real-source notehead and spine controls

The source obligations were frozen on production `77f409a2d40639012918c9843895c557ba4f8a71` before inspecting the new notehead prototype. Production NativeScorePageAnalyzer remains SHA `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`. No production file or pre-existing 180/36 synthetic fixture was edited.

`holdouts.json` contains **22 source-defined cases** on twelve immutable native page rasters: seven genuine notehead/own-stem positives (five filled and two hollow), two wrong associations between those same genuine heads and nearby structural barlines, and thirteen previously observed structural false witnesses. Each source PDF, native raster, original-pixel context crop and separate ruler image is hash-bound. All source contexts and all thirteen false-witness crops were visually inspected. The body/spine/target bounds and expected classifications remain unchanged after the prototype was disclosed. Holdout SHA: `f9ae21baf633a86a217d260c54db97751a88f4984f76f5f17fa2836e69186a2c`.

## Source obligations and limits

Coordinates are integer **top-left native-raster pixels**, with right/bottom excluded. The corrected Brahms93521 p38 raster is the exact frozen raster from the delivered corrected-source workflow; its coordinates must not be applied to the raw PDF. The other eleven pages use original native PDF rendering. `native-replay-inputs.json` supplies the historical staff geometry and source/raster bindings without baseline component outputs.

The genuine source cases include hollow heads on opposite sides of their stems, a head crossed by a staff line, a filled tied note at the lower staff edge, a visibly curve-connected filled head, and filled ledger heads on long stems. Body boxes are source-review regions, not claims that every enclosed staff-line pixel belongs to a notehead. Positive note-envelope boxes conservatively contain the selected head and stem. They are independent of any proposed crop or fitted ellipse. Nearby barline negatives deliberately reuse exactly the same genuine body as a positive case: the intervening staff line does not transfer the head's musical ownership to that barline.

A hollow scan cavity is not necessarily pure white. The p38 bottom-line half-note has source gray values 225 and 219 on a 0-black/255-white scale; the other hollow head has values 243 and 206 and a staff line dividing the cavity. The helper probe uses the native Core Graphics grayscale conversion and native 190 threshold, not a newly chosen image threshold.

**Coverage gap:** no confirmed real musical single spine traversing two complete staff cores was found in these reviewed source contexts. Ordinary and ledger stems cannot certify recovery of that harder case. These controls complement the unchanged synthetic 180/36 and broader 297/336 controls; they do not replace them or certify complete parts.

The thirteen structural negatives retain nearby genuine notes and ties/slurs as source-owned music. Rejecting a spurious notehead on a barline is not authorization to delete the curve or neighboring musical ink. This report tests evidence identity, not an automatic cleanup proposal.

## Candidate evaluation protocol

`helper-inputs.json` is a separate adapter prepared before first helper execution. It binds to the unchanged holdout hash. Physical black-spine widths are measured inside the frozen source corridors using the median row-run endpoints, excluding the selected head and staff-line rows. Existing historical staff geometry supplies API coordinates only, not true musical ownership. False-witness coordinates reuse the recorded actual core shift. `helper-probe.swift` loads hash-checked source pixels and calls the frozen helper directly.

Helper acceptance and actual native structural-erasure-path participation must be reported separately. The helper's vertical window covers four of the seven selected genuine heads. Both ledger heads and the physically tied middle-line head lie outside that window; they are explicit coverage omissions rather than silently counted native-path successes. No ordinary own-stem case is asserted to traverse the long-connector native path merely because a direct helper test accepts it.

The frozen candidate results below retain this protocol and all original source obligations unchanged.

## Frozen candidate v1 result

The tested candidate is `.build/notehead-provenance-2026-10-03/candidate-v1/Core`, Native SHA `8c2fa3f665dd1c41f95ac44b9f30fc0a6cdc094f5cac016cd866711badd41af3`. The independent helper binary was compiled from that immutable snapshot and run once against all 22 cases.

| Source obligation | Direct helper result |
| --- | --- |
| Seven genuine own-stem heads | 0 accepted |
| Four genuine heads whose centers lie inside the helper's vertical search window | 0 accepted |
| Two genuine heads deliberately associated with a different nearby barline | Both correctly return no witness |
| Thirteen structural barline/curve/staff intersections | 12 return no witness; **F05 is falsely accepted as hollow** |

The four in-search positives were then retested in a separately labeled input-fidelity diagnostic. The original global staff fit differs from actual local p38 scan lines by roughly 1-3 pixels. Before rerunning, five local line centers were frozen from original grayscale profiles in independently inspected adjacent staff-only fragments. Source body boxes, physical spine widths, expected ownership, staffSpace and slope stayed unchanged. `local-line-source-measurements.json` records every source sample rectangle and its complete row-darkness profile. This follow-up was prepared **after** seeing v1 primary results and is not represented as a blind holdout. All four still return no witness in `candidate-v1-local-line-results.json`; the global-to-local row discrepancy alone does not explain the misses.

Representative inspected misses are P01, a hollow half-note on its own upward stem at the Cello's bottom staff line, and P03, a genuine filled tied note on its own upward stem. Their original source ruler views are `review/P01-hollow-up-stem-bottom-line-ruler.png` and `review/P03-filled-tied-bottom-line-ruler.png`. P02 is the other hollow head, and P05 is a filled beamed head near an unrelated barline. The three out-of-search genuine bodies remain explicit coverage gaps; they are not counted as successful native preservation tests.

F05 is **Brahms Symphony No.1, IMSLP317803, physical page28**, at the structural barline near x859. The helper accepts a supposed hollow body centered at **(864.0231,1345.1257)** with radii **(4.125,3.50625)**, angle -15.18 degrees, three attachment rows and 85.7% surrounding white. The source shows a tie meeting the barline immediately below a staff line; that tie and staff line enclose the light pocket. It is not a source notehead. `review/F05-structural-intersection-ruler.png` is untouched source content with coordinate rulers; `review/F05-candidate-false-hollow-overlay.png` marks only the proposed ellipse on a separate enlarged copy. Both were inspected against the source. Its adapter uses the frozen recorded actual core shift and the same physical barline, not a newly guessed musical spine.

The code's hollow-cavity flood uses original ink, so a cavity bounded partly by a staff line and partly by a tie can satisfy enclosure even though it is not a musical notehead. Its outline sampling excludes predicted staff pixels, but the reported source counterexample demonstrates that the combination of ellipse support, white enclosure, short apparent termination and direct ink rows is insufficient to establish musical ownership here. Conversely, rejecting every connected curve would also be wrong: P06 is a genuine filled head touched by a tie, retained as a fixed source obligation even though outside this helper's present search window.

**Verdict: reject v1 as reliable notehead ownership evidence.** Keep all original source obligations and classifications fixed. These are direct helper checks; the full native connector search/erasure path was not invoked by this independent probe. The seven ordinary own-stem notes may never enter that path, and no new output crop omission or page-quality regression is asserted here. The false acceptance blocks an evidence-quality claim without requiring a full39/full1477 run. Parent/implementation-agent native replay results are separate evidence, not silently incorporated into these helper counts.
