# Recipient-owned shared headings: independent source obligations

**Archived experiment; do not promote the heading feature.** The original 52 planner/review lifecycle controls pass, but a later independent source-box mutation control fails (52/53 overall). The strict whole-block matcher passes 10 safety fixtures and removes **0 of 3** actual duplicate headings. No heading implementation from this study was installed in Partsmith, and no output PDF was changed. Production and prior reports were read-only for this subtask.

The original source obligations and preimplementation fixtures below remain frozen. This is groundwork for removing demonstrably redundant automatic copies, with no new vocabulary, invented text, staff reassignment or crop cleanup. The useful real-source positives remain unsolved.

## Mozart K. 478, IMSLP86903

Source SHA256: `33ba263af431caa89d16530adcce3bf230b9c8b2e2367b737835c112fcfc99c8`. Both physical page1/system1 Allegro and page12/system1 Andante have the same recipient requirements:

| Recipient | Required final behavior | Original-source reason |
|---|---|---|
| Violin | No added copy | Its crop already retains the original top-staff heading. |
| Viola | Keep automatic copy | No equivalent heading appears above Viola's own staff. |
| Violoncello | Keep automatic copy | No equivalent heading appears above Cello. A lower Piano heading can occur incidentally inside the Cello crop; it is not Cello-owned evidence. |
| Piano | Remove only automatic duplicate | A complete equivalent heading is already printed above Piano's own upper staff at the same opening position and retained by the main crop. |

The expected total for these two events is four copies, replacing the present six. All476 main crops and existing global source rectangles must stay unchanged. These are source-reviewed musical expectations, not a requirement to weaken an inconclusive recognition gate until both positives pass.

`mozart-recipient-obligations.json` binds the current native source crops, first-staff identities, original images and separately frozen word envelopes. The envelopes use every nonwhite source pixel within manually selected whole-word contexts plus a one-render-pixel guard. They deliberately retain adjacent scan/staff ink; they are not proposed copy boxes or a license to erase it. The p1 local Allegro has a descending g very close to the upper staff line. A scan ending at the mean staff line minus0.3 staff spaces can truncate it. The original global OCR text is `, Allegro.`, while the local printed word is visibly larger: literal text or raster equality may safely miss this positive, but indiscriminate punctuation normalization or ignoring nonmatching pixels can create an unsafe false match.

Both current full output sets and the six present copy rows were reviewed in `../ownership-mozart-output-2026-10-03/`. The new source contexts here were independently rendered from the original PDF and viewed before candidate inspection. Current same-category copying is already suppressed when the original global source ink itself lies in the main crop; the new behavior must prove a separate local equivalent.

## Schumann negative and positive source controls

For Quintet IMSLP06822 (source SHA256 `b8b9f6431438a6bd4c9593fffb46278418fbb211b7d81b6953d920faf8cf744e`):

- Page19/system3 Agitato has a complete separately printed Piano Agitato at the same musical position. Piano is a true positive for removing the automatic duplicate; ViolinII, Viola and Cello still require their copies.
- Page2/system1's shared Allegro brillante includes the metronome108. Piano's local Allegro brillante omits the metronome. Its full shared copy must remain, even if OCR normalizes both strings to the same words.
- Page26/system1's shared block contains SCHERZO, Molto vivace and the dotted-quarter metronome138. Piano has only Molto vivace. Keep the complete shared block for Piano and the lower strings; the neighboring Piano words inside the Cello crop cannot replace it. This control is current after the heading-block fix; older reports documenting the former incomplete copy are historical evidence, not the current candidate state.

All three original contexts were rendered and viewed here. The prior complete-heading source obligations remain unchanged in `../heading-block-independent/` and `../schumann-native-output-independent/`.

For Frauenliebe IMSLP270922 (source SHA256 `d13fc3f4299dda634845b218222add8884ab9fd5257a9abb7cb2f9bcad4b9975`), current native recognition supplies three top-staff headings: Larghetto p1/system1, Adagio p6/system2 and Adagio p15/system1. None has an equivalent local Piano heading. Page6 Piano says ritard. at the relevant position. All three required Piano copies must remain.

