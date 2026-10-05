"""Reproduce the bounded source renders behind the independent rest review.

The existing reviewed map locates systems; the accompanying audit records a
separate visual music review. This script does not classify rests from pixels.
"""
from pathlib import Path
import hashlib
import json
import pymupdf

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Tests/quality_control/mozart_rest_source_review_2026-10-04"
SOURCE = ROOT / "sample_scores/rest_detection/01_full_scores/mozart_piano_concerto_no23_kv488_mvt1_mutopia2229.pdf"
MAP = ROOT / "Tests/quality_control/k488-complete-workflow-2026-10-03/source-reviewed-map.json"
OUT.mkdir(parents=True, exist_ok=True)
doc = pymupdf.open(SOURCE)
systems = json.loads(MAP.read_text())["systems"]
for system in systems[:8]:
    page = doc[system["page"] - 1]
    rect = pymupdf.Rect(0, system["top"], page.rect.width, system["bottom"])
    page.get_pixmap(matrix=pymupdf.Matrix(2, 2), clip=rect).save(
        OUT / f"source-p{system['page']:02}-s{system['system']}.png")
for number in (7, 8):
    doc[number - 1].get_pixmap(matrix=pymupdf.Matrix(1.7, 1.7)).save(
        OUT / f"source-p{number:02}-full.png")

parts = ["Flute", "Clarinet in A", "Bassoon", "French Horn in A", "Piano",
         "Violin I", "Violin II", "Viola", "Cello and Bass"]
# Whole measures silent across every voice/staff of the named part, visually
# checked against all eight source system images. Partial-bar rests excluded.
silent = [
    [list(range(1, 6))] * 5 + [[], [5], [], []],
    [[6, 7, 8]] * 4 + [list(range(6, 11)), [9, 10], [9, 10], [8, 9, 10], [10]],
    [[13], [], [14], [13, 14, 15], list(range(11, 17))] + [[11, 12, 15, 16]] * 4,
    [[], [], [], [], list(range(17, 22))] + [[17]] * 4,
    [[], [], [], [23], list(range(22, 26)), [], [], [], []],
    [[], [], [], [], list(range(26, 30)), [], [], [], []],
    [list(range(31, 35))] * 4 + [list(range(30, 35)), [], [], [], [31, 32]],
    [list(range(35, 40)), list(range(35, 40)), [35, 36, 37], list(range(35, 40)),
     list(range(35, 40)), [], [], [], []],
]
review = {
    "source": str(SOURCE.relative_to(ROOT)),
    "sourceSHA256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    "scope": "First eight systems, measures 1–39; additional entrance check on pages 7–8",
    "method": "Independent visual reading of source renders; pre-existing map supplies location only",
    "systems": [],
    "safeWholeStripResults": {
        "firstSystem": {part: 5 for part in parts[:5]},
        "page4System2": {part: 5 for part in [parts[0], parts[1], parts[3]]},
        "pianoFirstEightSystems": 39,
        "pianoFullOpeningWholeStripChain": 65,
        "pianoFirstSoundingBar": 67,
    },
    "boundaryFindings": [
        "Initial common-time meter, key signatures, clefs and Allegro/TUTTI must remain before opening rest.",
        "No new shared tempo, meter or rehearsal direction inside measures 1–39.",
        "Wind notes start at measure 9; full-strip compression must leave the mixed 6–10 systems unchanged.",
        "Bassoon notes at measures 38–39 prevent compressing its entire Page 4 System 2.",
        "Vel. at33 and Bassi at35 belong to Cello/Bass; a 2. at19 belongs to Bassoon. These are not Piano events.",
        "SOLO is at67 within the printed 66–71 system. That mixed source system must remain, including its one rest at66.",
        "A source page/system break alone is not a musical rest boundary.",
    ],
}
for index, system in enumerate(systems[:8]):
    review["systems"].append({
        "page": system["page"], "system": system["system"],
        "firstBar": system["firstBar"], "barCount": system["barCount"],
        "partSilence": {part: {
            "wholeSilentMeasures": measures,
            "entireSystemSilent": len(measures) == system["barCount"],
            "source": "omitted" if part == "Piano" and index > 0 else "printed",
        } for part, measures in zip(parts, silent[index])},
    })
(OUT / "source-audit.json").write_text(json.dumps(review, indent=2) + "\n")
(OUT / "render-hashes.json").write_text(json.dumps({
    p.name: hashlib.sha256(p.read_bytes()).hexdigest()
    for p in sorted(OUT.glob("source-*.png"))
}, indent=2) + "\n")
