# V3 full Brahms replay: fermata false ownership

V3 remains outside production. It recovers the complete broken-stem control and removes the earlier five-page false matches, but a fresh replay of all **39 Brahms pages / 604 bands** finds a different false musical span on page 10. Violin II and Viola each acquire the other's complete staff core.

## Exact scope

The native analyzer is frozen at SHA256 `6f8a9200324702cc6579dba7455e7c6a0e2686cf6ab1e4606309d48e9196010c`. All 39 unchanged source images from the preceding full replay are used, with the same nine saved rectifications and corrected-page scale 2.5. The separate higher-resolution study is not included. Staff analysis is freshly rerun on every image; instrument profile, all staff geometry, ordinary component multisets, existing preservation alternatives and all band identities remain unchanged.

No old crop contracts. One new alternative causes two expansions:

| Crop | Previous top–bottom, points | V3 top–bottom, points |
|---|---:|---:|
| p10 system 1, Violin II | 56.396–102.831 | 56.396–131.301 |
| p10 system 1, Viola | 82.019–133.436 | 59.481–133.436 |

The measured Release run takes 6.05 seconds excluding PDF rendering. No candidate PDF or app was generated. A prospective combination with the rejected numbered-line experiment was stopped before any combined test or worker executed.

## Actual source

The new source region is at the right edge of the opening system. The barline touches repeated **fermata arches** above the independent instrument notes. Those compact, thick curved marks are not noteheads on a shared musical stem. A local filled patch inside an arch does not establish that its complete shape is a filled notehead. Giving the whole head-to-head interval to both instruments is therefore a false ownership claim.

The exact observer accepts three arches, above Violin II, Viola and Cello. Their detached dots remain separate. The interval between the outer arches intersects only the Violin II and Viola staff cores, producing the two incorrect ownership assignments. [The implementation/source report](../source-musical-spans-v3-2026-10-03/README.md) retains the three measured body footprints and verifies that logging does not change the native result.

The unannotated [source context](p10-source-context.png) and [magnified source detail](p10-span-detail.png) preserve this distinction. The latter is a displayed enlargement of the original crop, not additional source resolution. The new normalized component is `[0.8888889, 0.1066461, 0.9077778, 0.2105873]`, tagged as an ownership alternative for staff IDs 1 and 2.

## Bounded gains remain separate

The [independent 29-case results](../musical-span-independent-2026-10-03/candidate-v3/README.md) recover all three case176 owner envelopes, including their full 1,400 required source pixels. Complete observations rise from 64 to 70 with no new losses versus production. The [unchanged six-case addendum](../musical-span-attached-addendum-2026-10-03/candidate-v3/README.md) retains clear pp/flat negatives and full three-head recovery at half scale, but not full scale. Original four-core controls remain unchanged and still include existing incomplete envelopes.

Those measurements validate the narrow shaft-pixel correction: removing the physical shaft from a body representation had artificially split genuine oval heads before testing their thickness. Restoring only observed black shaft pixels within their attachment rows repairs that representation. They do not validate arbitrary thick compact glyphs as musical heads, nor override the real page-10 failure.

[comparison.json](comparison.json) contains exact component and crop changes. The archive preserves all 39 candidate results, baseline inventory, comparison and replay tools, frozen candidate sources, input bindings and logs. Full source rasters are reproducible from the hash-bound inputs in the preceding [full-score replay](../brahms-source-spans-full-2026-10-03/README.md). Future work needs whole-body shape evidence that distinguishes these observed arches from filled heads; no source guard or expected loss set has been relaxed.
