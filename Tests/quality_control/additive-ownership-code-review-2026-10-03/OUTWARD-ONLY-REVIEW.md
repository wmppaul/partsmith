# Independent review of the outward-only repair

**The repaired model passes this independent code review and all bounded replay checks.** It resolves the native-raster regression recorded in the frozen initial `README.md`. This approves the model repair at the tested scope; the owner's broader 633/755 controls, full-score corpus and output reviews remain separate requirements. No production file or pre-existing test was edited here.

The reviewed frozen snapshot is `.build/ownership-alternatives-2026-10-03/Core`:

- `NativeScorePageAnalyzer.swift`: `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`
- `ScoreExtractionPlanner.swift`: `0cfd6f6fdb1b926a16c4984f63a6d0a4fdf0261878875508916c646a739784b2`

## Code audit

The optional `isOwnershipAlternative` field defaults to nil for older inventories. Native analysis retains the local second-pass components as ordinary evidence and marks only genuinely new `(ordered staff IDs, exact bounds)` identities as alternatives. No-veto pages still avoid the second pass. Exact-key membership and the final cancellation checks are retained.

The planner excludes alternatives from every ordinary component consumer: both lyric-grouping loops, high-target support, following-system competition, initial selection and detached-mark propagation. The repository Core search found no additional `inkComponents` consumer left untreated. Only after those ordinary decisions finish does an alternative expand the bounds of a part whose staff IDs it touches. Ownerless alternatives cannot independently change a crop; cross-part alternatives expand the relevant parts and retain the ambiguity warning. This directly prevents the new evidence from becoming a reason to revoke the existing detached relay.

This is a preservation interpretation, not a musical symbol classifier. A falsely merged group may still retain excess neighboring notation, and a lost source connection may still fail to supply ownership. The repair does not claim to resolve those pre-existing limitations, prove all musical ownership, or recover all remaining failed envelopes. Ordinary untagged data retains its previous behavior.

## Unchanged native-raster regression

`raster-relay-alternative/` reruns the original `raster_relay_probe.swift` against the repaired Core without changing the fixture, staff initialization, profile, dimensions or source masks. Source PNG SHA-256 is `b6dfc5721cabcb403113d14c01066ce0c4fe572621a886c8bf72ed549d5144e8`; its bytes and `source-evidence.json` bytes exactly equal the failing `raster-relay-v2/` files.

| Result | Ordinary components | Added hypothesis | Upper crop bottom |
| --- | ---: | --- | ---: |
| Local interpretation | 8 | none | 287 px |
| Rejected untagged union | same 8 | lower-only ordinary box | 264 px |
| Repaired union | same 8 | same lower-only box, alternative=true | **287 px** |

All nine geometric boxes and ownership ID lists match the rejected model when the new flag is ignored. Thus the test is repaired by interpretation rather than changed recognition, expanded guards or altered source geometry. The second detached source mark at y272–281 is retained again. The third mark at y295–304 remains outside the upper crop just as in the local baseline; it is not silently reclassified as a success. `repaired-comparison.json` contains these assertions and hashes.

## API, codec and cancellation checks

`alternative_probe.swift` adds the same API supplement five ways and verifies the following outcomes:

| Supplement | Expected and observed result |
| --- | --- |
| Flag absent | Legacy upper bottom0.280 remains unchanged. |
| Flag=false | Same ordinary legacy behavior. |
| Flag=true, lower owner only | Upper bottom remains its original0.329; the lower crop can expand. |
| Flag=true, no owners | Exact no-op plan. |
| Flag=true, both staff owners | Both crops can expand; ambiguity warning remains. |

All five full-page JSON codec roundtrips and subsequent replans are exact. A legacy component with no field decodes to nil and reencodes to the same JSON bytes; explicitly true and false fields both survive roundtrip. These checks preserve the original untagged API counterexample instead of rewriting it to make the new code pass.

The actual native raster supplies one flagged alternative and 1534 cancellation callbacks. Cancellation requested at callbacks1,2,100,767,1533 and1534 returns nil every time, including the final check. This exercises early, middle and final cancellation on a real two-hypothesis analysis, not only a one-staff no-veto image. The preceding optimized/final noise measurements remain in the initial report; no broad runtime guarantee is inferred from this small test.

The existing top/left-only sort can still produce pre-existing order differences among tied components. The new model does not use Set iteration as output order or accumulate alternatives across repeated Auto runs. The app worker's operation-identity/cancellation barriers are unchanged. No new acceptance gate is added.

`alternative-results.json`, the unchanged raster replay, exact six-source compilation archive and `outward-review-hashes.json` bind this companion review. `initial-review-hashes.json` still verifies the original failing report and all its original evidence, unchanged.