The separate `../schumann-tempo-recipient-study/` is an archived, unpromoted German/interstaff experiment. Its three Voice duplicates—Lebhafter p12/system1, Adagio p12/system5 and Langsamer p14/system4—are words appearing below Voice and above Piano. I inspected these three original source contexts. They must not be used as evidence of an own-above-Voice heading. Piano's Lebhafter is also partially cut by the existing crop; recognizing the word does not prove complete glyph retention. The old study's source envelopes, failed initial-override audit and omitted song indices remain historical limitations, not new successes of this change.

## Required independent controls

The independent controls were frozen before implementation. They cover the following intended planner/review and matcher requirements; the results and untested integration limits are distinguished below:

1. Complete own local counterpart at the same system and horizontal musical position removes only the intended automatic heading; original crops and source rectangles remain exact.
2. Matching text at another x position, another system/page, another instrument, below the target, or above a Piano interior staff cannot suppress a required copy. Duplicate/ambiguous local detections fail conservatively.
3. A partial word, cut capital serif, descending letter, punctuation dot, faint original pixel, extra title row, musical note/dot, metronome number or a differing metronome value keeps the complete shared copy. OCR equality alone is insufficient. A matching word inside a larger source block cannot justify dropping unexplained source ink.
4. A joined heading block must be measured and matched as a whole. Coalescing separate fragments must discard stale partial counterpart evidence. Replanning and repeated Auto must be deterministic/idempotent for the same evidence.
5. Missing/invalid local bounds, nonfinite or empty staff lines, malformed source ownership, changed source/recipient assignments or music-to-cue changes must not produce wrong suppression or a crash. Initial overrides must be validated before capture, not accepted as retroactive recognition provenance.
6. Crop changes that remove part of a previously complete local heading restore a still-valid global copy. Test this through actual `ScoreSystemAssignment.pageOverride` and review APIs, because those materialize empty marking lists. A synthetic nil-list-only test misses the existing UI path.
7. An intentional Remove Copy remains removed. Explicit initial empty/nonempty marking lists remain authoritative. Removing an unrelated direction must not turn a later automatic restoration into an untracked stale copy. Source reassignment must invalidate automatic evidence without deleting explicit user copies or coincident navigation/ending copies.
8. Legacy inventories decode unchanged; optional counterpart fields roundtrip. Cancellation before OCR, during recipient work, and during planner filtering returns no partial committed suppression and leaves existing project/review state usable.

The current code's ending-counterpart model illustrates useful separation: global recognition stays independent from recipient-local proof; current assignments and whole local source containment are revalidated; explicit list/removal semantics have dedicated markers. Headings require their own lifecycle markers if using the same materialized review-list mechanism. Equal words or a generic same-page match are not sufficient provenance.

## Results and decision

| Evidence | Result | Meaning |
|---|---|---|
| Constructed planner/review lifecycle controls | 52/52 pass | Own-first-staff ownership, crop restoration, explicit removal, optional codecs, coalescing, category collisions, deterministic replanning and planner cancellation work for the constructed metadata. |
| Additional frozen global-box mutation | **Fails**; 52/53 overall | Existing local proof can suppress an enlarged global block that it never matched. This is a blocker independent of the matcher misses. |
| Independently frozen whole-block image fixtures | 10/10 pass | Identical blocks match; missing text, punctuation, metronome material, title material, staff fragments, a small tip and a faint original pixel do not. |
| Native original-source duplicate probes | **0/3 useful positives** | Mozart p1/p12 and Schumann p19 keep their automatic copies. Safe misses are not successful deduplication. |

The later mutation changes the global heading's right bounds and measured ink bounds from 0.32/0.319 to 0.39/0.385, representing an additional unrecognized symbol. It retains the same text, staff assignment and old local proof. `global-mutation-preexecution-hashes.json` freezes the test and unchanged candidate before execution. `global-mutation-results.json` records the one failure. The parent recognition binding covers staff ownership, not the precise global bounds/ink/text payload. Coalescing clears proof, but a direct metadata change does not. Any future implementation must bind each local match to the exact global source payload and invalidate it when that payload changes; this archive deliberately does not speculate a repair.

The root's matcher compares the entire grayscale block after removing white exterior padding and integer translation. Text normalization changes only whitespace and case. It does not scale, threshold away scan noise, discard fragments, forgive punctuation or special-case metronome symbols. The 10 fixture results in `matcher-results.json` therefore demonstrate narrowly defined safety controls, not general visual equivalence or broad musical recall.

