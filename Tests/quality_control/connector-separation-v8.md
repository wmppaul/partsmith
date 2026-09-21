# Local staff evidence for structural connector separation

The analyzer can now separate some intact barlines on curved scans whose staff positions differ from the page-center estimates. The original gap and core-support thresholds remain unchanged. A fallback requires sustained horizontal evidence at all five local staff lines, the original 88% core support, and an intact vertical junction at every line, including the outer boundaries. One pixel of junction-center rounding handles thin rasterized lines. Existing branch preservation still applies; original source pixels are never modified.

The earlier local-core experiment split a genuine cross-staff musical stem because horizontal staff-line ink filled enough missing stem-end rows to reach 88%. That approach was rejected. Mandatory physical junction evidence now preserves all 100 existing musical controls and passes two new independent intact-barline controls. The old analyzer fails the first new positive control. `bash tools/test_crop_quality.sh` passes all 102 checks against the final shared production files, including the separately promoted staff harmonic fix.

| Frozen source case | Bands | Foreign staff-line centers | Whole neighboring staves | Changed crops |
| --- | ---: | ---: | ---: | ---: |
| Current Quartet, exact recorded deskew |604|669→633|20→11|10|
| Current Quartet, raw |604|688→643|23→12|12|
| Historical Quartet 09200 |480|793→785|36→34|2|
| Ave |64|15→15|0→0|0|

All staff geometry stays unchanged in the isolated comparisons. The nine saved corrected pages retain identical 140 crop geometries. No new or worse failures appear across 39 raw and 50 corrected existing source regions or the historical frozen guards. Ave's 64 crops are exactly unchanged.

Independent source review froze envelopes before candidate crop edges were inspected: the p6 Viola/Cello pair plus 12 additional changed-band cases across the two editions and raw-only p28. All envelopes and the six detailed p6 landmarks fit the actual native exports. Independent visual comparison confirms intended notes, clefs, signatures, slurs, ledger lines, dynamics, hairpins, staccato and fermatas in those bands remain intact. Existing frozen guards were not relaxed.

The checkpoint's native exporter produced all four parts for each full source: 604 bands over 63 pages for the recorded-deskew Quartet, 604 over 63 pages for raw Quartet, and 480 over 41 pages for the historical edition. Every exported page passes native placement, source ordering, scale, staff containment and non-overlap checks. Exact output hashes, test conditions, independent guards and changes are recorded in `connector-separation-v8.json`.

This is a bounded improvement. Eleven whole neighboring staves remain in the recorded-deskew output, including the first Violin staff inside p31s1 Violin II. Partial neighboring notes and directions remain elsewhere. The source review establishes the newly changed bands; it does not declare every part ready for unattended publication.
