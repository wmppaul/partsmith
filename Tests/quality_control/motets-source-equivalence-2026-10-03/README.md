# Motets 101579 versus 101580: source equivalence fails

**No automatic source-map transfer is supported.** Both originals have 18 pages with equal per-page geometry, but all 18 native decoded page images differ. The independently reviewed 45-system map for 101580 remains bound to its own source.

Both MediaBox and CropBox are `[0, 0, 595.2, 841.08]` pt, with zero rotation throughout. PDFKit Media, Crop, Bleed, Trim and Art boxes match on every page. The same exact production rendering function produced 1800 x 2544 pixel RGBA images for both PDFs, with its unchanged 1800 x 2600 limits. No staff detection or extraction was run.

Exact decoded comparisons find 151,625 to 489,202 differing pixels per page (3.311% to 10.683%). The under-190 ink masks differ on 7,113 to 21,943 pixels per page, 311,188 in total. Differences are not just PDF container bytes. Their encoding/rendering cause is not isolated; these are pixel counts, not counts of differing notes or symbols. The frozen exact-equality criterion was not relaxed after seeing the result.

| Physical page | Different RGBA pixels | Percent | Different under-190 mask pixels |
|---|---:|---:|---:|
| 1 | 151,625 | 3.311% | 7,113 |
| 2 | 298,007 | 6.508% | 13,324 |
| 3 | 453,066 | 9.894% | 20,141 |
| 4 | 457,691 | 9.995% | 20,065 |
| 5 | 483,963 | 10.569% | 21,256 |
| 6 | 337,444 | 7.369% | 15,036 |
| 7 | 346,263 | 7.562% | 16,102 |
| 8 | 356,628 | 7.788% | 15,514 |
| 9 | 355,238 | 7.758% | 15,598 |
| 10 | 383,787 | 8.381% | 17,041 |
| 11 | 489,202 | 10.683% | 21,943 |
| 12 | 376,861 | 8.230% | 16,696 |
| 13 | 361,284 | 7.890% | 15,808 |
| 14 | 437,171 | 9.547% | 19,340 |
| 15 | 423,041 | 9.238% | 18,342 |
| 16 | 429,143 | 9.372% | 19,589 |
| 17 | 430,663 | 9.405% | 18,959 |
| 18 | 424,120 | 9.262% | 19,321 |

All 18 changed page pairs were visually inspected. Their printed page sequence, title/lyric page, section headings, staff rosters, system layouts and bar-anchor positions visually correspond. There are 45 visible musical systems in both; page 1 is the lyric/title page. The native-resolution page-4 detail also shows corresponding notation. This is useful evidence for assisted initialization, but not a note-by-note identity claim. **101579 still needs its own actual-source assignment/crop and output review.** Existing crop coordinates, detector IDs, recognition bindings and complete output certification cannot be inherited from this failed equivalence check.

`comparison.json` binds both original PDFs, all 36 native PNG byte hashes, every decoded RGBA pixel hash, and each page's difference count/bounds. `native-pages.json` retains both sets of exact PDF geometry. `protocol-before-results.json` binds the renderer and preexisting independent 101580 map before rendering. The renderer is the unmodified production Native `9f8d7e...` function extracted into a minimal read-only harness; the analyzer was never called. The two PDFs remain unchanged.

The nine complete-page pair sheets and one native detail viewed by the reviewer are archived once. They are presentation images; exact arithmetic used full native images before any thumbnailing. Full native PNGs remain in the private run directory, hash-bound here and reproducible from the immutable PDFs with the retained harness. No original PDF is duplicated in this report. No user documentation, production code, source map or delivered output was edited.
