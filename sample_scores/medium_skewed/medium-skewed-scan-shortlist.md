# Medium-skewed scan shortlist for Scan Rescue benchmarks

Goal: a set of 10 scanned PDFs that sit above the clean/normal baseline and generally above the lightly-skewed set, while still being readable score scans rather than badly broken photocopies.

## Selection note
- I sampled these with the repo deskew reviewer on small music-page windows rather than full-PDF exhaustive review.
- The first 8 entries below produced usable skew estimates in the sampled pass.
- `09` and `10` are manual alternates: older scans that looked worth keeping even though the sampled estimator did not lock onto enough pages to report an angle.

## Shortlist
1. **Mozart — Piano Quartet in G minor, K.478**
   - Work page: https://imslp.org/wiki/Piano_Quartet_in_G_minor%2C_K.478_%28Mozart%2C_Wolfgang_Amadeus%29
   - Selected file: **Complete Score (modern reprint) #86903**
   - Sampled skew note: median `|angle|` about `0.45°`.

2. **Brahms — Clarinet Trio, Op.114**
   - Work page: https://imslp.org/wiki/Clarinet_Trio%2C_Op.114_%28Brahms%2C_Johannes%29
   - Selected file: **Complete Score (filter) #114012**
   - Sampled skew note: median `|angle|` about `0.475°`.

3. **Schumann — Piano Quintet, Op.44**
   - Work page: https://imslp.org/wiki/Piano_Quintet%2C_Op.44_%28Schumann%2C_Robert%29
   - Selected file: **Complete Score (600dpi) #06822**
   - Sampled skew note: median `|angle|` about `0.325°`.

4. **Schumann — Concertpiece for 4 Horns and Orchestra, Op.86**
   - Work page: https://imslp.org/wiki/Concertpiece_for_4_Horns_and_Orchestra%2C_Op.86_%28Schumann%2C_Robert%29
   - Selected file: **Complete Score #51506**
   - Sampled skew note: median `|angle|` about `0.225°`; included as a useful orchestral scan that still trends above the clean baseline.

5. **Brahms — String Quartet No.3, Op.67**
   - Work page: https://imslp.org/wiki/String_Quartet_No.3%2C_Op.67_%28Brahms%2C_Johannes%29
   - Selected file: **Complete Score (medium quality) #09200**
   - Sampled skew note: median `|angle|` about `0.525°`.

6. **Brahms — String Quartet No.3, Op.67**
   - Work page: https://imslp.org/wiki/String_Quartet_No.3%2C_Op.67_%28Brahms%2C_Johannes%29
   - Selected file: **Complete Score #93521**
   - Sampled skew note: early-page sample caught a `0.90°` hit, but the later music-page sample was sparse; keep this one as a stronger chamber alternate rather than a perfect calibration case.

7. **Brahms — 2 Motets, Op.74**
   - Work page: https://imslp.org/wiki/2_Motets%2C_Op.74_%28Brahms%2C_Johannes%29
   - Selected file: **Complete Score (filter) #101580**
   - Sampled skew note: median `|angle|` about `0.45°`.

8. **Brahms — Gesang der Parzen, Op.89**
   - Work page: https://imslp.org/wiki/Gesang_der_Parzen%2C_Op.89_%28Brahms%2C_Johannes%29
   - Selected file: **Complete Score (filter) #109041**
   - Sampled skew note: early-page sample gave median `|angle|` about `0.325°`; later sample was sparse.

9. **Schumann — Frauenliebe und Leben, Op.42**
   - Work page: https://imslp.org/wiki/Frauenliebe_und_Leben%2C_Op.42_%28Schumann%2C_Robert%29
   - Selected file: **Complete Score #51733**
   - Manual note: older D-Mbs scan kept as a piano-vocal alternate even though the sampled estimator reported no usable angle.

10. **Schubert — Winterreise, D.911**
   - Work page: https://imslp.org/wiki/Winterreise
   - Selected file: **Complete Score #00414**
   - Manual note: older Peters vocal score kept as a long-form piano-vocal alternate even though the sampled estimator reported no usable angle.
