# Complete Mozart K.488 changing-instrument workflow

The complete 36-page first movement now has a source-reviewed assignment for all 78 systems and all nine printed parts. Its 702 output items comprise 603 source crops and 99 inserted rest passages. All parts cover measures 1–314. This is an assisted initialization of the existing native Partsmith planner/exporter, **not automatic instrument identification** and not a performance-ready certification.

Root inspected all36 original pages. The independent review in [k488-independent-review-2026-10-03](../k488-independent-review-2026-10-03/README.md) separately checked the five layouts, all printed system numbers and all source barline counts. It agreed with every system and every omission. PDF text and vector barlines supplied two separate timing checks; staff counts alone were never used to identify instruments.

Source: `sample_scores/rest_detection/01_full_scores/mozart_piano_concerto_no23_kv488_mvt1_mutopia2229.pdf`, SHA256 `b2e0feed0fc729fe0a755563cd1fc7137f2b0dc063f2b62cd59e96e7ec7b4d10`.

| Printed layout | Systems |
| --- | ---: |
| Full ensemble | 42 |
| Orchestra without Piano | 19 |
| Piano and strings | 8 |
| Winds and Piano | 6 |
| Piano alone | 3 |

The Piano receives 19 inserted passages totaling 88 measures; each wind receives 11 totaling 42; each string part receives 9 totaling 34. The combined Cello and Bass staff remains one printed part. Shared wind staves are retained as printed rather than separated into individual players.

## App correction found by this complete run

Starting measures entered in Assign System used to survive only on inserted rests. Printed music lost the value in planning/application. Reviewed start numbers and counts now survive the plan and materialized crop review; Add Parts saves the start on every corresponding music or silence item. A blank start remains blank. Existing automatic/legacy plans still have no inferred number.

Printed-music numbers now draw outside retained source pixels. Normal margins accommodate them without changing music geometry or pagination. Narrow margins reserve a 16-point row; exceptionally short crops also reserve that row so adjacent labels cannot overlap. Rest replacements retain their existing drawing behavior.

Validation:

- 142 generated-rest workflow checks, including actual Mozart page 17, nine-part export, optional blank starts, persistence/Undo, normal/narrow/zero margins and 20 short crops.
- 139 whole-score document checks.
- 5,389 layout assertions and 169 native crop/export checks.
- 288 scale/export checks pass with normal macOS graphics access. Restricted Core Image execution failed at the rectification fixture; the same compiled binary passed with graphics access. Source ink tests cover 0.8, 1, 1.25 and 1.4. Current 120-strip enlarged preview measured 0.689 s and cached spacing refresh 0.035 s in this run.
- All 702 full-score placements and all 53 original draft pages retain the same geometry after numbering. New shared-direction copies are a separate subsequent draft.
- Independent code/identity review found and then verified the short-row spacing correction. Separate export review is recorded in [k488-number-review-2026-10-03](../k488-number-review-2026-10-03/README.md).

No staff detector, crop ownership algorithm or rest recognizer is changed by this app correction.

## Complete draft output and remaining review

The subsequent draft includes 180 manually initialized source-image copy rectangles for 24 printed Allegro/SOLO/TUTTI directions. Its native PDFs total 57 pages: Flute 6, Clarinet 7, Bassoon 6, Horn 6, Piano 9, ViolinI 6, ViolinII 6, Viola 6, Cello/Bass 5. Every part has 78 ordered source-system items, and the project embeds the complete unchanged source PDF.

Root reviewed overview renderings of every output page. This checks broad layout/coverage, **not every target note at every crop edge**. Source assignments and bar counts have an independent complete review; 603 crops and 180 copied rectangles do not yet have a complete independent preservation review. The known remaining issues include:

- Conspicuous neighboring fragments on many crops; the first Flute crop includes a partial composer line, and the opening Cello/Bass continuation retains a Mutopia footer.
- A SOLO at bar 149 lies within the four winds' six-bar inserted rests beginning 144. Their durations are correct, but cue placement remains unfinished.
- Consecutive inserted rests remain separate source-system items. The Piano's long opening silence consequently occupies more space than a joined 60-bar rest would. No automatic merging is asserted.
- Musical page-turn review and full source-edge preservation review remain outstanding.

The 36-page geometry inventory is reused from the recorded production-native corpus run; there was no fresh OCR or full Auto staff-analysis run in this checkpoint. The source map and manual direction rectangles are separate review inputs. The app's native apply transaction, layout and exporter produced all outputs.

The notehead V 2 and auxiliary-label edge-completion experiments are separate, unpromoted studies. Neither is included in the app or these parts.

`provenance.json` binds inputs, binaries, test logs, source snapshots and output manifests. The reproduction inputs and small scripts are retained here; the native inventory and output metadata are compressed in `workflow-evidence.zip`. The PDFs and editable project are delivered separately with draft status intact.
