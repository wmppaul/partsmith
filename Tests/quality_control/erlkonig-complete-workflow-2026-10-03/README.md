# Complete Erlkönig assisted extraction and silent-part headings

The complete 11-page score now has both native Partsmith outputs: **Voice, 4 pages; Piano, 8 pages**. Each part accounts for 48 source systems and measures 1–148. Voice includes four confirmed three-bar silent opening systems and 44 printed systems; Piano has 48 grand-staff crops. The [complete draft and editable project](../../../output/pdf/auto-qc-2026-10-03/erlkonig-reviewed-draft/README.md) preserve the unchanged original source. The ZIP SHA-256 is `9082acd35197d3d71a2c403bf09bda403978d9edf9ec7fb6d8850f6530d8a40e`.

This is **manually initialized and corrected output**, not an Auto identity success. A [three-score source roster audit](../variable-profile-roster-audit-2026-10-03/README.md) confirms that the opening absent vocal staff makes a fixed staff cadence unsafe. The existing native staff inventory was reused; no fresh full staff-recognition run is claimed. Every system's identity and measure count was read from the source. The final count uses the original page-11 barlines, including its double final bar, to establish measures 145–148. Four manually read source directions were bound to the reviewed assignments by the production planner.

## Production improvement

Printed headings now bind to confirmed silent recipients as well as printed instruments. An inserted rest's source rectangle only identifies its source system; its pixels are never printed. Consequently, a heading inside that rectangle must still be copied. Both bounding-box and measured-ink containment shortcuts now respect this distinction.

Omission records preserve explicit source-copy lists and above/below positions. Remove Copy works for generated silence, reassignment clears tracked automatic copies, and manual choices stay separate. Reconfirming an unchanged printed system retains the silent recipient's reviewed removal. Horizontal anchor expansion allows a valid source copy outside the usual trim without clipping it at Add Parts. The [independent review](../generated-rest-heading-independent-2026-10-03/README.md) records the initially failing removal call and the final 47 passing checks, plus 70 unchanged local-ending controls.

The new [universal Mac build](../macos-build-2026-10-03-rest-headings.json) includes those changes and the prior Scale/Side Margins improvements. Native crop detection is unchanged. The build was verified and packaged without launching the user's running app.

## Source/output corrections

Independent review inspected all 11 original pages, all 48 paired source/output systems, and all 13 initial exported pages. It found an omitted opening metronome-note stem and a complete piano diminuendo below the original page-4/system-4 crop. The source-derived obligations were frozen before changing the export.

Exactly six edits were made: five main crop edges and one tempo-copy rectangle.

| Source item | Reviewed edit | Source obligation |
|---|---|---|
| Opening Schnell copy | `[121.6, 136.5, 220.1, 155.5]` pt | Includes the whole quarter-note stem and excludes piano beams below the source blank gap. |
| First Piano system | Top 136.5 pt | Removes a sliced work-number header while retaining the complete tempo and piano notation. |
| Page 4, system 4, Piano | Bottom 816.5 pt | Contains both diminuendo strokes through their measured stroke boundary at 814.960616 pt. |
| Page 2, system 3, Voice | Top 363.5 pt | One-point margin above original target ink at 364.5 pt. |
| Page 4, system 4, Voice | Top 657.5 pt | One-point margin above original target ink at 658.5 pt. |
| Page 6, system 2, Voice | Top 209.375 pt | One-point margin above original target ink at 210.375 pt. |

The voice obligations include printed bar numerals, complete clef/key tops, and upper note/stem/slur ink; lower and side edges are unchanged. Tiny foreign tips occupy the same vertical range, so tightening farther would not be safe. All 96 item identities and orderings, all assigned staves, all generated-rest counts, and all other crop/copy rectangles are unchanged.

The final native export has 12 pages: tightening the three oversized vocal crops reduces Voice from five pages to four. Six final pages change (all four Voice pages and Piano pages 1/4); the other six Piano pages are pixel-identical to the reviewed baseline. The independent reviewer inspected all changed pages and source guards; the root viewed all 12 final pages and all six changed strips. See the [independent source and export review](../erlkonig-independent-review-2026-10-03/README.md).

## Remaining quality limits

This is not a clean or performance-ready edition. The generated vocal introduction lacks its opening common-time indication and occupies four rest rows rather than one twelve-bar rest. All three final Voice turns interrupt phrases or pickups. Piano plays continuously across its turns. Several Piano crops retain cut vocal words, and smaller neighboring notes/lines remain in Voice. Corrected crop preservation does not certify missing shared-direction recall elsewhere.

## Validation and reproducibility

Current production passes 160 generated-rest workflow checks, 111 native planner checks, 139 whole-score document assertions, 47 independent heading/copy checks and 70 local-ending controls. The [permanent crop suite](../permanent-musical-preservation-2026-10-03/README.md) now passes 796 checks. The original 765 checks remain unchanged; 31 new checks bind the source/mask pixels and previously retained musical envelopes of two independently rejected cleanup rules. These counts cover named regressions, not overall corpus musical correctness.

The root verified the output ZIP's CRC and every member hash, both PDF page counts, the embedded source hash and every part's contiguous measure coverage. `workflow-evidence.zip` preserves source-map preparation, the six correction instructions, the final binding/export scripts, logs and exact current Core source hashes. The deliverable includes the profile, reviewed inventory, overrides, source map, corrections and native placement manifest. Saved input paths describe this workspace; reproduce in a fresh directory and keep the original baseline untouched.

The seven unresolved whole-neighbor Brahms Auto crops remain unresolved. The [row-width experiment](../row-width-independent-2026-10-03/README.md) and [long-barline fallback](../brahms-upper-continuation-2026-10-03/README.md) are rejected after independent source-preservation failures. Their apparent real-score cleanup does not justify excluding genuine musical strokes. The [remaining component audit](../brahms-residual-cause-audit-2026-10-03/README.md) explains the four causal components without promoting another geometry threshold. The broader Auto quality goal remains active.

A separate [detached-hairpin experiment](../erlkonig-detached-hairpin-2026-10-03/README.md) recovers this score's low diminuendo through additive source evidence, passes the current 796 crop checks and leaves 80 matched Brahms bands unchanged. It remains outside production: eight of eighteen positive shape cases are still missed, and footer lookalikes cause two unwanted expansions. The [independent challenge](../hairpin-independent-2026-10-03/README.md) also records three missed musical positives. The released app uses the unchanged detector; the delivered score uses the explicit reviewed correction above.
