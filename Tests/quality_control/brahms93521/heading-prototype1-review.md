# Experimental heading recognition: independent review

The exact inventory `.build/auto-qc/ocr-probe/quartet93521-deskew-headings.json` detects **5 of 7 large headings** across all 39 pages: Vivace, Trio, Coda, Poco Allegretto con Variazioni, and Doppio Movimento. All five predictions are true headings, have the right source system, and retain the complete visible heading glyphs when their bounds are drawn on the hashed corrected reference. There are no false positives among the five predictions. Andante (p16s1) and Agitato (p22s1) are missed.

The Trio rectangle includes a conspicuous neighboring violin beam at its lower-right corner; the heading is complete but the pasted annotation would contain music debris. Coda's lower edge is immediately against a staff line, requiring actual-fragment inspection. These are separate from heading recall.

The corrected oracle was not adjusted to recognition output. JSON records exact inventory, oracle and source hashes and confirms matching rectifications. `heading-prototype1-oracle.png` shows every expected heading, with red oracle bounds and blue detector bounds, against the exact derivative. Rectangle-coverage scores include oracle whitespace and are not treated as note/glyph clipping by themselves.

This is a seven-heading-class result on one score, not a robust full extraction result. The remaining rehearsal letters, ending brackets, return/D.C. directions and shared repeat-barline fermata in the 49-region source oracle remain outside this recognizer's implemented scope. No actual exported shared fragments were assessed in this check.
