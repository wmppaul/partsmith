# Remaining corpus instrument initialization

These 16 source-hash-bound additions cover the remaining unprofiled files in the 36-source corpus. They establish source roles and known layout changes, **not a crop/export quality pass**. The main corpus registry was not edited.

The machine-readable registry is `profile-additions-2.json`. Each record binds the exact source and profile SHA-256 and gives one-based physical PDF pages reviewed. Verify both hashes before merging or applying a profile. Raw profile JSON does not itself enforce the binding.

Two profiles support a fixed repeating staff roster within their stated scope: the two-page Beethoven excerpt and the Magic Flute overture. The other 14 explicitly require system assignment. La Bohème initializes only the verified opening roles, not the complete cast.

| Source | Initialization scope | Nominal staves | Full-size source pages reviewed |
|---|---|---:|---|
| Beethoven Symphony No. 5, opening two-page excerpt | fixed roster established for excerpt only | 12 | 1, 2 |
| Brahms Symphony No. 1, IMSLP 317803 | complete named group union variable layout | 16 | 1, 28, 37, 46 |
| Schumann Concertpiece for four horns, IMSLP 291222 | initial staff group roster with variable divisi | 19 | 1, 31, 36, 37, 41 |
| Puccini La Bohème, IMSLP 885132 vocal/piano score | initial roster only full cast not established | 4 | 1, 2, 3, 4, 83, 167, 223 |
| Brahms Two Motets op. 74, IMSLP 101579 | initial staff group roster with variable divisi | 6 | 2, 6, 11, 12, 18 |
| Mendelssohn Hear My Prayer, IMSLP 40163 | complete named group union variable layout | 7 | 1, 2, 3, 6, 10 |
| Brahms Gesang der Parzen, IMSLP 109040 | initial staff group roster with variable divisi | 20 | 2, 4, 27 |
| Schumann Concertpiece for four horns, IMSLP 51506 | initial staff group roster with variable divisi | 19 | 3, 33, 38, 39, 43 |
| Brahms Two Motets op. 74, IMSLP 101580 | initial staff group roster with variable divisi | 6 | 2, 6, 11, 12 |
| Brahms Gesang der Parzen, IMSLP 109041 | initial staff group roster with variable divisi | 20 | 2, 4, 27 |
| Beethoven Egmont Overture, normal digital score | complete named groups fixed positions with doubling | 14 | 1, 6, 36, 37, 38, 47, 50 |
| Mozart Magic Flute Overture KV620, normal digital score | fixed named staff roster supported at all section boundaries | 14 | 1, 3, 18, 19, 25, 43 |
| Mozart Symphony No. 18 KV130, normal digital score | complete named groups fixed positions with crook changes | 7 | 1, 16, 22, 23, 24, 37 |
| Mendelssohn Verleih uns Frieden, CPDL63797 organ arrangement | complete named group union variable layout | 7 | 1, 2, 3, 4, 5, 6 |
| Beethoven Symphony No. 5 complete, IMSLP52624 | complete named group union variable movements | 17 | 1, 7, 26, 41, 56, 104, 105, 106 |
| Beethoven Symphony No. 5 movement II, Mutopia1437 | complete named group union variable layout | 12 | 1, 2, 7, 35 |

## Interpretation limits

- Shared instrumental staves stay grouped. A wind pair, cello/bass shared line, or trombone/tuba shared line is not an independently extracted individual-player part.
- A section such as Alto I–II may use one combined staff or two divided staves. Its profile count initializes the opening only; explicit candidate grouping is needed later. The current selection helper assumes a constant count per part, so divisi requires a more capable editor or direct reviewed band overrides.
- Hidden staves are not sufficient evidence of a rest duration. No measure spans or generated rests were added.
- Thumbnail browsing locates movement boundaries and suspicious changes; only listed full-size pages establish the reported source evidence. No full rendered part output was reviewed in this task.

## Beethoven Symphony No. 5, opening two-page excerpt