For the real probes:

- Mozart p1: the local padded box exceeds the probe region and the OCR strings differ (`, Allegro.` versus `Allegro.`). No whole local block is fabricated. The pair record intentionally references an unproduced `p1-piano-whole-block.png`; the actual `p1-piano-region.png` is archived. Its descending letter reaches the staff line.
- Mozart p12: text matches, but complete nonwhite block dimensions are 118×37 versus 152×40. The global block includes a small bottom line/curve.
- Schumann p19: text matches, but complete nonwhite block dimensions are 107×36 versus 131×38. A small cut-off notation tip remains at the global block's bottom right.

I directly viewed all three exact global block PNGs, the two complete local block PNGs, and the p1 local region after the original full source contexts. The global p1 staff line, p12 bottom fragment and p19 tip are retained, not masked or reclassified by matching words. Font/scan differences and unexplained extra pixels remain reasons for conservative rejection. These observations agree with the root's source probe; they do not establish an improved output.

## Scratch implementation and remaining limits

`scratch-integration.patch` contains three scratch-only files against the frozen root baseline in `evidence.zip`, not against a subsequently modified working tree:

- `ScoreExtractionPlanner.swift`: optional local-counterpart data and normalized automatic-heading provenance; assignment/first-staff/text/location/containment checks; separate local-copy suppression and restoration. Joined blocks clear local proof.
- `ScoreSharedDirectionReview.swift`: explicit Remove Copy and stale assignment cleanup preserve provenance and coincident other-category copies.
- `PartsmithDocument.swift`: crop editing obtains its override through the existing shared override helper, retaining automatic markers and omitted-staff state.

No native local-heading detector, score-level phase, cancellation UI or app wiring was implemented. The 52 lifecycle tests use constructed local metadata; they do not prove native detection or cancellation of a new OCR phase. The standalone strict matcher has no cancellation parameter. Its runtime and memory were not benchmarked for full documents. Current whole-heading copies, duplicate tempo words and neighboring notation remain unchanged.

The document helper routing also exposed an existing local-ending provenance defect in the actual crop-edit API. The parent independently assigned and reviewed a separate document-only fix, outside this heading experiment. See `../crop-edit-ending-provenance-2026-10-03/` for that evidence and production decision. The heading model/planner/review patch remains unpromoted regardless of that narrower fix.

The original frozen `independent-controls.swift` is preserved verbatim. `controls-final.swift` contains two harness corrections: throwing codec operations were moved outside a nonthrowing assertion autoclosure, and a manually materialized marking's parallel side-flag list was updated along with its marking list. The malformed earlier fixture was rejected by the planner; its later force-unwrapped test lookup caused a test-process failure, not a reproduced implementation crash. Diagnostic compile/test logs are archived separately; no private operating-system crash report is included. The final 52 requirements were retained. The new global-box control was added afterward, frozen before its run, and its failure remains visible.

## Durable evidence and reproduction

`source-bindings.json` binds all original PDFs, both 23-file Core snapshots, the three changed files and excluded native binaries. `evidence.zip` contains 104 source/evidence files plus its own manifest: both frozen Core copies, the root's native probe and exact matcher, OCR observations, original block/region PNGs, harnesses and logs. It excludes binaries and source PDFs already in the corpus. `archive-manifest.json` lists every archived file's SHA256; every entry and ZIP integrity were verified after creation. `report-hashes.json` binds this complete report except itself.

`source-freeze-hashes.json`, the preimplementation control hash and matcher-fixture hashes remain unchanged. The copied native pair records retain their original scratch paths for provenance; use the corresponding `root-probe/` archive paths when replaying outside that scratch directory. The deliberately absent clipped p1 whole-block image is explained above and in `source-bindings.json`.

From the repository root, `bash Tests/quality_control/heading-local-ownership-2026-10-03/replay.sh` rebuilds the archived lifecycle and matcher controls in a separate scratch folder. It expects the original 52 checks to pass, the 53-check suite to report exactly the known mutation failure, and all 10 matcher fixtures to pass. This replays existing image/metadata evidence; it does not rerun Vision or claim a newly improved score output.
