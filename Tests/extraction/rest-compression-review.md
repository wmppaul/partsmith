# Rest compression: source review and acceptance fixtures

Reviewed 2026-09-20. This is a manual visual audit of candidate passages, not an automatic rest-recognition result. PDF page numbers and system numbers below are one-based. The source PDFs and existing extraction projects remain unchanged.

## Verified passages

| Source | Exact location | Verified notation | Expected handling |
| --- | --- | --- | --- |
| Brahms Clarinet Trio, medium scan | PDF page 3, Clarinet in A, system 1; printed bars 42-47 | Six consecutive complete measures, each containing only a whole-bar rest. The line includes the continuing clef and key signature; there is no new tempo or meter within this line. | Suitable internal passage for a manually specified six-bar replacement. Keep the surrounding source systems. |
| Same Trio | PDF page 3, Clarinet, system 2; bars 48-52 | Bars 48-50 are three full-bar rests. Bar 51 contains rests followed by a sounding entry marked `p`; bar 52 continues the phrase. | **Do not replace the whole second band.** Together, bars 42-50 constitute nine resting bars, but a whole-band-only feature cannot combine this nine-bar run safely. |
| Mozart, The Magic Flute overture | PDF page 2, sole system; Adagio bars 8-15 | Flute, Trumpets, and Timpani each have eight full-bar rests. Contrabass has seven full-bar rests followed by a sounding entry in bar 15. | Positive rest-only controls and a close negative control. Never replace the Contrabass band with eight rests. |
| Same Magic Flute | PDF page 3, first Allegro system, bars 1-4; second system, bars 5-9 | Flute, Clarinet, Horns, Trumpets, and Timpani rest throughout all four measures and all five measures respectively. | Useful 4+5 join example only if the opening Allegro, meter, and required key/clef context survive. Do not use a bare nine-bar replacement as a verified demonstration. Do not join back across the Adagio/Allegro boundary. |
| Schumann, Frauenliebe und Leben, lightly skewed scan | PDF page 16, printed page 17; Voice, system 3 | Eight full-bar rests. | Additional rest-only scanned control. |
| Same Schumann | Same page, Voice, system 4 | Eight full-bar rests, with a fermata over the final rest and a final barline. | A bare eight-bar replacement loses the final fermata. Retain the original or explicitly preserve that boundary and marking. |
| Brahms Clarinet Trio, lightly skewed scan | PDF page 27, Clarinet, system 4; bars 40-45 | Six whole-bar rests, but the meter changes from 9/8 to 6/8 inside the system. | Negative control for whole-band compression: preserve the meter change or retain the original. Do not infer one uniform count from low ink density. |

## Exact sources

Paths are relative to the Partsmith repository root.

| Source | Path | SHA-256 |
| --- | --- | --- |
| Trio, medium | `sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf` | `0f617f77acf2e257973b14a8ce558e88eca877835df6fff4894419e66c871e4b` |
| Magic Flute | `sample_scores/normal/02_orchestra/mozart_magic_flute_overture_kv620_score.pdf` | `c455db9ffabb18a8d3f5e111090825d31294941fa15ad7bbd530421850ebb86d` |
| Schumann, lightly skewed | `sample_scores/lightly_skewed/05_schumann_frauenliebe_und_leben_op42_imslp_270922.pdf` | `d13fc3f4299dda634845b218222add8884ab9fd5257a9abb7cb2f9bcad4b9975` |
| Trio, lightly skewed | `sample_scores/lightly_skewed/02_brahms_clarinet_trio_op114_imslp_114011.pdf` | `db43702c5b9b64069748f90339aeeb6f4e4d5736696b59dd8e14a58780c5e19d` |

Do not substitute the medium-skewed Schumann PDF: it has different pagination. Its page 16 is not the final page inspected here.

The existing project `output/pdf/brahms-trio-medium/Brahms Clarinet Trio Op. 114.partsmithproject` contains the preferred six-bar demonstration:

- Part: `Clarinet in A`, ID `734CF9D9-B1E8-4150-B5FA-C309824D9334`.
- Six-rest band: ID `722F70DA-D570-45ED-8E3D-AFB4EE91F90C`, `pageIndex: 2`, `topFraction: 0.06873109461240759`, `bottomFraction: 0.10457915294890398`.
- Following mixed band that must remain: ID `5E10100E-CA43-4CFA-8E85-B95F881DDC9E`.
- Use all original stored crop geometry, rather than reconstructing a crop from these abbreviated coordinates.

## Inspectable evidence

