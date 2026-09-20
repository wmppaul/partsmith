"""Reviewed source structure, separate from the detector under test.

Manual observations below came from every full source page. Generated overrides
reuse native staff geometry: only instrumentation changes and shared directions
are supplied. This script must not infer expected counts from detected counts.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
SOURCES = json.loads((HERE / "sources.json").read_text())

COUNTS = {"ave": [2] * 4, "notte": [5] * 4,
          "schumann": [4] + [5] * 13 + [4, 4]}
MOVEMENTS = {
    "ave": [(1, 1, "Adagio")],
    "notte": [],
    "schumann": [
        (1, 1, "1. Seit ich ihn gesehen — Larghetto"),
        (2, 3, "2. Er, der Herrlichste von allen — Innig, lebhaft"),
        (5, 3, "3. Ich kann's nicht fassen, nicht glauben — Mit Leidenschaft"),
        (7, 1, "4. Du Ring an meinem Finger — Innig"),
        (9, 1, "5. Helft mir, ihr Schwestern — Ziemlich schnell"),
        (11, 1, "6. Süßer Freund, du blickest — Langsam, mit innigem Ausdruck"),
        (13, 1, "7. An meinem Herzen, an meiner Brust — Fröhlich, innig"),
        (15, 1, "8. Nun hast du mir den ersten Schmerz getan — Adagio"),
    ],
}
# Boxes below are measured against inspected 120-dpi source images (860x1250).
# They contain only the direction, not substituted or reconstructed music.
SCHUMANN_MARKINGS = [
    (5, 4, "Etwas langsamer.", [553, 701, 700, 724], ["piano"]),
    (6, 2, "Adagio.", [466, 294, 535, 312], ["piano"]),
    (8, 1, "Nach und nach rascher.", [412, 89, 594, 110], ["piano"]),
    (12, 1, "Lebhafter.", [497, 147, 582, 168], ["voice"]),
    (12, 5, "ritard.", [501, 975, 554, 997], ["voice"]),
    (12, 5, "Adagio.", [609, 980, 680, 1002], ["voice"]),
    (14, 1, "Schneller. / a tempo", [451, 78, 540, 113], ["piano"]),
    (14, 3, "Noch schneller.", [460, 511, 585, 533], ["piano"]),
    (14, 3, "Presto.", [460, 582, 527, 602], ["voice"]),
    (14, 4, "Langsamer.", [700, 790, 792, 810], ["voice"]),
    (16, 2, "Adagio.", [177, 445, 244, 466], ["voice"]),
    (16, 2, "Tempo wie das erste Lied.", [328, 449, 536, 471], ["voice"]),
]


def write(name, value):
    (HERE / name).write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def main():
    for key in COUNTS:
        source = SOURCES[key]
        profile = json.loads((HERE / f"{key}-profile.json").read_text())
        inv = json.loads((ROOT / f".build/full-score-inventory-v7/{key}/inventory.json").read_text())
        count = COUNTS[key]
        physical = [n * sum(p["staffCount"] for p in profile["parts"]) for n in count]
        if key == "notte":
            physical[0] = 13
        assert [len(p["staves"]) for p in inv["pages"]] == physical, (key, "Detector count differs from independent source map")
        markings = []
        if key == "schumann":
            markings = [{"pageIndex": p - 1, "systemIndex": s - 1, "text": text,
                         "rect": [round(x * 0.6, 2) for x in rect], "targetPartIDs": targets}
                        for p, s, text, rect, targets in SCHUMANN_MARKINGS]
        observed = {
            "ave": "All four source pages inspected. Eight printed staves per system, including the combined Basso ed Organo staff. Preserve choral text, organ tasto solo and multi-line figured bass; no invented separate organ realization.",
            "notte": "All four source pages inspected. First two systems contain piano alone (bars 1–9); retain labeled piano cues for the voice. Remaining 18 systems have Voice plus grand staff. Preserve both lyric languages, stage directions, orchestral cues in the piano reduction, final bar 73.",
            "schumann": "All sixteen source pages inspected. Complete eight-song cycle, 77 systems, voice plus piano grand staff in every system, including printed vocal rests in postludes. Preserve lyrics, piano pedal directions, ledger bass, high slurs, all shared tempi. The two printed directions Noch schneller and Presto remain distinct. Page 10 system 4 has ritard/a tempo printed in both parts already.",
        }[key]
        structure = {"schemaVersion": 1, "source": source["source"],
                     "sourceSHA256": hashlib.sha256((ROOT / source["source"]).read_bytes()).hexdigest(),
                     "notationPolicy": "preserve-target", "reviewStatus": "source_structure_reviewed_output_pending",
                     "profile": profile, "expectedSystemCount": sum(count),
                     "expectedPhysicalStaffCount": sum(physical),
                     "movements": [{"pageIndex": p - 1, "systemIndex": s - 1, "label": label} for p, s, label in MOVEMENTS[key]],
                     "sharedMarkings": markings, "sourceObservations": observed,
                     "pages": [{"pageIndex": i, "expectedSystems": n, "expectedPhysicalStaves": physical[i]} for i, n in enumerate(count)]}
        write(f"{key}-map.json", structure)
        overrides = []
        for page in inv["pages"]:
            pi = page["pageIndex"]
            page_movements = [m for m in structure["movements"] if m["pageIndex"] == pi]
            page_markings = [m for m in markings if m["pageIndex"] == pi]
            if not page_movements and not page_markings and not (key == "notte" and pi == 0):
                continue
            systems, offset = [], 0
            for si in range(count[pi]):
                bands = []
                if key == "notte" and pi == 0 and si < 2:
                    ids = [offset, offset + 1]
                    bands = [{"partID": "voice", "candidateIDs": ids, "kind": "cue",
                              "label": f"Piano introduction — voice tacet, bars {'1–4' if si == 0 else '5–9'}"},
                             {"partID": "piano", "candidateIDs": ids}]
                    offset += 2
                else:
                    for part in profile["parts"]:
                        bands.append({"partID": part["id"], "candidateIDs": list(range(offset, offset + part["staffCount"]))})
                        offset += part["staffCount"]
                for band in bands:
                    rects = [m["rect"] for m in page_markings if m["systemIndex"] == si and band["partID"] in m["targetPartIDs"]]
                    if rects:
                        band["sourceMarkings"] = rects
                system = {"systemIndex": si, "bands": bands}
                if movement := next((m for m in page_movements if m["systemIndex"] == si), None):
                    system["movementLabel"] = movement["label"]
                    if key == "schumann" and (pi != 0 or si != 0):
                        for band in bands:
                            band["pageBreakBefore"] = True
                systems.append(system)
            overrides.append({"pageIndex": pi, "reason": "Reviewed instrumentation/section/shared-direction metadata; crop geometry remains generated by the native detector and profile.", "systems": systems})
        write(f"{key}-overrides.json", overrides)


if __name__ == "__main__":
    main()
