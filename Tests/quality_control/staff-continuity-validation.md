# Staff continuity validation

The exact tested continuity guard was promoted after the parent completed its release build. Source SHA-256 is `fc94f285d300167d9010ed47b9cfcf1fee92f036ee8472e73a14939d38a30c9e`; previous v2 was `6dc75edcd2a784963941a827b2ebebb090c2767843533c415fcd0497282ee781`.

Across all 36 sources and 1,477 physical pages, the only changes are:

- Egmont PDF page 47: 15 → 14 candidates. Repeated high Violin I ledger lines are rejected; every one of the 14 actual staff line arrays is exactly preserved.
- Beethoven 52624 PDF page 106: 5 → 0 candidates. This publisher subscription page contains prose, no music.

All other retained staff line arrays match frozen v2 exactly. Total patterns change from 23,804 to 23,798: six source-verified false patterns removed, no new or moved patterns. The earlier Mozart/Frauenliebe recall recoveries remain intact. Synthetic nonlinear/curved/faint/tilted/broken staves and existing title/catalogue negatives pass, as do the existing staff-detection tests.

The guard requires at least three observed lines to continue for four staff spaces (minimum 12 pixels), with a small vertical tolerance and existing skew compensation. Repeated short fragments or prose glyphs lack this continuity. No score identifier, instrument count or expected output is an algorithm input. `staff-continuity-candidate.patch` is the exact narrow diff; `staff-anomaly-source-oracle.json` binds source hashes and independently observed positive/negative regions. `staff-continuity-validation.json` binds detector, executable, harness and corpus hashes. Full geometry remains in `.build/staff-anomalies-v1/continuity-aggregate.json`.

Run `tools/test_staff_continuity.sh` for the source/synthetic regressions. The harness also supports the same optional whole-corpus arguments as `test_staff_recall.swift`.

This is a bounded geometry improvement, not full extraction approval. Removing false candidates may change nearby proposed crop edges and planning; those outputs still need review. Bohème page 167 remains a separate harmonic-spacing failure (six true staves become three half-spacing patterns), and Beethoven 52624 page 1 still has seven ornamental false detections. Neither is claimed fixed here.

Independent logic review found no corpus-supported blocker. One specific limit remains: the consecutive-run guard resets at a column with fewer than three surviving lines. Aligned scan damage more frequent than four staff spaces may reject a real staff; the interrupted-line positive fixture uses longer segments and does not prove that harsher case. The corpus result does not imply universal robustness to interrupted scans.
