# Lightly skewed scan shortlist for Scan Rescue benchmarks

Goal: a small, boring, representative set of scanned PDFs with only mild tilt/skew — enough to test deskew and staff-band correction, but not so bad that they become edge cases.

## Core set (8)

### Chamber
1. **Mozart — Piano Quartet in G minor, K.478**
   - Work page: https://imslp.org/wiki/Piano_Quartet_in_G_minor%2C_K.478_%28Mozart%2C_Wolfgang_Amadeus%29
   - Recommended file on page: **Complete Score (scan) #478563** — Piupianissimo — 52 pp — 2017-06-25
   - Why: mixed chamber layout with piano grand staff plus 3 strings; good for variable system height.
   - Preview impression: clean scan, only mild visible tilt.

2. **Brahms — Clarinet Trio, Op.114**
   - Work page: https://imslp.org/wiki/Clarinet_Trio%2C_Op.114_%28Brahms%2C_Johannes%29
   - Recommended file on page: **Complete Score (scan) #114011** — piupianissimo — 35 pp — 2011-08-19
   - Why: clarinet/cello/piano layout; another mixed-height chamber score without being crowded.
   - Preview impression: clean scan, mild visible tilt.

### Orchestral
3. **Brahms — Symphony No.1, Op.68**
   - Work page: https://imslp.org/wiki/Symphony_No.1%2C_Op.68_%28Brahms%2C_Johannes%29
   - Recommended file on page: **Complete Score (scan) #317803** — Piupianissimo — 86 pp — 2014-03-05
   - Why: standard orchestral score with many staves; good baseline for dense but normal systems.
   - Preview impression: still clean, but enough tilt to exercise deskew logic.

4. **Schumann — Concertpiece for 4 Horns and Orchestra, Op.86**
   - Work page: https://imslp.org/wiki/Concertpiece_for_4_Horns_and_Orchestra%2C_Op.86_%28Schumann%2C_Robert%29
   - Recommended file on page: **Complete Score (scan) #291222** — Piupianissimo — 77 pp — 2013-08-05
   - Why: medium-size orchestral score with a conventional Romantic layout.
   - Preview impression: mild visible tilt, otherwise straightforward print scan.

### Piano-vocal
5. **Schumann — Frauenliebe und Leben, Op.42**
   - Work page: https://imslp.org/wiki/Frauenliebe_und_Leben%2C_Op.42_%28Schumann%2C_Robert%29
   - Recommended file on page: **Complete Score (scan) #270922** — piupianissimo — 16 pp — 2013-02-23
   - Why: simple voice-and-piano systems; good first scan-rescue case for piano-vocal.
   - Preview impression: slight but manageable tilt.

6. **Puccini — La bohème, SC 67**
   - Work page: https://imslp.org/wiki/La_boh%C3%A8me%2C_SC_67_%28Puccini%2C_Giacomo%29
   - Recommended file on page: **Vocal Scores → Complete Score #885132** — Goldberg988 — 277 pp — 2023-11-22
   - Why: long-form opera vocal score / piano reduction; excellent realistic benchmark once the simpler song case works.
   - Preview impression: mild visible skew in a generally clean printed vocal score.

### Choir
7. **Brahms — 2 Motets, Op.74**
   - Work page: https://imslp.org/wiki/2_Motets%2C_Op.74_%28Brahms%2C_Johannes%29
   - Recommended file on page: **Complete Score (scan) #101579** — piupianissimo — 18 pp — 2011-05-09
   - Why: SATB-plus-keyboard presentation with multiple vocal staves; useful for choir-system grouping.
   - Preview impression: only mild tilt; good non-crazy choir benchmark.

8. **Mendelssohn — Hear My Prayer, WoO 15**
   - Work page: https://imslp.org/wiki/Hear_My_Prayer%2C_WoO_15_%28Mendelssohn%2C_Felix%29
   - Recommended file on page: **Complete Score #40163** — Ralph Theo Misch — 10 pp — 2009-09-29
   - Why: soprano + mixed chorus + organ; gives you a choir score with varying system content.
   - Preview impression: light skew only; still very usable as a first rescue-mode sample.

## Good alternates (2)

9. **Brahms — Gesang der Parzen, Op.89**
   - Work page: https://imslp.org/wiki/Gesang_der_Parzen%2C_Op.89_%28Brahms%2C_Johannes%29
   - Recommended file on page: **Complete Score (scan) #109040** — piupianissimo — 27 pp — 2011-07-13
   - Why: choral-orchestral hybrid; more complex than the core set, but still not a wreck.

10. **Brahms — String Quartet No.3, Op.67**
   - Work page: https://imslp.org/wiki/String_Quartet_No.3%2C_Op.67_%28Brahms%2C_Johannes%29
   - Recommended file on page: **Complete Score (scan) #242312** — piupianissimo — 26 pp — 2012-07-14
   - Why: fixed 4-staff chamber score; nice control case for “same spacing every page” assumptions.

## Manual review checklist before adding to the Codex folder
- Prefer the exact file IDs above, not manuscripts or heavily cleaned derivatives.
- Keep only scans that look like **mild** tilt, not crooked photocopies.
- Reject pages with strong gutter curvature, clipped margins, shadows, or uneven exposure.
- For the first pass, avoid handwritten manuscripts, title pages with no music, and scans where the first music page already looks hard.
- Keep a note next to each PDF saying: category, file ID, and whether your manual review still agrees that it is “lightly skewed”.
