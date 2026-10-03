# Independent combined Brahms 93521 output review

**Verdict: accept the bounded crop improvement as a draft.** Source page 29/system 1 loses two whole neighboring-staff inclusions while retaining the intended violin notation and heading. All 604 music strips and 42 direction copies remain in source order. No new output clipping, dropped system, off-page content or row collision was found. The resulting 13→14 First Violin page turn remains inconvenient during continuous rapid playing; this is not a performance-ready pagination claim.

This second review was performed independently of the output owner's visual review. It reads the exact fresh-worker baseline/candidate exports under `.build/brahms-continuation-release-2026-10-03/output-review/`; it makes no production or owner-report edits. `independent-results.json` binds both manifests, all eight baseline/candidate PDFs and the current corrected review source. `independent-review.py` preserves the separate structural checks and render procedure.

## Source retention

I first viewed the immutable original page-29 first-system image and its corrected counterpart from `residual9-boundary-independent/source-review/`, then rendered the current candidate's corrected source and actual PDF rows. I compared the two changed strips directly with the source, including the left clefs/key/time signatures, opening notes, beams, lower slurs, articulation dots, dynamics/hairpins and right-hand repeat barline/dots.

- **First Violin:** all visible intended notes, the complete “Poco Allegretto con Variazioni.” heading, the opening p, slurs, hairpins and closing pp remain. The frozen source envelope `[0, 23.5, 427, 74]` is wholly contained in the final crop `[0, 18.90358657925185, 427, 75.76205167759349]`. The former lower edge was 91.65291168530655; the change removes almost all of the Second Violin staff while retaining a thin neighboring top-line/clef fragment.
- **Second Violin:** all intended notes, low opening notes and slurs, late low sharp/ledger note, p/pp and hairpins remain. The frozen envelope `[0, 70.5, 427, 105.5]` is wholly contained in `[0, 59.22367913613573, 427, 110.62707288854608]`. The former upper edge was 35.26880061704583. The copied heading is retained, and the obsolete whole First Violin staff is removed. Neighboring dynamics/beams above and viola fragments below remain visible.

The source envelope files were not changed. The current corrected-source PDF has SHA-256 `2509460f334bf1f762e376e1f68b1df87a8ec5e0c7db68f8e72fd4cee287a933`. Its regenerated PDF bytes differ from earlier corrected review PDFs; the current page itself was rendered and compared to the original, rather than treating a prior PDF hash as current evidence.

The independent structural comparison found only those two changed main crop rectangles (the First Violin upper edge also differs by ~1e-13 pt rounding). The other 602 main source rectangles are exact, and every direction source rectangle and its ordering is exact. This is not a new whole-score note-by-note audit.

## Changed output pages and turn

I rendered and viewed all 18 changed candidate pages: First Violin pages 1–17 and Second Violin page 12. The First Violin sheets `independent-pages-*.png` cover every changed page; its pages 12–15 were also examined as individual larger images. Second Violin page 12 and the two changed strips have dedicated images. I additionally viewed the owner's side-by-side baseline/candidate comparisons for First Violin pages 13 and 14.

The changed crop reduces First Violin page 13's top row height. Source `p31-s2-violin1` moves intact from baseline output page 14 to candidate page 13. Its complete high-note/ledger/staccato/slur row was separately rendered and checked. Page 13 consequently contains 10 systems instead of 9; page 14 contains 8 instead of 9. Pages 12 and 15 retain their system membership. The resulting rows fit without collision or footer intrusion; the last page-13 strip ends at y=744 pt on a 792 pt page. Reading order remains continuous, with source page 31/system 3 now starting output page 14. The movement heading still begins page 13.

Both the old turn and the new turn interrupt continuous rapid notes. Moving one system does not create a new lost note or layout collision, but does not provide time for a practical unaided page turn. Existing broad neighboring ink remains distracting across the draft, including source pages 28, 31 and 35 visible in these reviewed pages. Smaller partial neighboring fragments also remain. The generic page balancing changes on the other First Violin pages are visually modest; no new readability/layout regression was found at this scope.

The output owner independently establishes that 46/64 pages are pixel-identical and 18 differ. My check concentrates on source retention and all changed pages; it does not repeat that full raster comparison or claim to re-review the 46 unchanged pages.

## PDF bindings

| Part | Pages | Candidate SHA-256 |
| --- | ---: | --- |
| Violin I | 17 | `b41d5d74d312e112b7d40574434a82bb33feb66ad6d01a2f417d20a42f4f1ce4` |
| Violin II | 16 | `b4dc8cfa17ee0d634ac34f337afe2d364984683d11acd3f0bec3284b6d825eed` |
| Viola | 16 | `1c1e5b14a528b9d5144435764a7d7933f62c0741eae88b3d07e0ead6546371b1` |
| Violoncello | 15 | `e5e51e8e009f29edfd461e466b54491a0c2adabfa987525bebc5f10c528c430b` |

Each part has 151 strips; total 64 pages. These hashes were also verified against the newly delivered PDFs in `output/pdf/auto-qc-2026-09-21/brahms-quartet-93521-continuation`. `independent-hashes.json` binds this review's files and original source-review dependencies without modifying the owner's manifest.
