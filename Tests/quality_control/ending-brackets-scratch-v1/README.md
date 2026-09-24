# Paired ending brackets: scratch experiment

Across 68 full pages from KV498 and Brahms 93521, the experiment finds all ten known printed ending brackets in five pairs. A permissive line/hook detector proposes 576 regions; coalescing leaves 415. OCR produces twelve numeral-like regions. Pair geometry rejects two beam fragments misread as “2”, leaving the ten known brackets and no extra selected pair.

This is a source-copy experiment. The bracket lines and digits are copied directly from the score. Fast Vision reads three scanned printed “1” glyphs as literal “I” at 0.5 confidence. That ambiguous reading is preserved as evidence and accepted only as the first candidate in a closed bracket followed by a correctly aligned, recognized “2” bracket. It is never drawn as a replacement numeral.

Twenty-five ownership/alignment controls pass, along with three image-based synthetic negatives: shifted Roman-I prose, unpaired Roman I, and “Chapter I” in the number cell. The two actual beam false positives are retained as images. Search regions are tied to a verified system's first staff; no page IDs or oracle rectangles appear in recognition rules.

All ten proposed source envelopes were visually inspected. All intended digits and bracket strokes are retained. Some frozen oracle rectangles include additional blank safety margins outside the measured copy regions; every mismatch is recorded, without changing the oracle. The Brahms p6 first ending includes a clipped neighboring one-bar-rest count, and p32/p36 retain adjacent musical fragments. These are not clean-isolation results.

The complete scratch KV498 export has 405 bands on 39 pages. Root independently inspected the actual Clarinet, Viola and Piano ending passages: both numerals, all hooks and long lines remain complete, align with the correct bars, and do not collide with intended music. The lower source guard extends 0.293 points beyond the copy into blank space. The guard remains frozen. The known duplicate Rondo heading is a separate unresolved issue in this scratch generation.

`review.json` binds sources, frozen guards, OCR outputs, inventories, exporter and PDFs by SHA256, and lists exact failures and limitations. `prototype/` preserves the scratch implementation only. This detector is **not enabled in the app**. Unpaired endings, third endings, unusual number lists, additional score styles and variable instrument layouts require further work; this experiment is not a broad recall claim.
