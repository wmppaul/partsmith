# Independent review of reviewed-system template matching

The frozen v2 matcher makes 56 correct complete-system suggestions after eight source-reviewed examples across these three complete scores. Including the examples, 64 of 82 source systems are covered; 18 still require manual assignment. No wrong part or partial system appears in these clean-source results. V2 also passes all 32 independent input challenges. This supports an optional, explicitly accepted layout-reuse aid, not automatic instrument identification or finished-part certification.

The unchanged v1 challenge result contains a real safety failure: after the supplied inventory loses the Voice staff at Notte page 2, system 1, v1 calls the remaining Piano pair a source-supported Piano-only system. The original source still prints Voice in bars 24–26. V2 rejects that page after rechecking the actual source raster, while retaining correct suggestions on unaffected pages. V1 is not accepted.

## Complete source coverage

| Complete score | Source systems / printed staves | Reviewed examples | New correct suggestions | Covered / total | Unresolved |
|---|---:|---:|---:|---:|---:|
| Mozart, *Notte e giorno* | 20 / 58 | 2 | 8 | 10 / 20 | 10 |
| Schubert, *Erlkönig* | 48 / 140 | 2 | 46 | 48 / 48 | 0 |
| Mendelssohn, *Verleih uns Frieden*, Righetti organ arrangement | 14 / 77 | 4 | 2 | 6 / 14 | 8 |
| Total | 82 / 275 | 8 | 56 | 64 / 82 | 18 |

All 275 observed staves map one-to-one to the original PDFs' five horizontal line paths, with maximum line-coordinate difference 0.162 PDF points. Every seed and suggestion has exactly the source system's staff set, physical order, and named per-part ownership. The evaluator never reads the implementation author's `expected.json`. V1 and v2 have identical full-score suggestions and diagnostics on these clean inputs.

Notte's templates are Piano-only and Voice/Piano; Erlkönig's are the same. Mendelssohn needs SATB/Organ, Organ alone, Bass/Organ, and Alto/Bass/Organ. Organ always includes both manuals and the pedal staff. The source truth includes all 21 pages, each physical staff, system boundaries, instrument owners, printed measure anchors, and absent recipients. Separate choir and organ brackets are not independent musical systems.

With only the first real system supplied, all three runs safely make zero suggestions. Unsupported groups cause a whole page to abstain, so these results do not imply that one example is enough. Notte pages 3–4 and eight Mendelssohn systems remain unresolved with all reviewed examples. We did not relax the matching rules to improve these counts.

## Silence and identity limits

The complete source truth has 179 printed music rows and 27 required absent-part rows. Notte's opening Voice silence is nine bars; Erlkönig's is twelve. In Mendelssohn, Soprano and Tenor are absent for bars 8–66, Alto for 8–36, and Bass for 8–15. All four voices are actually printed in the seven opening bars and must retain their printed staff identities.

Six new suggestions omit instruments: one Notte system, three Erlkönig systems and two Mendelssohn systems. They explicitly require target-system counts. Suggestions carry neither a start bar nor a bar count, including when seeds are deliberately given start 999 and count 42. Source examples include different target durations despite identical instrumentation. This review does not claim that the matching helper alone generates or validates those rests; application must obtain each target count.

None of these three real documents has a same-count, different-roster transition. The independently frozen synthetic three-system source fixture safely abstains, but its unsupported split connections/no clefs prevent it from exercising the matcher's competing-template branch. That limitation is explicit. The author's separate source-equivalent conflicting-roster API controls exercise that branch; those are not counted among our 32 independent challenges or as new real-score coverage. Clef resemblance alone cannot establish an unseen same-count instrument identity. Reviewed seed identities remain a prerequisite, and suggestions require explicit acceptance.

## Independent challenges and historical failure

`challenge-v1-results-assessment.json` records 31/32 passing challenges and the full wrong suggestion plus original source truth for the missing Voice. `challenge-v2-results-assessment.json` records 32/32 on byte-identical inputs. The cases cover:

- No seeds, only the first seed, and arbitrary seed measure numbers for all three complete documents.
- Missing source images and cancellation.
- Cross-system selections, Piano-only subgroups of Voice/Piano systems, an organ brace missing the pedal, and Bass plus manuals mislabelled as Organ.
- Missing first, middle or last staff; missing Soprano/Tenor that mimics a known five-staff roster; missing pedal that mimics four staves; a phantom staff on blank source pixels.
- Reordered physical staves, changed profile counts, overlapping reviewed ownership, and the bounded same-count source fixture.

Safe rejection counts as passing a negative; it is not successful reuse. In particular, some malformed cases are rejected before reaching identity matching. The source recheck guards stale or altered inventories; because it uses the same staff detector, it cannot prove that an identically repeated detection miss is absent. A helper rejection means uncertainty, not proof that no instrument is present.

Read-only UI inspection found explicit acceptance, no automatic selection of competing `needsReview` alternatives, required counts for absent parts, source/review snapshot comparisons, and cancellation/run-ID checks. This is bound in `ui-inspection-binding.json`; it is not an independently executed UI test or a replacement for the root's batch/app validation.

## Evidence, independence and reproduction

`frozen/` preserves the original twelve files and unchanged freeze manifest (`f61cef9ce1743cf486ae0e9668bfaa7e9a551579f17d43e7b82fb5206d8e3ce1`). Source truth and protocol were completed before receiving the first matcher outcome summary. The manifest was recorded just after that summary, before opening implementation results; this sequencing is documented in the original freeze notes. No source oracle or negative expectation changed after outcomes. The remaining challenge inputs implement the frozen protocol and add explicit first/middle/last omissions; the same input bytes run against both versions.

`source-renders.zip` retains all 21 previously reviewed source-page PNGs unchanged. `archive-members.json` binds each image and the six common compiled Core files plus both matcher versions in `reproduction-core.zip`. PDFs remain in the repository and are hash-bound by `source-bindings.json`. Executables stay in scratch; their hashes are recorded, not copied. The v1 matcher is `7fe773ef2cc6ac7b25f5256cd3b1714696627e88de609bf8be552bcc17d69032`; v2 is `fe3504a1ba9b86659a6bc5bed37ef1e6424ca4c63d8deb959d45f3ad4a8d2df7`.

To recheck the independent comparisons, run `compare_source.py` on each `evaluation-v1`/`evaluation-v2` directory and `assess_challenges.py` on each challenge result. Native reproduction uses `build.sh`, `challenge.swift` and the archived Core files in a clean checkout with the hash-bound source PDFs. Restore this report's harness/input files under `.build/system-template-independent-2026-10-03`, including the synthetic PNG from `frozen/`, then build each frozen matcher and invoke the binary with the challenge-input JSON and a new output path. The first v1 launch failed before testing because the synthetic page omitted a required decoding key; that startup log is preserved. Only the harness schema was completed, with no source pixels or expectations changed, before both recorded runs.

The cached 32-case helper runs took approximately 1.24 seconds for v1 and 3.89 seconds for v2 on this host. These are process-local measurements, not a UI performance benchmark. No production file, original report, source guard, or exported part was edited by this independent review.