Source: `Tests/extraction/sources/beethoven-op67-pages-7-8.pdf`. Profile: `Tests/quality_control/profiles/excerpt-beethoven-op67-pages-7-8.json`.

Scope: lossless excerpt only. Requires explicit system assignment: **no**.

- Both excerpt pages are visually checked: one complete 12-staff system on page 1 and two 12-staff systems on page 2. Printed opening names, wind-pair numbers and clefs establish the order.
- This is source PDF 52624 pages 7–8 only. The later piccolo, contrabassoon and trombones in the complete symphony are outside this excerpt; this profile must not be applied to that entire source.

## Brahms Symphony No. 1, IMSLP 317803

Source: `sample_scores/lightly_skewed/03_brahms_symphony_no1_op68_imslp_317803.pdf`. Profile: `Tests/quality_control/profiles/lightly-skewed-03-brahms-symphony-no1-op68-imslp-317803.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Opening printed roster has 14 physical staves: paired flutes, oboes, clarinets, bassoons; contrabassoon; two horn pairs; trumpets; timpani; five string staves. The profile is the union of these roles plus the two trombone staves printed at the finale opening (page 46).
- Page 28 opens Andante sostenuto with 13 staves, then a reduced 10-staff system. Page 37 opens Un poco Allegretto e grazioso with 12 staves and then 11. Page 46 opens the finale Adagio with 16, including an alto/tenor trombone staff and bass trombone staff.
- All 86 page thumbnails were browsed to locate boundaries; only the listed pages received full-size roster review. Clarinet/horn crooks change; part names preserve player identity without imposing an opening transposition on later music.

## Schumann Concertpiece for four horns, IMSLP 291222

Source: `sample_scores/lightly_skewed/04_schumann_concertpiece_4_horns_op86_imslp_291222.pdf`. Profile: `Tests/quality_control/profiles/lightly-skewed-04-schumann-concertpiece-4-horns-op86-imslp-291222.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Opening has 19 physical staves. The separate orchestral horn staff is ad libitum; the four individually printed solo horn staves follow Viola and precede Violoncello. These must not be conflated.
- Romanze begins on page 31 and Sehr lebhaft on page 41. Pages 36–37 have a real extra cello staff: I. Violoncell. and II. Violoncell. are printed on page 36 above separate staves. The 20-staff count is not a detection error.
- Profile keeps one Violoncello section role with an initial count of one. It requires explicit variable-size band grouping on divisi systems; the fixed-count selection helper cannot yet express this directly.

## Puccini La Bohème, IMSLP 885132 vocal/piano score

Source: `sample_scores/lightly_skewed/06_puccini_la_boheme_sc67_imslp_885132.pdf`. Profile: `Tests/quality_control/profiles/lightly-skewed-06-puccini-la-boheme-sc67-imslp-885132.json`.

Scope: complete vocal score. Requires explicit system assignment: **yes**.

- This file is a vocal/piano reduction. The first page has three piano-only grand-staff systems. Marcello first appears on page 2; page 4 prints Rodolfo above Marcello, then Rodolfo alone. Profile initializes only these two verified opening roles plus Piano.
- Act openings are pages 1, 83, 167 and 223. Act II page 83 includes crowd/vendor groups Bassi, Soprani, Tenori and Monelli in a system above piano. This changing cast and order cannot use a fixed voice/piano stride.
- Full cast/chorus role inventory is not established; these three profile entries are explicitly incomplete for the opera. No silent intervals may be inferred from a missing named voice.
- Page 167 (Act III opening) visibly contains three piano grand-staff systems, six real staves. Raw candidate1 inventory detects only three. This unresolved recall issue is separately recorded.

## Brahms Two Motets op. 74, IMSLP 101579

Source: `sample_scores/lightly_skewed/07_brahms_2_motets_op74_imslp_101579.pdf`. Profile: `Tests/quality_control/profiles/lightly-skewed-07-brahms-2-motets-op74-imslp-101579.json`.

Scope: complete two motet collection. Requires explicit system assignment: **yes**.

