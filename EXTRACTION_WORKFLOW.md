# Part extraction: workflow and evaluation

The result is two parallel workflows: a reusable [ChatGPT/Codex skill](skills/score-part-extraction/SKILL.md), and an improved native macOS application that runs without internet access. They share an editable project format. The skill is installed in the local personal skills directory as `score-part-extraction`.

The previous project state, including unfinished bar-number work, was preserved in commit `6b422ea` before these changes.

## What was tested

| Score and scope | Extracted part | Result |
| --- | --- | --- |
| Mozart, Ave verum corpus, complete four-page score | Soprano; eight systems, bars 1–46 | Reviewed one-page PDF. All lyrics, notes, slurs, opening tempo and source measure numbers retained. |
| Mozart, Notte e giorno, complete four-page score | Piano; twenty grand staffs, bars 1–73 | Reviewed four-page PDF. Seven precise exclusions remove neighboring lyric fragments while preserving nearby notation. Original source page divisions retained. |
| Brahms, Quartet No. 3 Op. 67, medium scan, PDF pages 1–3 | Violin I; fourteen systems, bars 1–98 | Negative stress test. All systems identified, but clean isolation failed visual review. Dense neighboring notes and tilted slurs require further intervention; not delivered as a clean part. |

Reviewed results are [Ave verum](output/pdf/ave) and [Notte e giorno](output/pdf/notte), each containing its PDF, portable recipe, immutable source-embedded project and exact-hash review manifest. Preview PNGs are generated locally but omitted from git. Native re-exports also received visual inspection.

The failed scan is retained locally under `.build/extraction/brahms-draft`, outside the reviewed deliverables. Its reproducible recipe, [failed review](Tests/extraction/brahms-failed-review.json) and [passage report](Tests/extraction/scan-test-report.md) are retained as a negative test. A tidy-looking crop was explicitly rejected when experimental masks damaged target dynamics or a rehearsal box.

## Iterations that changed the implementation

1. Dense beams initially merged staff-line responses. Local maxima and distributed horizontal evidence improved detection. The Python workflow finds all 64/58/56 expected staves across the two complete digital scores and three scan pages. Instrument identity still requires a source-derived map.
2. Correct staff counts still produced clipped lyrics, slurs and dynamics. Every final strip was compared against the source; crop edges were corrected individually. The piano's first two systems have no voice staff, so a repeated modulo assignment would have been wrong.
3. Some vocal lyrics overlap the piano clef's vertical range. Seven spatially precise whiteouts solved the separable cases. High-resolution review found a subpixel residual at coincident crop edges; boundary-only bleed fixed it without expanding interior mask edges.
4. Independent review found native layout could clip staff ends at enlarged scale and overflow tall bands. Export now respects margins, preserves aspect ratio and rejects invalid/missing source geometry explicitly.
5. A final code review found non-ASCII text could turn into question marks, and failed multi-part rebuilds could leave altered PDFs beside an old reviewed manifest. The skill now embeds a Unicode font when needed and stages complete generations before publication. Previous generations remain in returned hidden backup directories.
6. Editorial labels and explicit page breaks now persist into the native project, avoiding silent loss of a supplied tempo/rehearsal cue during local re-export.

The independent piano forward-test narrative is [here](Tests/extraction/forward-test-report.md). It records the historical intermediate limitations as well as the observed musical corrections; the current bridge also preserves labels/page breaks.

## Native app behavior

Import a score, create/select a part, then use **Find Staves**. The offline review sheet shows numbered proposals and line confidence. Select the relevant staves; use two staves per band for a grand staff. Repeated-order selection is available only when the detected count divides into the chosen system size, and still requires checking instrument order. Applying proposals is one undoable edit with duplicate suppression.

Detection uses a background worker with its own PDFKit document, cancellation and stale-result checks. Rectification uses local CoreImage; a failed requested correction cannot silently supply proposals in the wrong coordinate space.

The band inspector provides whiteout areas, editorial labels and page breaks. Preview and export use the same native renderer. The app requires no Python environment, downloaded model, cloud backend or AI service. Different typography can affect pagination relative to the skill, so check native re-exports.

Native detector evaluation covers seventeen source pages and 256 expected staves. The first fourteen pages find all 200 expected staves. The medium quartet yields 16/20/19 raw; applying the existing 0.675-degree correction on page 3 recovers the twentieth staff. These are geometry results, not claims of complete playable extraction. [Exact filenames and findings](Tests/extraction/native-detection-report.md).

## Reproduce the checks

Set up any Python 3.10+ environment with the skill requirements; the local run used `.build/extraction-venv`:

```sh
python3 -m venv .build/extraction-venv
.build/extraction-venv/bin/python -m pip install -r skills/score-part-extraction/scripts/requirements.txt
.build/extraction-venv/bin/python -m unittest discover -s Tests/extraction -v
.build/extraction-venv/bin/python Tests/extraction/regression_review.py output/pdf/notte
bash tools/test_staff_detection.sh --samples
bash tools/test_layout_export.sh
```

Python tests cover actual score counts, source immutability, vector preservation, bounds and coverage validation, portable project coordinates, whiteout transforms, review hashes, Unicode text, and failed/reduced-part rebuilds. Seven mask-edge pixel checks detect residual fragments; three critical clef/slur/chord regions must match an unmasked reference exactly.

All fourteen Python tests pass. Fresh rebuilds using the final skill reproduce all five reviewed output pages pixel-for-pixel at 144 dpi; [comparison record](Tests/extraction/final-rebuild-results.json). Independent agents both operated the skill and reviewed the implementation, with original failure repros rerun after fixes.

Native harnesses pass 5,295 layout assertions and 127 export assertions, covering layout boundaries, tall crops, invalid geometry, explicit page breaks and labels, whiteout persistence, undo/redo, and real piano project re-export. The detector suite separately checks grouping, undo/redo and stale/cancelled detection. Rendering checks compare all pixels outside native masks with the unmasked native renderer. The final native piano export has four pages of five systems each, with all eighteen supplied labels and seven masks preserved; every page received independent visual inspection. The macOS graphics sandbox can prevent CoreImage from rendering; corrected scan benchmarks were verified with ordinary local graphics access.

Debug and Release builds use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project Partsmith.xcodeproj -scheme Partsmith -configuration Release \
  -derivedDataPath .build/DerivedData CODE_SIGNING_ALLOWED=NO build
```

The resulting app is `.build/DerivedData/Build/Products/Release/Partsmith.app`; the local preview archive is [Partsmith-extraction-preview-macos.zip](artifacts/macos/Partsmith-extraction-preview-macos.zip). This is a local unsigned preview build, not a published/notarized release.

## Practical limits

This workflow is robust about preserving source geometry, exposing uncertain results, retaining review evidence and refusing failed output. It is not unattended extraction for arbitrary scores. Staff detection cannot infer all instrument changes, shared markings or tacet duration. Small overlapping fragments can be masked only when the target ink is separately identifiable. Truly interleaved notation, severe scan distortion and musical page-turn planning still need informed review. The retained negative scan test documents that boundary rather than hiding it.
