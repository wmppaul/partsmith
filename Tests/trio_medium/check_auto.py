#!/usr/bin/env python3
"""Check fresh native Auto coverage and independently measured upper marks.

Run after regenerating the medium-scan inventory and Compact plan. These
source measurements exercise actual clipping cases; passing is not a claim
that all musical marks have been recognized automatically.
"""
import argparse
import json
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("inventory")
parser.add_argument("plan")
args = parser.parse_args()
here = Path(__file__).resolve().parent
expected = json.loads((here / "source-layout.json").read_text())
inventory = json.loads(Path(args.inventory).read_text())
plan = json.loads(Path(args.plan).read_text())
assert inventory["sourceSHA256"] == expected["sourceSHA256"], "Wrong source variant"
assert len(inventory["pages"]) == len(expected["pages"]) == 35
for actual, source in zip(inventory["pages"], expected["pages"]):
    assert actual["pageIndex"] == source["pageIndex"]
    assert len(actual["staves"]) == source["expectedPhysicalStaves"]
bands = {(p["pageIndex"], b["systemIndex"], b["partID"]): b
         for p in plan["pages"] for b in p["assignments"]}
expected_keys = {(p["pageIndex"], s, part)
                 for p in expected["pages"] for s in range(p["expectedSystems"])
                 for part in ("clarinet", "cello", "piano")}
assert bands.keys() == expected_keys, "Missing or duplicate part coverage"
assert sum(len(p["assignments"]) for p in plan["pages"]) == 393
assert all(not p["unresolvedReasons"] for p in plan["pages"])
clearances = []
for landmark in json.loads((here / "upper-mark-landmarks.json").read_text()):
    page_index = landmark["page"] - 1
    band = bands[(page_index, landmark["system"] - 1, "piano")]
    top = band["topFraction"] * inventory["pages"][page_index]["pageHeight"]
    clearance = landmark["firstTargetInkY"] - top
    assert clearance > 1, f"Insufficient crown/ascender clearance: {band['id']}: {clearance}pt"
    clearances.append({"id": band["id"], "targetClearancePoints": clearance})
print(json.dumps({"status": "pass", "sourcePages": 35, "physicalStaves": 524,
                  "musicSystems": 131, "partBands": 393, "upperMarks": clearances}, indent=2))