- Opening printed voices are Soprano, Alto, Tenor, Bass with a two-staff piano reduction. The footnote says the piano is only an aid for rehearsal, not a performed accompaniment.
- Page 6 expands to Soprano I/II, Alto, Tenor, Bass I/II plus two piano staves (eight physical staves). Page 11 returns from that layout to SATB plus piano for the Choral; page 12 starts the second motet in SATB plus piano. Page 18 closes with that six-staff layout.
- One Soprano section and one Bass section initialize the combined opening staves; separate I/II passages require explicit variable-size group mappings. Individual singers cannot be separated from a shared printed staff by cropping.

## Mendelssohn Hear My Prayer, IMSLP 40163

Source: `sample_scores/lightly_skewed/08_mendelssohn_hear_my_prayer_woo15_imslp_40163.pdf`. Profile: `Tests/quality_control/profiles/lightly-skewed-08-mendelssohn-hear-my-prayer-woo15-imslp-40163.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Title names solo soprano, choir and organ. Page 1 has four solo-soprano-plus-organ systems, three staves each; the organ brace contains two staves.
- Page 2 starts with solo plus organ but its last system introduces the full seven-staff roster: Solo soprano, Chorus soprano, Alto, Tenor, Bass, Organ (two). Solo and chorus soprano are separate parts.
- Page 6 mixes reduced solo systems and full choir systems; page 10 retains the full roster through the ending. Absent choir staves need source-derived, reviewed measure spans before rests can be generated.

## Brahms Gesang der Parzen, IMSLP 109040

Source: `sample_scores/lightly_skewed/09_brahms_gesang_der_parzen_op89_imslp_109040.pdf`. Profile: `Tests/quality_control/profiles/lightly-skewed-09-brahms-gesang-der-parzen-op89-imslp-109040.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Opening page 2 has 20 physical staves. Altos I–II share one staff and Basses I–II share one staff; page 4 separates both groups, producing 22 physical staves, retained at the ending on page 27.
- The lowest trombone and bass tuba share one printed staff; the upper two trombones share another. The flute staff includes piccolo doubling, explicitly visible near the ending.
- Profile preserves the combined opening voice sections and shared instrumental staves. It cannot produce independent player or individual choral-division parts from those shared staves. Divided voice systems need explicit variable-size band grouping.

## Schumann Concertpiece for four horns, IMSLP 51506

Source: `sample_scores/medium_skewed/04_schumann_concertpiece_4_horns_op86_imslp_51506.pdf`. Profile: `Tests/quality_control/profiles/medium-skewed-04-schumann-concertpiece-4-horns-op86-imslp-51506.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Independently inspected opening page 3 has the same 19-role order as IMSLP 291222: a separate ad-libitum orchestral horn staff and four solo horn staves between Viola and Violoncello.
- Romanze starts on PDF page 33 and Sehr lebhaft on page 43. Pages 38–39 have 20 real staves: page 38 prints I. Violoncell. and II. Violoncell. on two separate staves above Double bass.
- This is a separate source edition/scan and remains separately hash-bound. One initial cello-section staff is not a fixed count for the full work.

## Brahms Two Motets op. 74, IMSLP 101580

Source: `sample_scores/medium_skewed/07_brahms_2_motets_op74_imslp_101580.pdf`. Profile: `Tests/quality_control/profiles/medium-skewed-07-brahms-2-motets-op74-imslp-101580.json`.

Scope: complete two motet collection. Requires explicit system assignment: **yes**.

- Independently inspected opening page 2 is SATB plus a two-staff rehearsal piano reduction. Page 6 expands to SSATBB plus piano; page 11 returns to SATB plus piano in the Choral; page 12 starts the second motet.
- Initial Soprano and Bass section roles each cover a combined staff and must expand to two candidate staves in divided passages. Fixed modulo-six assignment would misidentify the music.
- The piano is labelled as rehearsal assistance. This source is independently hash-bound even where page layout matches IMSLP 101579.

## Brahms Gesang der Parzen, IMSLP 109041

Source: `sample_scores/medium_skewed/08_brahms_gesang_der_parzen_op89_imslp_109041.pdf`. Profile: `Tests/quality_control/profiles/medium-skewed-08-brahms-gesang-der-parzen-op89-imslp-109041.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Independently inspected page 2 has the 20-staff combined-voice opening. Page 4 divides both Alto and Bass sections into two staves each, yielding 22; the ending on page 27 remains divided.
- Trombone III and bass tuba share a staff; upper trombones share another. Flutes include piccolo doubling. Shared printed staves remain grouped in initialization.
- This is a separate source hash, not a generated distortion of IMSLP 109040. Initial staff counts do not establish full-source assignment.

