# Brahms Op.114 full-source map review

Source: `sample_scores/lightly_skewed/02_brahms_clarinet_trio_op114_imslp_114011.pdf`.

The full PDF has 35 pages: 33 music pages with 131 systems / 524 physical staves, followed by a blank page and a publisher catalog. Those last two source pages are explicitly classified as nonmusic; no music is silently skipped. Page1 has three systems and pages2–33 each have four. Every music system has Clarinet in A, Violoncello, and Piano (two physical staves retained together). The title's optional viola alternative is not a separately printed stave and does not produce an invented part.

The four movement starts are PDF p1 Allegro, p12 Adagio, p18 Andante grazioso, and p26 Allegro. Source counts, order, all movement starts and the final cadence were independently mapped from full-page contact sheets. Native v7 supplies all 524 staff proposals with no manual detector replacements. Dense p13 and p16 overlays were independently inspected here after the detector's phase correction; source line identity, including final piano right-hand staff p16 around y702.22, is correct. The app_audit reviewer inspected every target boundary on all 33 music pages; its detailed page observations and source evidence are in `trio-independent-review.md`.

Profile: Clarinet and Cello top/bottom10 staff spaces, Piano top/bottom9. Both horizontal trims are zero. This correction is necessary for alternating scan margins: p2's final barline extends to about x583.5, and the piano measure number on p7 begins around x2.5. The full-width protected regions include those physical edges. No per-band crop rectangles and no masks are used.

Seven common tempo fragments were rendered at 4x and visually inspected, then associated with Cello, whose source staff lacks the direction printed above both Clarinet and Piano. They cover the four movement tempos plus p11s1 rit., p11s2 Poco meno Allegro, and p25s3 Un poco sostenuto. These are source image fragments, not re-created or inferred text.

Accounting: native 524/524 staff proposals on all music pages; zero on the two nonmusic pages; zero detector replacements; zero custom crop rectangles; zero masks; seven verified shared fragments; six music-page metadata overrides; two explicit nonmusic page classifications. Final native export review and PDF hashes remain separate from this source map audit.
