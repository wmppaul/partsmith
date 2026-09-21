# Chamber and piano/vocal initialization review

The new profiles in `corpus-profile-additions.json` come from rendered source pages, printed labels, clefs and piano braces. The main `corpus.json` was left unchanged during the running baseline inventory. These are instrument initialization profiles, not completed extraction reviews. Every entry lists the exact source hash and pages inspected; uninspected pages and final part crops still require review.

| Source edition | Printed order represented in profile | Source layout findings |
| --- | --- | --- |
| Mozart K.478, normal Mutopia | Violin, Viola, Cello, Piano (2 staves) | Opening and movement changes on PDF pages 23 and 34 retain this order, including silent string staves. |
| Mozart K.478, light scan #478563 | Violin, Viola, Cello, Piano (2) | PDF page 38 includes a short printed piano variant in a footnote. The 16th detected staff is real editorial notation. Page 51 also has a tiny variant chord. |
| Mozart K.478, medium scan #86903 | Violin, Viola, Cello, Piano (2) | Page 1 has a short alternative piano bass staff below the last system. Page 25 has four complete five-staff systems; baseline detection misses the first Violin staff. |
| Mozart K.387, normal Mutopia | Violin I, Violin II, Viola, Cello | Labels and order verified at the opening and Menuetto, Trio, Andante and final Allegro transitions on pages 12, 14, 16 and 24. Final page 31 has two complete systems. |
| Mozart K.498, normal Mutopia | Clarinet in B-flat, Viola, Piano (2) | Printed `Clarinetto in B.` has one flat while strings/piano have three; order repeated at Menuetto and Rondo. Pages 12, 13 and 17 retain four physical staves. |
| Schumann Piano Quintet #06822 | Violin I, Violin II, Viola, Cello, Piano (2) | Page 1 is a cover. Page 2 labels all five parts. Sampled interior, coda and last pages retain six physical staves. |
| Brahms Quartet #242312 | Violin I, Violin II, Viola, Cello | First page distinguishes `1. Violine` and `2. Violine`. Sampled systems retain all four staves; page 26 is a publisher catalogue. |
| Brahms Quartet #93521 | Violin I, Violin II, Viola, Cello | Page 1 is a cover. Page 2 labels both violins separately, then Bratsche and Violoncell; sampled later/last pages retain four staves. |
| Schumann Frauenliebe #51733 | Voice with lyrics, Piano (2) | Cover on page 1, music on pages 2–17, blank page 18. The final piano postlude keeps the voice staff with printed rests. Baseline misses the lower piano staff in page 14's fifth system. |
| Schubert Winterreise #00414 | Voice with lyrics, Piano (2) | **Variable printed roster:** pages 47 and 69 begin with piano-only systems. Cover and blank on pages 1–2; first music on page 3. Profile requires explicit system assignment. |
| Schubert Erlkönig, normal Mutopia | Voice with lyrics, Piano (2) | **Variable opening:** first four systems on page 1 are piano only (bars 1–12). Voice appears in the fifth system at bar 13. Profile requires explicit system assignment and counted opening voice silence. |

The existing medium Brahms Trio profile remains at `Tests/trio_medium/profile.json`; it was already mapped and has earlier full-source evidence, so no duplicate was created.

The independently checked **Notte e giorno** opening is also variable: two piano-only systems, followed by three voice/piano systems, produce **13 real staves**. The native count agrees with `Tests/full_scores/notte-map.json`; it is not a false-positive regression. The proposed variable profile prevents a fixed three-staff cadence. Historical `Tests/full_scores/notte-overrides.json` uses an editorial voice cue, which is reviewed output rather than pure Auto or newly counted generated rests.

The two Mozart scan ossias must not be silently deleted just to make staff totals divisible by five. Associate the extra notation with the piano part as an editorial variant or preserve the printed context. Conversely, the missing Violin staff on Mozart #86903 page 25 and missing lower piano staff on Schumann #51733 page 14 are genuine detector misses: the full source and native overlay were compared directly.

`profile-planning-baseline.json` records native planning diagnostics using these initialized profiles and the frozen baseline executable. A plan without unresolved pages still needs source coverage and independent visual review before its parts can be called usable.

Normal Mozart K.478, K.387 and K.498 produce complete raw plans (660, 520 and 405 bands respectively) with these profiles. Other raw plans report the named ossias/missing staves or zero-staff pages. The raw batch planner does **not** call `ScoreDetectionReview.automaticallyExcludePagesWithoutStaves()`, which the app uses to skip detected blank/nonmusic pages. Thus an unresolved cover or catalogue in this report alone does not demonstrate a GUI blocker. Full-flow testing should exercise that production review step and still distinguish real nonmusic pages from detector failures that happen to produce zero staves.
