# Independent forward test: Notte e giorno — complete piano part

Operator: score_survey subagent, independent of maintained skill author. Source is the complete four-page Mutopia piano/vocal score already in the repository. Runtime: `.build/extraction-venv/bin/python`; maintained skill script invoked directly. No maintained project files or score PDFs were altered by this test.

## Actual progression

1. Read SKILL.md and recipe reference. Ran analyze on all four pages. Visually checked every numbered analysis page. Staff counts were exactly correct: 13,15,15,15. Piano mapping was explicitly 1–2,3–4,6–7,9–10,12–13 on page1, then 2–3,5–6,8–9,11–12,14–15 on pages2–4. This is important because the first two systems have no printed vocal staff.
2. Built all20 piano systems using unions of suggested staff rectangles. The script succeeded, but the five-page PDF was not acceptable: many English vocal-lyric fragments remained; bar20's Ob. cue/trill top and bar46's slur tops were cut; bar42's final low bass notehead was cut; several bottom edges included fragments of the next vocal system's bar numbers/stage text. Retained `v1/` evidence.
3. Adjusted top/bottom coordinates against source. Found four vertically inseparable overlaps (page2 systems3/4/5 and page3 system1). Built and inspected a faithful five-page fallback retaining full vocal context for those four systems. It preserved all target notes but was not strictly piano-only. Retained `context/` evidence.
4. Skill author introduced optional per-band exclusions in response to the demonstrated overlap. Prepared seven narrow source-space masks, leaving the piano treble clefs, central slur apex and high chord/accidental intact. All four masked passage tops were compared with source at 288dpi. The first implementation left faint clipped-lyric remnants at the crop-top boundary because whiteout fill edges were antialiased; reported this upstream.
5. Removed redundant labels for opening systems and retained original source page divisions. This fits five complete grand staffs on each of four Letter pages, avoiding the initial orphan final system. Every final page is rendered at144dpi, with the difficult mask regions additionally inspected at288dpi.

## Exact geometry corrections

Recipe `recipe-clean.json` is authoritative. All coordinates are top-down source PDF points. All bands use x=20 to569. Top/bottom ranges:

- PDF page1: 69.5–168,174–274,349.1–442,519–618,691.5–801.
- PDF page2: 94–179,247–332,399–486,554.5–660,720–831.
- PDF page3: 89.5–179,250–346,409.5–502,570.5–670,737–831.
- PDF page4: 95.5–181,247–334.2,402–502,574–661,727–825.

Source exclusions:

- p2s3: [54,399,568,405]. Only lower English lyric fragments; piano clef is to the left.
- p2s4: [54,554.5,86,561.7] and [360,554.5,568,561.7]. Keeps the central piano slur untouched.
- p2s5: [55,720,132,726.5] and [478,720,550,726.5]. Removes two distant vocal lyric clusters, keeping both piano slurs.
- p3s1: [55,89.5,510,95.2] and [541.8,89.5,568,95.2]. Keeps the high piano chord/accidental between the masks; the final vocal “se” begins at x542.354.

## Coverage and musical review

Twenty strips, each with both piano staves. Complete bars1–73, source system starts:
1,5,10,15,20 / 24,27,29,32,36 / 39,42,44,46,48 / 50,56,61,64,70.

Review explicitly checked:
- opening Molto allegro and oboe/strings/bassoon cues;
- bar10 grand-staff fermatas, lower-staff slur, and all triplet engraving;
- bar20 Ob./Fag./trill and lowest bass ledger note;
- source page2 grand-staff sustained notes and slurs;
- source page3 bass-clef changes in the upper staff, the lowest bass note at bar43, and return to treble;
- bar46 top slurs/trill;
- source page4 bass-staff ledger notes, cresc., Tutti. and final chord/rest;
- source bar sequence, no missing or duplicate grand staffs.

No transposition, interpretation or re-engraving was attempted. Output is faithful to this source's piano reduction. Voice lyrics and stage directions are deliberately not part of the final piano-only output.

The four original source page divisions are preserved. This avoids introducing additional page turns; it does not guarantee a pianist can turn printed pages without assistance at Molto allegro. A digital display/page turner is a reasonable performance choice. The app currently may paginate differently and editorial source-bar labels may be PDF-only, so re-export requires renewed layout review.

## Concrete workflow findings

- Detection passed this variable staff-count case, but instrument identity required a reviewed system map.
- Suggested crop rectangles are draft starting points. Correct staff counts do not imply safe musical boundaries.
- Bilingual lyrics and piano clefs/slurs can overlap vertically, requiring reviewed local exclusions or retained context.
- Original page breaks plus less redundant annotation can materially improve pagination.
- High-resolution local inspection mattered: faint crop-edge text remnants were obvious at288dpi even when page thumbnails looked clean.
- Build and native-package creation worked. Exclusions are serialized in project.json; app open/export is tested separately by the parent task.
- Portable copied recipe.source and text-fit fixes were authored upstream during this test, not by the forward-test operator.

## Final outcome

The crop-edge bleed correction removed all remaining top-edge lyric artifacts. The final four-page PDF was re-rendered and every page inspected again. Its seven masked crop-edge strips contain zero dark pixels in the automated 288dpi regression check. Three critical notation regions (treble clef, central slur, high chord/accidental) are pixel-identical to the unmasked source placement. Review record was accepted by `verify`, marking this exact PDF reviewed. The manifest and review.json contain the final SHA256.

Regression script to retain/adapt: `/tmp/partsmith-forward/regression_review.py`. Its two meaningful assertions are (1) zero dark pixels in the narrow top-edge region of every mask and (2) exact equality to an unmasked source placement for three independently chosen target-notation regions. The latter ensures fixes do not make the mask test pass by deleting nearby music.
