#!/usr/bin/env python3
"""Combine independently reviewed source geometry with the current native Auto.

Use explicit context-cleanup recommendations, preserve all source guards, and
record every manual rectangle separately from automatic geometry.
"""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("inventory")
parser.add_argument("plan")
args = parser.parse_args()
here = Path(__file__).resolve().parent
read = lambda p: json.loads(Path(p).read_text())
inventory, automatic = read(args.inventory), read(args.plan)
layout = read(here / "source-layout.json")
reviews = [read(here / name) for name in
           ("clarinet-cello-source-review.json", "piano-source-review.json")]
assert all(r["sourceSHA256"] == inventory["sourceSHA256"] == layout["sourceSHA256"] for r in reviews)
evidence = {(b["pageIndex"], b["systemIndex"], b["partID"]): b for r in reviews for b in r["bands"]}
assert len(evidence) == 393
extra_path = here / "additional-context-corrections.json"
extra_cleanup = {b["id"] for b in read(extra_path)} if extra_path.exists() else set()
assert extra_cleanup <= {f"p{p+1}-s{s+1}-{part}" for p, s, part in evidence}
contains = lambda outer, inner: all((outer[i] <= inner[i] + 1e-5) if i < 2 else
                                   (outer[i] >= inner[i] - 1e-5) for i in range(4))
shared = [dict(c) for r in reviews for c in r.get("sharedMarkings", [])]
# Independent second review isolated these bar digits from a tiny brace tip.
gutter_right = {(7, 1): 40.5, (7, 3): 42.0, (8, 0): 20.1, (9, 2): 30.1,
                (10, 0): 19.1, (10, 1): 20.25, (15, 1): 35.9, (24, 3): 27.7}
for cue in shared:
    if cue["label"].startswith("Bar ") and (cue["pageIndex"], cue["systemIndex"]) in gutter_right:
        cue["rect"] = list(cue["rect"])
        cue["rect"][2] = gutter_right[(cue["pageIndex"], cue["systemIndex"])]
    cue["text"], cue["targetPartIDs"] = cue["label"], cue["partIDs"]
movements = {0: "I. Allegro", 11: "II. Adagio", 17: "III. Andante grazioso", 25: "IV. Allegro"}
mapping = {**layout, "status": "independent source review complete; export review pending",
           "notationPolicy": "preserve-target", "sharedMarkings": shared, "pages": []}
overrides, decisions = [], []
for page, source_page, auto_page in zip(inventory["pages"], layout["pages"], automatic["pages"]):
    pi, width, height = page["pageIndex"], page["pageWidth"], page["pageHeight"]
    mapped_page = {**source_page, "systems": []}
    mapping["pages"].append(mapped_page)
    if not source_page["expectedSystems"]:
        reason = "Source-reviewed blank page" if pi == 33 else "Source-reviewed publisher catalog"
        overrides.append({"pageIndex": pi, "reason": reason, "nonMusicReason": reason, "systems": []})
        continue
    override_page = {"pageIndex": pi, "reason": "Fresh medium-scan source review; unchanged detected staff identities; explicit crop and shared-marking corrections listed per band.", "systems": []}
    overrides.append(override_page)
    for si in range(source_page["expectedSystems"]):
        system, override_system = {"systemIndex": si, "bands": []}, {"systemIndex": si, "bands": []}
        mapped_page["systems"].append(system)
        override_page["systems"].append(override_system)
        if pi in movements and si == 0:
            override_system["movementLabel"] = movements[pi]
        for auto in [b for b in auto_page["assignments"] if b["systemIndex"] == si]:
            part = auto["partID"]
            reviewed = evidence[(pi, si, part)]
            assert reviewed["candidateIDs"] == auto["candidateIDs"]
            rect = [auto["leftFraction"] * width, auto["topFraction"] * height,
                    (1 - auto["rightFraction"]) * width, auto["bottomFraction"] * height]
            guards = [{"rect": list(g["rect"]), "description": g.get("description", g.get("label", "Reviewed target envelope"))} for g in reviewed["protectedRegions"]]
            # MuPDF exposes the PDF's 595.2pt width as a float32 value. Normalize
            # only its <0.0001pt representation error to native PDFKit bounds.
            for guard in guards:
                if guard["rect"][2] > width:
                    assert guard["rect"][2] - width < 0.0001
                    guard["rect"][2] = width
            misses = [g for g in guards if not contains(rect, g["rect"])]
            cleanup = auto["id"] in extra_cleanup or reviewed.get("materialContextCleanupRecommended", False) or any(
                "material neighboring" in c for c in reviewed.get("classification", []))
            override = {"partID": part, "candidateIDs": auto["candidateIDs"]}
            if cleanup:
                rect = list(reviewed["suggestedRect"])
                rect[2] = min(rect[2], width)
            elif misses:
                rect[1] = min(rect[1], min(g["rect"][1] for g in misses) - 0.5)
                rect[3] = max(rect[3], max(g["rect"][3] for g in misses) + 0.5)
            assert all(contains(rect, g["rect"]) for g in guards), auto["id"]
            if cleanup or misses:
                override["rect"] = rect
                decisions.append({"id": auto["id"], "reason": "material neighboring context" if cleanup else "conservative source guard margin", "rect": rect})
            cues = [c["rect"] for c in shared if c["pageIndex"] == pi and c["systemIndex"] == si and part in c["partIDs"] and not contains(rect, c["rect"])]
            if cues:
                override["sourceMarkings"] = cues
            if pi in movements and si == 0:
                override["pageBreakBefore"] = True
            override_system["bands"].append(override)
            system["bands"].append({"partID": part, "candidateIDs": auto["candidateIDs"], "sourceRect": rect,
                                     "protectedRegions": guards, "sourceMarkings": cues,
                                     "exclusions": [], "observations": reviewed.get("observations", ""),
                                     "neighborNotation": reviewed.get("neighborContext", "Small neighboring fragments may remain when target notation requires the same height.")})
mapping["manualCropDecisions"] = decisions
for name, value in (("source-map.json", mapping), ("overrides.json", overrides)):
    (here / name).write_text(json.dumps(value, indent=2) + "\n")
print(json.dumps({"bands": len(evidence), "manualRectangles": len(decisions),
                  "contextCleanup": sum(d["reason"] == "material neighboring context" for d in decisions),
                  "sourceGuardExpansions": sum(d["reason"] != "material neighboring context" for d in decisions),
                  "sharedSourceMarkings": len(shared)}, indent=2))
