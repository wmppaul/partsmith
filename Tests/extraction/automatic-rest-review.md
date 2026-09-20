# Automatic rest detection: independent evaluation

The goal is automatic identification and counting of complete rest-only source bands. The manual replacement feature is a fallback, not the acceptance criterion for this work.

## Ground truth

`automatic-rest-fixtures.json` records 17 independently inspected real-score bands: eight supported whole-band replacements and nine negative controls. These include two crop variants of the same four-bar passage. Expected counts were read from the source before the detector was run. Sources are bound by SHA-256; coordinates refer to the complete original PDF page, normalized top-down. Page and system indices in JSON are zero-based. The earlier visual audit and exact one-based locations remain in `rest-compression-review.md`.

Positive counts span the scanned Brahms Trio (six), scanned Schumann vocal postlude (eight), and digital Magic Flute Flute/Trumpet/Timpani staves (eight, four, and five). Negative controls include a late note after seven rests, an opening note before mostly empty measures, partial rests mixed with notes, a two-staff piano system, an internal meter change, a final fermata, and uncertain clipped neighboring ink. A detector must not replace these negative bands merely because it can count some resting bars.

`staffRanges` independently anchors the intended staff lines so a test cannot pass by silently analyzing a neighboring staff. `prefixLandmarks` cover actual source ink for Allegro and leading notation. `suffixLandmarks` cover final double bars. The harness checks that the detector's retained source rectangles include these landmarks, and that no counted rest is duplicated in the retained prefix.

The two Magic Flute page-3 flute crop variants were refined after inspecting the source at enlarged resolution:

- The four-rest band's original bottom of .080 includes the top of the next oboe's `a2`. The tight positive ends at .078, below the entire flute clef and above the oboe marking. The original wider band remains a positive only because that extra ink is retained in the source prefix; the additional prefix landmark enforces this.
- The five-rest band's original top of .508 clips the previous system's contrabass clef/stem. A second positive starts at .5121, below that unrelated ink and above the flute's bar-5 label/clef. The original broad band remains a negative: its extra ink lies above the first counted rest, outside the retained prefix.

These are source-derived crop distinctions, not changes to the true four/five bar counts. The inspection image `.build/rest-audit/magic-prefix-detail.png` shows the leading flute context and adjacent oboe marking.

## Counting is not sufficient for safe application

- Magic Flute's page-2 eight-rest lines end at a double bar. Preserve that marker and its boundary or decline automatic application.
- Magic Flute's page-3 four-rest line begins with Allegro, key, clef, and common-time context. Correctly returning four is insufficient if the replacement removes them.
- The Trio's six-rest example is internal, but the following source band includes the sounding entry at bar 51 and its `p`; it is an explicit negative control.
- The Trio meter-change band and Schumann final-fermata band have true rest counts, but a count-only replacement cannot represent all required notation. They remain negative controls unless the output representation explicitly preserves those details and the review is updated with that evidence.
- Copying a sounding note into the retained prefix does not make a rest count correct. The first measure must actually be silent, even when the note sits close to a clef or key signature.

## Adversarial cases

The independent synthetic tests include one clean three-rest baseline and fifteen negative cases: whole-note lookalikes, a half rest, a missing barline, repeat dots, fermata, first-measure sounding/whole/ledger notes before a full-rest-like symbol, and close note/signature combinations. They also verify immediate and mid-analysis cancellation and invalid crop rejection.

The initial seven intended positive counts and original negative controls passed after detector iteration. A subsequent safety extension exposed a false positive: a sounding note adjacent to a clef/key-like cluster was preserved as signature ink while the first measure was incorrectly counted as silent. This is a musical-counting error even though the note pixels survive. A stronger mutation of the real Magic Flute prefix exposed hollow-note variants whose top/bottom arcs vanished during staff-line removal, leaving disconnected side fragments. Both problems were corrected in the detector and retained as regression tests.

The completed independent run passes **182 checks with zero failures**: 17 real fixtures, 16 synthetic shapes, 47 real-prefix images, and nine padded ledger-note images. The real-prefix cases include an unchanged copy control, five staff-line/four staff-space positions with whole-note widths of 1.2/1.6/1.8 staff spaces, up/down stems at each pitch, and the originally failing off-grid hollow note. Every inserted sounding-note image is declined; the unmodified source still returns four.

Validated detector SHA-256: `666abb878c3492d660109827829fa3e25f2d4b12c143e0f5b5cdf43fd8722959`. Test-source SHA-256: `6dc9ec318961f97f5606b0dcbeaf49a3d594f7dd5af89dd71364c8ad3037a8dd`.

The additional ledger-note extension isolates and pads the actual four-rest source strip, preserving a successful unmodified control, then places notes at −2/−1.5 or +5.5/+6 staff spaces with both stem directions. It exposed four outward-stem notes that were incorrectly treated as text above/below the staff. The corrected detector now declines all eight sounding-note cases, while the unmodified padded source still returns four. These cases remain permanent regression tests.

## Actual Auto crop coverage

A production `NativeScorePageAnalyzer` → `ScoreExtractionPlanner` run with the default Compact crop mode and the source's 14-instrument staff order was probed on Magic Flute pages 2–3. Both pages produced applicable plans (14 and 28 physical staves).

- Page 2: automatically generated Flute, Trumpet, and Timpani bands all recognize the reviewed eight-rest runs.
- Page 3: the two automatically generated Flute bands are broader than the independently reviewed tight bands. Their ranges are .027829973–.088392889 and .505441913–.545580635. They include neighboring staff lines/ink, so the current detector conservatively leaves both original strips unchanged.
- Page 3: the automatically generated second-system Trumpet band recognizes five rests.

