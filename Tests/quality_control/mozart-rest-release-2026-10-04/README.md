# Mozart rest compression — Alpha 5 release review

This release fixes the opening Clarinet in A and two-staff Piano rest detection in the supplied Mozart K.488 score. Inserted rests join by default, including an eligible compressed opening followed by omitted silent systems. Original source rows remain separately editable.

## Reviewed output

The bounded fixture contains the first eight systems (bars 1–39), all nine parts, 72 source entries. Both numbered and unnumbered variants ran through the actual document compression and PDF export path. Clarinet's opening is five bars; Piano's printed opening five plus 34 inserted bars becomes one 39-bar grand-staff row with a single count. Both clefs, brace, meter, key signatures and copied opening instructions remain. The PDFs and editable project are in [the output folder](../../../output/pdf/mozart-rests-2026-10-04/README.md).

An independent agent compared all nine rendered outputs against the source and checked the source identity, geometry, markings and inserted durations. Playing and mixed strips were unchanged. Six of eight musically eligible whole-rest strips were recognized; opening Flute (header ink) and final Clarinet (neighboring Bassoon notes) remain conservative abstentions. Existing neighboring notation and header/footer crop leakage remain. This review does not certify every crop edge or the full 36-page score.

## Validation

- [Detector review](../mozart-rest-detection-2026-10-04/README.md): 112 new Mozart checks, including 81 injected-note cases; 250 existing detector checks across 34 real-score fixtures; 120 existing source-context checks with zero changed prefix/suffix pixels in the ten positive fixtures.
- [Default join review](../default-rest-joins-2026-10-04/README.md): 348 checks covering model persistence, boundaries, missing systems, manual separation, layout, rendering, document Undo and the automatic workflow. Native graphics access was needed for rectification checks; the same compiled executable passed with that access.
- [Independent source/output review](../mozart_rest_source_review_2026-10-04/output-review/README.md): all nine parts, two grand-staff H-bars with one count, unchanged playing passages, and the two conservative abstentions.
- [End-to-end record](end-to-end.json): both numbering variants; 72 retained entries, nine PDFs per variant, one printed Piano count of 39.

Root visually inspected the final Piano and Clarinet renders. Tests exercise model/document/layout/export behavior; this turn did not perform new live application mouse interaction tests. No running app or user project was replaced.

## Build and package

The frozen snapshot contains 47 source/build inputs. The Release build compiled all 37 Swift sources for both arm64 and x86_64, with macOS 14.0 as the minimum. Built and extracted ad hoc signatures, ZIP integrity, and every extracted bundle file/mode were checked. Only the executable changed from the Alpha 4 app bundle.

`source-hashes.json`, `snapshot-receipt.json`, `private-package-audit.json` and `archive-members.json` bind the reviewed source to the archive. `build-evidence.tar.gz` contains the frozen inputs and build evidence. `publish.py` verifies peer evidence, source hashes, tests and exported artifacts before replacing the local public ZIP. `publication.json` records that operation; GitHub publication is performed by the version-tag workflow. `manifest.json` covers this review's files.

Archive SHA256: `120a205da7a77353c16d3511090e0da909b8c9aae213739323d5dce5e37f1e6f`.
