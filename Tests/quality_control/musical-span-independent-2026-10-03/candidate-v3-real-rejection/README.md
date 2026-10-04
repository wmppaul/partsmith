# Standalone V3 rejected by original Brahms p10

**Do not promote or combine V3.** The parent’s full 39-page replay discovers one false musical interval on page 10, system 1. It expands the Violin II and Viola crops so each includes the other's complete staff core. The independent source review confirms that the accepted shapes are fermata arches touching a structural right barline, not noteheads on a shared musical shaft.

This real-score result overrides any promotion inference from the [bounded V3 recovery](../candidate-v3/README.md), which remains frozen and accurately reports its narrower scope. No combined controls, production edit, app build or candidate PDF export was performed by this reviewer.

The unannotated original system context was inspected before the detailed span and accepted footprint panel. All three fermatas have visible detached dots. Their local instrument notes and stems remain separate; the continuous vertical source stroke is the system's ordinary right barline. Local thickness inside a curved arch is insufficient evidence that the complete shape is a filled notehead.

The raw witness actually accepts **three** arches, above Violin II, Viola and Cello:

| Accepted source body bounds (raster pixels) | Local disk |
| --- | --- |
| [1600, 276, 1634, 293] | center [1613, 279], radius 3 |
| [1600, 401, 1634, 419] | center [1612, 404], radius 3 |
| [1600, 528, 1634, 545] | center [1616, 531], radius 3 |

The combined interval [1600, 276, 1634, 545] contacts staff cores 1 and 2, so only Violin II and Viola receive the false ownership alternative. The Cello core begins below the interval even though its fermata supplies the third accepted body. Each body includes 27 recorded original shaft pixels; its detached dot is excluded. The footprint/disk panel makes the distinction visible: each whole shape is an open arch, while the radius-3 witness lies in its thick top.

The parent’s complete 39-page/604-band comparison reports one new span, two outward crop expansions and two new foreign-core inclusions. No ordinary component or old preservation alternative is removed and no crop contracts. These are parent-run native results, not a duplicate full-score execution by this reviewer. Exact p10 baseline/candidate analysis and plan excerpts, the comparison, and source/result hashes are retained here. The author's p10 logging-only replay matches the full-run analysis and plan exactly.

Source binding: original Brahms Op. 67 IMSLP93521 PDF SHA256 `662aabfdecb2d125151c984fe1dc866ea068668ee9bb74f23f286f552603c14a`; p10 raster SHA256 `1e8f4a8ce47ffe60bb1309d17470477c3e7fe080248dd2b03f38d31e4ce11cc2`. Page 10 uses the unchanged original native rendering; no saved rectification applies on that page. The candidate Native SHA256 is `6f8a9200324702cc6579dba7455e7c6a0e2686cf6ab1e4606309d48e9196010c`.

All three archived body patches were independently checked byte-for-byte against their recorded rectangles in the original grayscale raster. Existing fixture masks, p35 source-guard failure, bounded V1/V2/V3 reports and delivered outputs remain unchanged. No new fixture or further tuning is introduced in this review.
