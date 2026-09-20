#!/usr/bin/env python3
"""Report every independent target-envelope violation before expensive pixel QA.

This checks reviewed source regions, not inferred note ownership. It does not
declare musical completeness, clean isolation, or final visual approval.
"""
import argparse
import hashlib
import json
from pathlib import Path


def check(directory, source_map):
    manifest = json.loads((directory / "manifest.json").read_text())
    mapping = json.loads(source_map.read_text())
    assert manifest["sourceSHA256"] == mapping["sourceSHA256"]
    guards = {(p["pageIndex"] + 1, s["systemIndex"] + 1, b["partID"]): b["protectedRegions"]
              for p in mapping["pages"] for s in p.get("systems", []) for b in s["bands"]}
    violations, checked, seen = [], 0, set()
    for part in manifest["parts"]:
        assert hashlib.sha256((directory / part["file"]).read_bytes()).hexdigest() == part["sha256"]
        for band in part["placements"]:
            identity = (band["sourcePage"], band["system"], part["id"])
            assert identity not in seen
            seen.add(identity)
            crop = band["sourceRect"]
            for guard in guards[identity]:
                checked += 1
                rect = guard["rect"]
                clearance = [rect[0] - crop[0], rect[1] - crop[1], crop[2] - rect[2], crop[3] - rect[3]]
                if min(clearance) < -0.0001:
                    violations.append({"bandID": band["id"], "sourceRect": crop, "guard": guard,
                                       "clearancePointsLeftTopRightBottom": clearance})
    assert seen == set(guards), "Missing or extra source bands"
    return {"status": "fail" if violations else "pass", "bands": len(seen), "regions": checked,
            "sourceSHA256": manifest["sourceSHA256"],
            "sourceMapSHA256": hashlib.sha256(source_map.read_bytes()).hexdigest(),
            "manifestSHA256": hashlib.sha256((directory / "manifest.json").read_bytes()).hexdigest(),
            "violations": violations}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("source_map", type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    result = check(args.directory, args.source_map)
    args.out.write_text(json.dumps(result, indent=2) + "\n")
    print(f"{result['status']}: {result['bands']} bands, {result['regions']} regions, {len(result['violations'])} violations")
    raise SystemExit(0 if result["status"] == "pass" else 1)
