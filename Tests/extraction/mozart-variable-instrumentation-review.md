# Mozart K. 488: varying instrumentation review

Source: `sample_scores/rest_detection/01_full_scores/mozart_piano_concerto_no23_kv488_mvt1_mutopia2229.pdf`, 36 pages, LilyPond digital edition. SHA-256: `b2e0feed0fc729fe0a755563cd1fc7137f2b0dc063f2b62cd59e96e7ec7b4d10`.

This is an independent source-layout and measure-count audit for assignment tests. It is not a completed extraction of all parts. Original notation remains the source of truth; generated rests represent explicitly confirmed silent omissions.

## Printed conventions

Only the first system prints the instrument names. The remaining systems do **not** repeat abbreviated labels. The initial score order is Flute; Clarinet in A; Bassoon; French Horn in A; Piano (two staves); Violin I; Violin II; Viola; Cello and Bass. This means nine part rows and ten staves when all are printed. Wind and string sections have connecting braces/brackets; the piano is a separate grand staff. The two violin staves have a brace too, so a brace alone does not identify piano.

The score hides silent instruments, including the piano immediately after the opening system. Clefs, key signatures, relative order, and musical continuity provide evidence for human review; the number of staves cannot safely determine which instruments disappeared. Two six-staff systems can be piano plus strings, or a different collection such as winds plus piano. Source measure labels occur above the first printed staff, which may be the piano rather than the flute.

## Verified representative mappings

The page and system numbers below are one-based. Staff numbers match the app's one-based staff badges. The machine-readable companion uses zero-based indices.

| Page / system | Measures | Staff badges | Printed parts in source order | Silent omitted parts |
|---|---:|---|---|---|
| 1 / 1 | 1–5 | 1–10 | All nine parts; Piano uses 5–6 | None |
| 1 / 2 | 6–10 | 11–18 | Flute, Clarinet, Bassoon, Horn, Violin I, Violin II, Viola, Cello and Bass | Piano: 5 bars |
| 8 / 1 | 66–71 | 1–10 | All nine parts; Piano uses 5–6 | None |
| 8 / 2 | 72–75 | 11–16 | Piano 11–12, Violin I 13, Violin II 14, Viola 15, Cello and Bass 16 | Four wind parts: 4 bars each |
| 8 / 3 | 76–79 | 17–22 | Piano 17–18, Violin I 19, Violin II 20, Viola 21, Cello and Bass 22 | Four wind parts: 4 bars each |
| 17 / 1 | 144–149 | 1–6 | Piano 1–2, Violin I 3, Violin II 4, Viola 5, Cello and Bass 6 | Four wind parts: 6 bars each |
| 17 / 2 | 150–152 | 7–8 | Piano only | All eight other parts: 3 bars each |
| 17 / 3 | 153–156 | 9–18 | All nine parts; Piano uses 13–14 | None |

Native staff detection independently agrees with the visual inventories: page 1 has 18 staves (10 + 8), page 8 has 22 (10 + 6 + 6), page 17 has 18 (6 + 2 + 10). Page 18 returns to two full ten-staff systems, beginning at measures 157 and 162; its opening confirms the preceding page ends at measure 156.

On page 17, the `SOLO` marking occurs at the piano's entry in measure 149. It is **not** a new tempo or an instruction that other parts start playing; the omitted winds remain silent through measures 144–152. `TUTTI` appears at measure 156, inside the full printed third system. Counted rests for the two earlier systems do not swallow this printed entrance. These observations validate this example; another score can require a shared tempo, meter, or rehearsal marking inside an omitted span, which must still be preserved at its original measure.

## Assignment workflow and safety

Use a scrollable Fit Width view with zoom, full-row staff hit targets, and shift-click range selection. Select one complete source system; check the instruments actually printed in profile order; give a starting measure if known; give a bar count whenever a part is omitted. Keep the checked instrument layout for reuse, but clear the previous bar count after assigning. Selecting or loading an existing system must show its own staves, choices, and counts.

The explicit variable-layout setting prevents a coincidentally divisible page count from enabling guessed assignments. A complete system accounts for every profile part exactly once: a printed staff group or a confirmed silent generated rest. Unassigned instruments and old omissions without counts remain unresolved. Non-music page exclusions are separate and do not generate rests.

A generated rest has dedicated provenance and never displays or restores another instrument's source crop. Its source geometry is only a system location for ordering and inspection. Moving source staves out of a previously mapped system marks that old system incomplete until reassigned. Existing labels, crop rectangles, shared markings, and page breaks survive edits to unrelated systems.

## Regression assets

- `Tests/extraction/mozart-variable-instrumentation-fixtures.json` stores the source hash, profile, staff groups, measure spans, and omitted identities for pages 1, 8, and 17.
- `bash tools/test_score_planner.sh --mozart` checks these three real pages in addition to synthetic assignment, preservation, error, and silent-rest tests.
- `.build/mozart-assignment-audit/page-01.png`, `page-08.png`, `page-17.png`, and `page-18.png` are the reviewed raster evidence.
- `.build/mozart-assignment-audit/analysis-17.json`, `page17-override.json`, and `page17-plan.json` record actual native detection and the reviewed page-17 plan: 27 items, consisting of 15 printed bands and 12 generated rest items, with every detected staff used once.
- `.build/Mozart Assignment UI.partsmithproject` embeds the original 36-page source and saves the nine-part setup with variable-layout mode enabled and no bands, for native UI initialization tests.