The full-page inspection rasters are scratch artifacts under `.build/rest-audit/`: `trio-medium-03.png`, `magic-flute-01.png`, `magic-flute-02.png`, `magic-flute-03.png`, `schumann-light-16.png`, and `trio-light-27.png`. They are not a substitute for the immutable PDFs. Recreate an image with Poppler, for example:

```sh
pdftoppm -f 3 -l 3 -scale-to 1600 -png sample_scores/medium_skewed/02_brahms_clarinet_trio_op114_imslp_114012.pdf .build/rest-audit/trio-medium
```

## Initial feature boundary

The first implementation is an explicit, editable per-band bar count, not automatic music recognition. It keeps the original source coordinates and offers restoration. Joining the immediately preceding rest is separately selected and off by default.

The compact replacement must retain any existing editorial labels and copied source-marking rows. These mechanisms do not automatically preserve notation inside the replaced crop. For new tempi, clefs, key or meter changes, repeats/endings, cues, fermatas, or any sounding notes, retain the source unless the needed notation is explicitly carried into the replacement.

Prefer an internal plain-rest demonstration, such as the Trio's six bars. An opening rest requires its performance context. A compact rest does not justify losing the Allegro or common-time signature at the beginning of Magic Flute's fast section. A source thumbnail in the editor improves inspectability but does not preserve a missing marking in exported music.

Acceptance requires the six-bar replacement to be visible and readable in production preview/export, the following Trio entry and its `p` to remain unchanged, restoration and undo to recover the exact source bands, and the source PDF bytes to remain unchanged. Synthetic joins can test 4+5=9 without presenting a context-losing Magic Flute output as musically complete.

## Implementation review

The initial implementation validates counts from 2 through 999. Rest metadata keeps the source geometry intact and is invalidated by changes to source bytes, crop geometry, source markings, exclusions, page correction, or the assigned part. Undo restores a complete prior snapshot. Joining is explicit and refuses an excluded-band gap, a page break, a label or copied marking, an invalid total, or conflicting available bar numbers.

Independent review found a preview/export mismatch: the preview snapshot had removed excluded bands before layout, erasing an intended join boundary. The snapshot now retains all bands of the selected part. `tools/test_preview_performance.swift` exercises a synthetic four-bar rest, an excluded band, and a five-bar rest whose join option is selected; both preview and export keep the two rests separate. It compares counts, source-band coverage, and actual PDF pixels. All **24 preview checks passed**, with **0.35 ms** observed enqueue time for the full Trio part and a ten-page final preview. This timing measures scheduling responsiveness, not total PDF rendering time.

## Final example review

Independently compared `output/pdf/rest-compression-example/Brahms Trio — rest example.pdf` with the full medium-scan source page 3. The one-page output is explicitly titled a Clarinet excerpt, with source page 3 and bars 42-62 identified. Its four bands cover the four source systems in order.

- The first system's six full-measure rests, bars 42-47, are replaced by a clear counted H-bar marked `6`.
- The next strip retains all three full-bar rests at bars 48-50, the partial rests and sounding entry at bar 51, its `p`, and the continuation into bar 52.
- The bar-53 strip retains the complete target notes, rests, accidentals, slurs, and diminuendo through bar 57.
- The bar-58 strip retains the target's high notes, triplet figure, accidentals, ties/slurs, dynamics, hairpins, rests, and final sounding entry through bar 62. The crop also retains neighboring cello fragments below the target staff; this is a preservation example, not a clean-isolation result.
- Editorial labels `Bar 42`, `Bar 48`, `Bar 53`, and `Bar 58` sit above their strips. Bar-number badges are hidden, leaving clefs and key signatures unobstructed.
- The editable example stores exactly one replacement (`barCount: 6`, `joinWithPrevious: false`); the other three bands have none. There are no whiteout masks or copied source-marking rows in this example.
- The embedded source PDF SHA-256 is unchanged and exactly matches the medium source hash recorded above.

The excerpt passes this limited target-preservation and rest-replacement review. This is not a fresh review of the complete Trio extraction or an assertion of automatic rest detection. The original opening tempo/meter context is outside the clearly labeled excerpt.

Reviewed output PDF SHA-256: `926a854e0fafd5c7df22aaf02b30b5270df1499f4f6a8ef35c779def977a84b1`. Reviewed editable project JSON SHA-256: `120bf4125824468adf87ee385795a4e7ec98d00dcbda21ce3919748f1b361b38`.

Also inspected `.build/rest-tests/synthetic-joined-9.pdf`: the four-plus-five join produces one readable H-bar marked `9`, while the following synthetic strip and its sounding note remain. This is a rendering/merging fixture, not a claim about source-score musical identity. Its SHA-256 is `b5eaab53e0d0b9a6e1f7a398e24ec40a397fea1bcfbfd26704f3dd75ff9e1a1d`.
