# Brahms Clarinet Trio — medium scan evaluation

This case uses `sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf`, SHA-256 `0f617f77acf2e257973b14a8ce558e88eca877835df6fff4894419e66c871e4b`. It is a different scan from the previously reviewed lightly skewed 114011 file. All source guards were established again from this file.

The source has 33 music pages, 131 systems and 524 physical staves. Page 34 is blank; page 35 is a publisher catalog. The reviewed setup is Clarinet in A / Cello / Piano, with 1 / 1 / 2 staves. Native detection found every staff without a manual detection correction. Four one-staff quartet parts would have the same staff count but the wrong grouping, so instrument setup must be explicit.

## Findings and changes

The live Auto flow stopped on the two nonmusic pages and hid the exclusion action inside assignment corrections. The app now exposes an explicit reasoned exclusion, moves to the next unresolved page, accepts typed source-page navigation and confirms new instrumentation setups. Rectification controls have distinct labels.

Fresh source review found 27 confirmed clipped marks in the original Compact result: seven Cello and twenty Piano slurs, articulation marks or text ascenders. The planner now recovers small detached high marks directly above connected target notes and uses a 1.5-staff-space/minimum-6pt upper safety margin. It does not follow detached-to-detached chains into another instrument. The lower margin and legacy fixed-padding mode are unchanged.

The revised Auto contains all 262 Clarinet/Cello source envelopes and all actual Piano target ink inspected by the reviewers. Two Piano envelopes still request less than 0.4pt more conservative whitespace; their original guards were retained and the final reviewed crops expanded locally. The seven precisely measured upper-mark regression cases now have more than 1pt clearance.

The finished outputs are deliberately distinguished from untouched Auto: 224 of 393 rectangles were explicitly reviewed corrections (222 context trims and two conservative guard expansions); 169 retain Auto geometry. No staff detections were replaced and no source pixels were masked. The source map records every decision. There are 261 copied source fragments: 127 printed bar numbers in each of Clarinet and Cello, plus seven shared Cello tempo directions. Movement starts have explicit page breaks. Native output is 12 Clarinet pages, 12 Cello pages and 24 Piano pages, with every part's 131 systems present.

Neighboring staff-line-center crossings dropped from 95 in the original Compact output to 4 in the final reviewed output; complete neighboring staves dropped from 2 to 0. This is an approximate context metric, not music recognition. Small slur, note, text and staff-end fragments remain where source ink shares the target's height. The original scan's small Clarinet/Cello staves remain approximately 4mm high on Letter paper; the Piano staves are approximately 5.8mm. This workflow crops and preserves engraving rather than re-engraving or reflowing individual measures.

## Reproduce

Run from the repository root on macOS with Xcode:

```sh
bash tools/score_extraction_batch.sh inventory --source sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf --out .build/trio-auto-current/inventory
bash tools/score_extraction_batch.sh plan --inventory .build/trio-auto-current/inventory/inventory.json --profile Tests/trio_medium/profile.json --overrides Tests/trio_medium/nonmusic-overrides.json --out .build/trio-auto-current/revised-plan.json
python3 Tests/trio_medium/check_auto.py .build/trio-auto-current/inventory/inventory.json .build/trio-auto-current/revised-plan.json
python3 Tests/trio_medium/assemble_review.py .build/trio-auto-current/inventory/inventory.json .build/trio-auto-current/revised-plan.json
bash tools/export_score_plan.sh --inventory .build/trio-auto-current/inventory/inventory.json --profile Tests/trio_medium/profile.json --overrides Tests/trio_medium/overrides.json --title 'Brahms Clarinet Trio Op. 114' --composer 'Johannes Brahms' --out output/pdf/brahms-trio-medium
python3 tools/review_score_output.py output/pdf/brahms-trio-medium --map Tests/trio_medium/source-map.json --pixels
python3 Tests/trio_medium/validate_project.py
```

The review tools require PyMuPDF, Pillow and NumPy (available in `.build/extraction-venv`). PDF generation uses the same native apply transaction, layout and exporter as Partsmith. The app itself needs no Python or internet connection.

Re-export changes output hashes and requires a new visual review. Source guards, structural tests and exact pixel comparisons do not replace that review. Final per-page visual records and artifact hashes accompany the delivered set.

Validation includes 149 native planner/corpus assertions over 84 corpus pages and 1,357 staves, 64 native document assertions, fresh medium-scan coverage/landmark checks, and editable-project consistency. Both architectures build in Release. The delivered project was opened successfully in the user's running Partsmith and its 12-page Clarinet preview checked; the existing running app was not replaced. Use the new preview app bundle for the improved Auto algorithm and controls.