The probe log is `.build/rest-detection-tests/planner-probe.log`. The page-3 flute limitation is a coverage limitation of the current end-to-end Auto flow; tight-fixture success must not be presented as proof that unadjusted Auto compresses those same two bands.

## Full Magic Flute candidate audit

The complete 43-page source was run through the production native page analyzer, default Compact planner, and detector using the source's 14-instrument order. Every page produced an applicable plan: 644 source bands in total. The detector proposed 77 replacements containing 384 bars across the parts. All 77 corresponding source strips were independently inspected in eight contact sheets. Every proposed count agrees with the visible full-bar rests, and no candidate contains sounding notes or partial rests on its intended staff.

This is a review of the detected subset, not a recall claim for every rest run in the score. After the hollow-note and ledger-note corrections passed the independent regression suite, the complete 43-page probe was rebuilt and rerun. All 77 candidate identities, counts, crop rectangles, staff geometry, and suffix rectangles remain unchanged from the visually inspected set. Six prefix edges moved by one analysis pixel (candidates 002, 014, 031, 035, 056, 072); every changed sliver was checked and contains only staff-line pixels, with no clef, key, text, or note ink affected.

The source strips and machine-readable geometry/context are in `.build/rest-full-magic/report.json`, `candidate-001.png` through `candidate-077.png`, and `sheet-01.png` through `sheet-08.png`. Source-page renders are retained for pages with candidates. Candidate 039 includes the opening Allegro/clef/key/common-time context; candidates 001–003 include the Adagio-ending double bars. Those contexts must remain in actual exported replacements.

The complete independently reviewed candidate list is grouped below (source PDF page and system are one-based):

| Page | System | Bars per strip | Instruments |
| --- | --- | --- | --- |
| 2 | 1 | 8 | Flute, Trumpet, Timpani |
| 3 | 2 | 5 | Oboe, Clarinet, Bassoon, Horn, Trumpet, Bass Trombone, Cello, Contrabass |
| 4 | 1 | 5 | Flute, Oboe, Horn, Trumpet, Bass Trombone, Timpani, Contrabass |
| 5 | 1 | 5 | Oboe, Clarinet, Horn, Trumpet, Bass Trombone, Timpani |
| 10 | 2 | 5 | Bassoon, Horn, Trumpet, Bass Trombone, Cello, Contrabass |
| 11 | 1 | 5 | Horn, Trumpet, Bass Trombone, Timpani |
| 13 | 1 | 4 | Trumpet, Bass Trombone, Timpani |
| 15 | 1 | 4 | Oboe |
| 19 | 1 | 4 | Flute, Oboe, Bassoon, Bass Trombone, Contrabass |
| 20 | 1 | 5 | Flute, Oboe, Clarinet, Horn, Trumpet, Bass Trombone, Timpani |
| 21 | 1 | 4 | Clarinet, Horn, Trumpet, Timpani |
| 24 | 1 | 6 | Horn, Trumpet, Timpani |
| 25 | 1 | 5 | Trumpet, Bass Trombone, Timpani |
| 25 | 2 | 5 | Trumpet, Bass Trombone |
| 26 | 1 | 5 | Trumpet, Bass Trombone, Timpani |
| 27 | 1 | 5 | Clarinet, Horn, Trumpet, Bass Trombone, Timpani |
| 34 | 1 | 5 | Oboe, Horn, Trumpet, Bass Trombone, Timpani, Contrabass |
| 35 | 1 | 5 | Bass Trombone |

## Harness

Run `bash tools/test_rest_detection.sh` from the repository. It verifies source hashes, expected staff geometry, exact counts/refusals, retained context rectangles, and synthetic safety controls. It records real-fixture outcomes and timings at `.build/rest-detection-tests/results.json`, reports all failures, and exits unsuccessfully on any mismatch. A focused development run can use `--fixture=<fixture-id>`.

The detector and real candidate-source audit pass within the documented scope. An exported-output preservation claim additionally requires comparing the actual automatically generated PDF with the source. Full-score candidate review remains useful because a bounded fixture corpus cannot establish universal signature recognition.


## Native document and exported-output verification

The final document workflow passes 147 checks. Running the final detector through the actual worker on the complete reviewed medium-skewed Trio examines 393 strips and replaces 2: Clarinet bars 42–47 (six) and Cello bars 76–82 (seven). All 48 final release pages have identical drawing streams and 72dpi pixels to the independently reviewed automatic-rest run. The [delivered full set](../../output/pdf/automatic-rests/README.md) includes the editable project, source hash, recognition report and refreshed export audit. All 46 pages unaffected by those replacements match the earlier baseline drawing streams; all 24 Piano pages also match its pixels.

The complete Schumann project examines 154 strips and keeps all source notation; its 30 output page streams and pixels match the previously reviewed export. Its broad saved eight-rest crop includes neighboring fermata/stem/slur ink, so this refusal is intentional rather than an eight-bar counting failure.

Actual native deskew followed by fresh page-3 Auto and the real rest worker was exercised on Brahms. The broad proposal includes the printed page identifier and stays original. An independently reviewed top edge of .072 excludes only that identifier; the remaining complete clef, key, six rests and ending barline count as six through the real corrected-raster worker. The exported three-part page-3 excerpt was visually checked for retained context and the following clarinet entry. This corrected test is an explicitly scoped excerpt, not a claim that unadjusted whole-score deskew Auto compresses that passage. Its generated evidence is under `.build/automatic-rest-corrected-trio-release/review/`; the regression is in `tools/test_rest_auto_flow.swift`.
