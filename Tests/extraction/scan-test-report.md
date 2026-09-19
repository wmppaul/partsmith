# Brahms scan: bounded independent forward test — FAILED CLEAN-PART REVIEW

The scan test did not produce a verified clean Violin I part. The conservative draft is intentionally left `draft_needs_visual_review`. It contains neighboring musical fragments, so it is not a performance-ready deliverable.

## Tested scope and evidence

- Source: repository medium-skewed Brahms String Quartet No.3 Op.67 IMSLP09200, PDF pages1–3 only.
- Expected and detected physical staff counts:16,20,20. Expected Violin I systems:4,5,5 (14 total).
- System starts:1/8/17/24;29/34/39/45/50;58/66/75/85/92. Scope ends before bar99 on PDFpage4.
- All three source pages, all14 source crop ribbons, and both pages of the experimental and final draft PDFs were visually inspected.
- Higher-resolution source details were inspected at288dpi, plus selected small details at720dpi. Extra sampling does not add detail to the original low-resolution binary scan; it only makes its source pixels easier to inspect.
- Final machine-readable failed review: `review-failed.json`. It contains the exact draft PDF SHA256, all14 band IDs, and11 source-coordinate issue regions.
- CLI verify correctly rejected this report because `cropEdges` fails and page turns are not assessed. Status remains draft. It was not overridden.

## What was tried

The initial broad rectangle recipe preserves most first-violin notation but also includes second-violin notes, beams, slurs and markings, plus some preceding-system cello fragments. The original page3 system2 top boundary (189pt) clips the high first-violin slur over the final bars; expanding it to182pt restores that slur.

A single cleanup pass proposed35 rectangular exclusions and tighter crop bounds. It substantially reduced neighboring fragments, but visual re-review caught damaged target markings: the final f in page1 system1 became shorter, the initial d in page2 system4's dim. was erased, and the D-box edge in page3 system3 was touched. These are failed edits, not acceptable simplifications. All experimental exclusions were removed from the conservative final draft. The failed experiment is retained separately at `/tmp/partsmith-brahms/v1/` for development evidence.

## Hard passages

- Page2 system3, around bar39: first-violin fp and the second violin's upward flag are separated by a sub-point white gap. Their vertical extents overlap. Source detail: `/tmp/partsmith-brahms/p2s3-fp.png`, region[92,360,120,385]. Rectangular deletion can isolate them only with more exact coordinates than the first pass established.
- Page2 system2: target hairpin and dolce legg. text sit just above second-violin slurs. A globally horizontal lower boundary either retains context or risks text/slur loss.
- Page3 system2: top expansion needed for the high first-violin slur admits preceding-cello fragments; bottom also competes with second-violin slurs.
- Page3 system3: previous cello dynamics/hairpins enter the top envelope around rehearsal D. A wide top mask damages the rehearsal box.
- Page3 system5: second-violin staff/slurs and staccato dots intrude below target p cresc. and low slurs. A clean separation was not verified.

The failed review lists the other affected strips and coordinates. No passage was declared fundamentally impossible to isolate; this bounded pass simply did not establish a safe clean extraction.

## Workflow implications

The review gate worked: correct staff detection, a successful build, and visibly tidier strips did not cause an unsafe result to be marked reviewed. Scan tilt makes neighboring ink vary across x, and small binary pixels leave little margin for rectangular cleanup. The app's close-up before/after mask preview is needed here, ideally supplemented by per-staff normalization or editable contour boundaries. Any future automated masking must validate preservation of specific target dynamics/rehearsal boxes as well as absence of neighboring ink.

The useful output of this test is the reproducible failed case and exact unresolved regions. Deliver the successful digital-score parts separately; keep this scan example clearly labeled as a draft stress test.
