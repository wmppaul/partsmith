# Original-source musical spans V3 — rejected on real fermatas

V3 repairs the exact V2 half-lobe measurement error and fully recovers case176. It rejects all eight known V1 false spans and the attached pp control. **The full39-page replay nevertheless finds a new false interval on Brahms p10: three fermata arches touching the right barline are classified as filled heads.** Two previously clean crops gain whole neighboring staff cores. This version is not suitable for promotion or combination with numbered-line cleanup.

Frozen Native SHA: `6f8a9200324702cc6579dba7455e7c6a0e2686cf6ab1e4606309d48e9196010c`. Protocol SHA: `10761c23ed286b161835cfef75aa1a8367817fcac731b7b661022f71a3c4ab6e`. Production Native remains `9f8d7ef80a27569ca3f5711388ad5876326a2931d60ecd77b2703d0aba235f01`.

## Exact change and bounded results

V3 preserves every V2 continuation/attachment/compactness parameter and source bound. The filled-disk test includes only actual original black shaft pixels between the same body's observed attachment rows. Tested centers remain original off-shaft pixels; no source gap is filled. This fixes the artificial split documented in [V2](../source-musical-spans-v2-2026-10-03/README.md).

- Case176: all three complete original source envelopes/pixel masks recover. The real eight-row scan interruption remains explicit.
- Original36 four-core cases: all144 owner loss results remain production-exact;68 are still incomplete. Filled and hollow recall is not generally solved.
- Independent29:70/99 complete, with no newly lost production/V2 pixels or lost old alternatives. The full-scale filled and hollow cases remain incomplete.
- Addendum6: pp and flat negatives remain clear. Three-head ownership succeeds at0.5 scale but the full-scale source still has an uncertified head and unchanged646/568/1082 owner losses. Connecting all certified heads cannot repair missing body evidence.
- Exact five real pages23/28/29/38/39: components and plans equal production, removing all eight V1 false intervals.
- Root's full39 corrected pages/604 crops: one new interval causes two expansions on p10. Ordinary components and old alternatives remain exact; the expansion-only contract prevents new crop loss but permits false ownership.

The [independent29 V3 report](../musical-span-independent-2026-10-03/candidate-v3/README.md) and [addendum V3 report](../musical-span-attached-addendum-2026-10-03/candidate-v3/README.md) are hash-bound in `bindings.json`. The full39 Release run took6.05s; this is not a UI responsiveness claim.

## P10 original-source finding

The logging-only p10 replay reproduces the root full39 analysis and plan byte-for-byte. Full original system context and the complete accepted footprints were viewed. Source image coordinates are top-down in the unchanged1800×2588 raster.

The physical shaft is x1628..<1631 and traced rows179..<612. Three accepted bodies are:

| Original bounds | Off-shaft pixels | Original body-shaft pixels | Accepted disk(x,y,radius) |
|---|---:|---:|---|
| [1600,276,1634,293] |170|27|[1613,279,3]|
| [1600,401,1634,419] |184|27|[1612,404,3]|
| [1600,528,1634,545] |183|27|[1616,531,3]|

Each is a **fermata arch**, with its detached dot below. The dots are separate components and are not silently included in the body certificate. A local filled disk fits in the thick top of each arch, but the complete shape remains open and concave. Compactness plus one local thickness witness is insufficient to establish a filled notehead.

The false interval [1600,276,1634,545] is assigned to staff IDs1/2. `p10-s1-violin2` expands its bottom from102.830757 to131.300618 source points; `p10-s1-viola` expands its top from82.019320 to59.480680. Each now contains the other's complete staff core. No actual shared musical shaft exists at that right system boundary.

`p10-source-footprints.png` juxtaposes original source with complete residual/body-shaft pixels and the accepted disks. `p10-witnesses.json` retains all footprint runs, source shaft pixels, explained thin paths and attachment rows. Exact source patches and full changed-page analysis are archived; source raster hashes remain bound. Candidate fit boxes were never treated as source ownership truth.

## Aborted combination

A mechanically composed numbered-lineV2+spanV3 snapshot was prepared at Native `516913dd298998d806e4484f7f8e440b32caaa29d67f5a003daa695c2079a65c`. Removing the four span additions recovers byte-exact numbered-lineV2; applying them to the shared baseline recovers byte-exact spanV3. **No combined test or worker ran.** Root stopped that experiment when the full39 p10 failure appeared. Its frozen construction record and explicit abort are archived; no success is inferred.

No new thresholds or variant were authorized at this freeze. Independent whole-footprint/hull measurements may diagnose the remaining distinction, but they are not a tested fix. Hollow/glyph ambiguity and pre-existing missed musical bodies remain explicit. The permanent796/297/336 combined suites and broad corpus were not run. Production, source guards and all prior rejected snapshots remain unchanged.
