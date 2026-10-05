# Default rest joining and grand staff output

348 focused checks passed against unchanged production sources. The exact Swift file hashes and test source hashes are included. These tests validate the document, layout, exported PDF and automatic-rest worker; they do not claim a live app mouse interaction test.

| Suite | Checks | Evidence |
| --- | ---: | --- |
| Default and mixed rest joining | 56 | `test.log`, `results.json` |
| Existing generated-rest joins | 35 | `generated-joins.log` |
| Manual replacements, layout and PDF | 44 | `multibar.log` |
| Document editing and Undo | 55 | `document.log` |
| Automatic-rest workflow | 158 | `auto-flow-native.log` |

The new mixed fixture starts with a five-bar printed piano grand staff and follows it with seven confirmed omitted-staff runs: 5, 6, 5, 4, 4, 5, 5. It produces one 39-bar rest while preserving all eight original source references and original document rows. `grand-staff-39-bars.pdf` and its PNG were exported through the production renderer and visually inspected: both staff groups have an H-bar and share one count above the upper staff. Pixel checks sample both sides of each center line so a thin staff line alone cannot satisfy the rest-symbol assertions.

Coverage includes default joining with unknown measure numbers, explicit separation, persistence, Undo/Redo, labels and copied directions, repeats/double-bar boundaries, unknown ending geometry, excluded source intervals, sounding music, skipped/repeated source systems, page gaps, conflicting later numbers, impossible inferred starting numbers, count limits and integer overflow. New printed contexts retain their own boundaries. Opening source context and source fragments survive a joined run.

Project-wide continuity tests check that another part's later source system, including an excluded row, prevents joining over the missing final system when crossing a page boundary. Worker tests allow an opening direction ending at x=.264, after the retained prefix at .241 but before the first rest at .298. They retain that copied direction verbatim, reject a later direction extending to .4, use the earliest rest even when bounds arrive unsorted, and fall back to the conservative prefix boundary when glyph positions are unknown.

Older tests now state explicit separation when testing separate rows. The round-trip fixtures also choose an explicit shared/individual layout so unrelated legacy-layout migration does not alter their expected model values.

The first sandboxed automatic-workflow attempt stopped at its required Core Image rectification check (`auto-flow.log`). The same compiled binary then passed all 158 checks with native graphics access; no source change or workaround replaced that check.

This synthetic fixture tests safe joining and grand staff rendering independently of musical image recognition. Actual Mozart recognition and source-score review are recorded separately; the PDF here is not an engraving-quality source score or a test of note transcription.
