# Independent K. 488 identity, timing and number-placement review

No instrument-identity or measure-count mismatch was found in the reviewed source-specific mapping. The latest bar-number code has no remaining actionable issue in this bounded review. This is **not** certification of all 603 cropped music regions or all 180 copied directions, and the instrument mapping was manually reviewed rather than automatically inferred.

The original 36-page PDF was independently rendered and visually inspected, including its opening instrument names, brace groups, clefs, key signatures, changing instrumentation and final system. Source SHA256: `b2e0feed0fc729fe0a755563cd1fc7137f2b0dc063f2b62cd59e96e7ec7b4d10`.

| Reviewed layout | Printed parts | Systems |
| --- | --- | ---: |
| A | All nine parts; Piano has two staves | 42 |
| O | Winds, horn and strings; Piano omitted | 19 |
| PS | Piano and four string parts | 8 |
| WP | Flute, clarinet, bassoon, horn and Piano | 6 |
| P | Piano alone | 3 |

The two six-staff layouts, PS and WP, were distinguished by their braces, clefs, keys and continuity—not by staff count alone. Piano clef changes retain the Piano identity. The source's combined “Cello and Bass” staff stays one part.

An independent script reads full-width staff lines, printed left-margin system numbers and vertical strokes from the original PDF. It does not use the parent's barline arrays or native staff candidates. All 78 source-system bar counts match the mapping; the final system starts at 311 and has four measures, ending at 314. The initial system starts at 1. Every successive span is contiguous.

The 99 generated-rest items count **omitted part/system passages**, not 99 individual measures: Piano has 19 omitted systems covering 88 measures; each of flute, clarinet, bassoon and horn has 11 covering 42; each string part has 9 covering 34. The directed plan has 603 printed music bands plus 99 generated rests, giving each of nine parts 78 sequential items covering 314 measures. These missing staves are interpreted as the source's suppressed silent parts, with source-reviewed identities and timing; absence alone is not a general automatic-rest rule.

`mapping-verification.json` binds the exact map, overrides and directed plan and records every system. The corresponding staged manifest contains 57 pages and 180 source-direction copies. Those counts were verified, but this review does not approve all copy content or complete output layout.

## Code review

Reviewed changes preserve optional system start/count fields on planned printed music and generated silence, retain starting measures when adding parts, and put ordinary measure labels outside music. Narrow margins reserve a separate number row. Existing unnumbered plans remain unnumbered. The source-marking validity contract keeps copied directions inside the band's horizontal span, so the ordinary left-margin position does not displace source notation.

The initial implementation permitted overlapping number **rectangles** for very short source crops at minimum system spacing; an actual glyph collision was not asserted. The independently reproduced three-row fixture has 5.16-point rendered music heights and 4-point spacing. The parent's final fix reserves a 16-point number row for rendered music below 12 points and clamps the margin label's vertical position. Recompiling that fixture against the final engine eliminates the overlaps. Initial and final logs and frozen model/layout snapshots are preserved.

Final reviewed layout-engine SHA256: `bcbb 339 fb 8 c 9 de 6 b 2 f 922 ef 751 c 15 ac 0 dba 075 ec 75 bcaf 9 f 6804 ea 2 a 2 f 5830 c 6`. `reviewed-code-hashes.json` binds the four changed production files and permanent test file; `reviewed-code.patch` captures the reviewed diff. No production file was edited by this reviewer. Parent-owned broader tests and full PDF layout review remain separate evidence.

`evidence.zip` contains original source renderings, independent checks, the source-bound map/overrides/plan, review snapshots and logs. `evidence-manifest.json` binds its entries; `report-hashes.json` binds every other report file.
