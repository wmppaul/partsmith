# Brahms 93521 upper-staff continuation study

**Rejected. Independent source-tagged four-core musical controls demonstrate new target-note loss in four damaged-stem cases (filled/hollow, with/without a tie). The upper-owner crop loses186 or216 source pixels and the lower owner also worsens. See `../four-core-independent-2026-10-03/README.md`. No promotion or broad run is justified.**

The unpromoted source-continuation prototype separates the two p28 violin groups and passes the unchanged 765 crop checks. Both changed source strips retain their frozen full-target and local note/mark envelopes; source review found no new target notation loss. The p31 problem is unchanged. These real-score and existing-suite results remain valid bounded observations, but are insufficient against the independently reproduced musical omissions.

## Source and causal components

The original full systems on p28 and p31 were viewed before the analysis components. Corrected p28 was viewed separately. The immutable manually reviewed targets and original/corrected source hashes are bound in `verification.json`; none were changed. Current production analyzer hash is `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`.

A logging-only native replay exactly matches both current unmodified analysis and the saved component multisets on both pages. These are ordinary shared components, not the additional musical-ownership alternatives. The planner retains the full bounds of an ordinary component touching either target and a neighboring staff, which explains the crop widening.

**p28, corrected 1068×1538 raster.** The shared component has 23,057 analysis pixels, bounds `[132,69,969,229]`, and owners `[0,1]`; its corrected PDF box is `[52.775,27.591,387.419,91.570]`. All seven other upper-gap barline connectors are separated normally. The first interior barline at physical columns246..<248 remains because the upper translated core has29/34 supported rows (85.29%), below the existing88% gate. Missing rows are113..<117 and122..<123. The lower three staff cores along exactly this physical corridor have33/33,34/34 and34/34 occupied rows, and every intervening row is occupied. The original scan independently shows the same internal interruptions; this is not merely rectification damage.

As a diagnostic only, removing63 existing analysis pixels inside the failed connector's already defined gap rectangle `[242,142,252,173]` splits the shared component into intact13,119- and9,875-pixel groups owned by the upper and lower staff respectively. This proves the causal connection; it is not an automatic classification rule or a source edit. Other musical pixels lie elsewhere in that y-range, including dynamics and hairpins, so a full-width gap erasure would be wrong. The actual prototype uses the normal locally shifted branch-preserving cut interval; the63-pixel count belongs to this separate diagnostic experiment.

**p31, original 1800×2593 raster.** The offending component has448 analysis pixels, bounds `[1641,200,1651,350]`, and owners `[0,1]`; its PDF box is `[389.282,47.435,391.654,83.012]`. The source overlay shows a curved right system boundary with tiny transverse staff fragments. The final upper beamed notes, detached note and slur, and the lower flagged notes, slur and crescendo lie separately and must remain. The component is not a notehead or slur. The analyzer's final box-width filter retains this boundary fragment; the preceding boundary separator fails to recover local five-line identity. A generic width or aspect-ratio cutoff would also encounter legitimate stems, glissandi and steep curves, so this observation does not justify increasing that cutoff.

The two source/component overlays and `causal-components.json` retain the exact pixel paths, all occupied row runs, and separate diagnostic split results. Existing p31 target boxes `[349,33,386.5,65]` and `[353,73,389.5,102]` remain fixed. The full manual p31 ViolinII target remains a separate obligation, not a source of tuned thresholds.

## Frozen prototype

The hypothesis was written before the candidate results and is bound by SHA `aadbc4366738b6ae5bbe4d375240d1563588409e8c81b179dfd96911a3f9a655`. The candidate analyzer is `769776e41d5908f1c4bbdff8700493327f93f34bfc6ea9cb8df0cb28051f19ab`.

This fallback runs only after the existing local staff trace succeeds and the translated core/junction check fails. It requires one undilated physical stroke; real outer longitudinal junctions plus all five independently supported source staff-line fragments for the damaged core; and three other consecutive complete cores, all above or all below, each passing88% and every longitudinal junction inside that same physical corridor. Every row of every intervening inter-staff gap must be occupied in the same corridor. No sideways stepping, loose halo continuity, missing-gap interpolation, or concatenation across system whitespace is allowed.

The ordinary thresholds, the immediate core shortcut, musical terminal-body veto and branch-preserving gap separation are unchanged. The candidate only adds an independently checked longer-barline interpretation. Its unchanged terminal-body veto does not establish exclusive structural ownership. The independent four-core controls demonstrate that a musical cross-staff chord can share this physical spine and lose source pixels despite that veto.

## Bounded results

The exact frozen candidate passes all765 existing crop checks, retaining the printed known limitation for the pre-existing three-row-gap annotation. Fresh native analysis of both saved rasters preserves every staff candidate and staff-line coordinate.

| Band | Before y-range, PDF pt | Candidate y-range | Frozen target |
| --- | --- | --- | --- |
| p28 s1 ViolinI | 17.592–93.570 | 17.592–70.778 | y24–64 retained |
| p28 s1 ViolinII | 21.591–107.566 | 60.778–107.566 | y66–98.5 retained |
| p31 | All existing crops | Exact baseline | Unchanged |

The p28 shared component becomes exactly two staff-owned component boxes. No other semantic component changes occur on either page, and only the two listed crop edges and their ambiguity warnings change. All four existing p28 local note/mark obligations remain contained. Both complete source strips were inspected after the comparison. Complete neighboring staff cores are removed from these two bands, but ViolinI still grazes a neighboring upper line/clef tip and ViolinII retains fragments of the upper forte and lower Viola notation. The candidate is therefore less clean than the separately reviewed manual benchmark, while improving these two automatic crops.

No source PDF, production implementation, profile, manual target, saved project or published output was edited. No exports or whole-corpus run were performed. The unchanged p31 result is expected: its local staff trace fails before this new fallback. Extending the proof to that earlier failure would be a separate hypothesis and must not be silently folded into this result.

## Reproduction

`baseline-Core/` and `candidate-v1/Core/` contain the six compiled files. The scripts preserve the exact source of the logging and native replays. `trace.jsonl`, `core-support.json`, `candidate-v1/comparison.json`, the two candidate source-strip comparisons and `verification.json` bind the evidence. Full working rasters and native binaries are hash-bound under `.build/brahms-remaining-2026-10-03/upper-review`; they can be regenerated from the preserved harnesses and immutable input bindings. Paths in the harnesses describe this workspace.

The independent four-core gate failed. Three lower complete cores and uninterrupted gaps do not prove that the upper shared spine is nonmusical: a source-tagged cross-staff chord can share that corridor. Retain this rejected hypothesis and its bounded real-score improvement as development evidence; do not continue to broader runs or promotion. Passing765 or correcting this one real barline alone is insufficient.