## Beethoven Egmont Overture, normal digital score

Source: `sample_scores/normal/02_orchestra/beethoven_egmont_overture_op84_score.pdf`. Profile: `Tests/quality_control/profiles/normal-beethoven-egmont-overture-op84-score.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Opening establishes 14 physical staves: separate Flutes I and II; paired oboes, clarinets and bassoons; two horn pairs; trumpets; timpani; five string staves. The horn pairs open in F and E-flat.
- Flauto piccolo is printed above the second flute staff on pages 36 and 38. This is a doubling/instrument change on that staff, not an extra staff. Manual system confirmation remains enabled for this change.
- Boundary pages 6 (Allegro), 37 (Allegro con brio), and ending page 50 retain the 14 physical positions. Page 47 has 14 real staves, while candidate1 detects 15 due to high ledger lines above Violin I. That false positive needs separate detector review.

## Mozart Magic Flute Overture KV620, normal digital score

Source: `sample_scores/normal/02_orchestra/mozart_magic_flute_overture_kv620_score.pdf`. Profile: `Tests/quality_control/profiles/normal-mozart-magic-flute-overture-kv620-score.json`.

Scope: complete work. Requires explicit system assignment: **no**.

- Four labelled section openings (Adagio page 1, Allegro page 3, Adagio page 18, Allegro page 19) retain the same 14-staff roster/order. Page 25 shows two complete systems with repeated abbreviations and page 43 the complete final system.
- Wind pairs share staves. Alto and tenor trombones share one staff; bass trombone has its own. These groups are retained rather than claiming separate individual-player extraction.
- Native inventory counts of 14 or 28 agree with sampled one/two-system layouts, but count divisibility is only supporting evidence and does not constitute crop/output verification.

## Mozart Symphony No. 18 KV130, normal digital score

Source: `sample_scores/normal/02_orchestra/mozart_symphony_no18_kv130_score.pdf`. Profile: `Tests/quality_control/profiles/normal-mozart-symphony-no18-kv130-score.json`.

Scope: complete work. Requires explicit system assignment: **yes**.

- Seven physical groups: paired flutes, upper horn pair, lower horn pair, Violin I, Violin II, Viola, combined Violoncello/Double bass. The last shared staff cannot be cropped into separate cello and bass players.
- Page 16 starts Andantino grazioso in its lower system and changes horn crooks from opening C alto/F to F/B-flat. Page 22 Menuetto returns to C alto/F; page 23 Trio and page 24 Allegro molto retain seven physical groups. Page 37 ends with all seven.
- Part names identify upper/lower horn pairs across changes; source notation is preserved without transposition. System confirmation is conservatively enabled for movement/instrument changes although sampled physical positions remain constant.

## Mendelssohn Verleih uns Frieden, CPDL63797 organ arrangement

Source: `sample_scores/normal/04_choir/mendelssohn_verleih_uns_frieden_gnadiglich_cpdl63797_full_score.pdf`. Profile: `Tests/quality_control/profiles/normal-mendelssohn-verleih-uns-frieden-gnadiglich-cpdl63797-full-score.json`.

Scope: complete arrangement. Requires explicit system assignment: **yes**.

- This is Benjamin Righetti’s choir-and-organ transcription, as printed on the title; the file name full_score does not mean orchestral score. The organ is three staves: two manual staves within a brace plus a pedal staff.
- Page 1 has SATB plus three-staff organ. Page 2 starts with organ alone, then Bass plus organ. Page 3 is Alto/Bass plus organ. Page 4 changes from that five-staff layout to full SATB plus organ; pages 5–6 retain the full seven-staff layout.
- All six source pages were visually inspected for roster and grouping. This establishes named groups and layout changes, not successful output crops or counted silent intervals.

## Beethoven Symphony No. 5 complete, IMSLP52624

Source: `sample_scores/rest_detection/01_full_scores/beethoven_symphony_no5_op67_complete_imslp52624.pdf`. Profile: `Tests/quality_control/profiles/rest-detection-beethoven-symphony-no5-op67-complete-imslp52624.json`.

Scope: complete work with front and back matter. Requires explicit system assignment: **yes**.

- The actual score starts on physical PDF page 7. The opening three movements use 12 physical staves. Movement starts are pages 7, 26 (Andante con moto), 41 (Allegro scherzo), and 56 (Allegro finale).
- The finale opening page 56 adds separate piccolo, contrabassoon, alto trombone, tenor trombone and bass trombone, producing 17 physical staves. The profile is the union in finale printed order; earlier systems require explicit omissions/assignment and reviewed measure spans.
- Clarinet and horn crooks differ between movements. Generic player/group identities are retained rather than applying opening key names to the finale.
- Music ends on page 104. Pages 1–6 are front matter and 105–106 back matter; all-page top thumbnails were inspected, and pages 1, 105 and 106 inspected in full. The ornate page 1 and prose page 106 contain no staves, despite raw candidate1 counts of 7 and 5. These are existing nonmusic false positives, not musical examples.

## Beethoven Symphony No. 5 movement II, Mutopia1437

Source: `sample_scores/rest_detection/01_full_scores/beethoven_symphony_no5_op67_mvt2_mutopia1437.pdf`. Profile: `Tests/quality_control/profiles/rest-detection-beethoven-symphony-no5-op67-mvt2-mutopia1437.json`.

Scope: standalone second movement only. Requires explicit system assignment: **yes**.

- Opening has 12 physical groups matching movement II. Page 2 abbreviations Vi1, Vi2, Va, Vc, Cb verify the five string identities omitted from the opening left margin. Wind/brass/percussion names are printed at the opening and in abbreviations at the ending.
- Page 2 hides horns, trumpets and timpani, leaving nine staves. Page 7 has seven staves in its upper system (bassoons, horns, five strings) and six in the lower (clarinets, five strings). Page 35 returns to all 12.
- This file covers only the second movement, not the full symphony. Missing staves require source-derived measure counts; no silent duration is encoded by this initialization profile.

## Separate unresolved detector findings

These findings were recorded against the raw candidate1 inventories; no detector change or compensating count assumption was made in this task.

- `lightly-skewed-06-puccini-la-boheme-sc67-imslp-885132`, PDF page 167: 6 source staves, 3 detected. Three piano-only grand-staff systems visible at Act III opening. Source pages are not altered.
- `normal-beethoven-egmont-overture-op84-score`, PDF page 47: 14 source staves, 15 detected. High ledger lines above the true Violin I staff create a candidate. Profile does not delete it or reinterpret it as a real instrument.
- `rest-detection-beethoven-symphony-no5-op67-complete-imslp52624`, PDF page 1: 0 source staves, 7 detected. Ornate cover, no music staves.
- `rest-detection-beethoven-symphony-no5-op67-complete-imslp52624`, PDF page 106: 0 source staves, 5 detected. Publisher prose, no music staves.

## Native validation

All 16 profiles decoded in the frozen release native batch CLI against their exact source-hash-bound candidate1 inventories (899 pages). Both fixed-scope profiles produced plans: 36 bands for the Beethoven excerpt and 644 for Magic Flute. All 14 profiles requiring system assignment produced zero assigned bands and retained unresolved music pages, as intended. This verifies profile loading and the assignment guard only. Source/profile/inventory/executable hashes and per-source native results are in `profile-additions-2-validation.json`; no output received a quality pass.
