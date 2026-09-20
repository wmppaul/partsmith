#!/usr/bin/env python3
"""Measure neighboring staff-line context in native crops (not musical correctness).

Counts use detected line heights at the page center. Skew can leave a fragment
near an edge even when that center is outside the crop. Copied shared markings
are intentionally excluded; their rectangles need separate visual review.
"""
import argparse
import hashlib
import json
from pathlib import Path


def measure(directory, inventory_path):
    directory = Path(directory)
    manifest = json.loads((directory / "manifest.json").read_text())
    inventory = json.loads(Path(inventory_path).read_text())
    assert manifest["sourceSHA256"] == inventory["sourceSHA256"]
    pages = {p["pageIndex"] + 1: p for p in inventory["pages"]}
    results = []
    for part in manifest["parts"]:
        assert hashlib.sha256((directory / part["file"]).read_bytes()).hexdigest() == part["sha256"]
        bands = []
        for band in part["placements"]:
            page = pages[band["sourcePage"]]
            top, bottom = band["sourceRect"][1::2]
            neighbors = []
            for staff in page["staves"]:
                if staff["id"] in band["candidateIDs"]:
                    continue
                lines = sum(top <= y * page["pageHeight"] <= bottom for y in staff["staffLineFractions"])
                if lines:
                    neighbors.append({"staffID": staff["id"], "lineCount": lines})
            bands.append({"id": band["id"], "heightPoints": bottom - top,
                          "neighborLineCount": sum(n["lineCount"] for n in neighbors),
                          "wholeNeighborStaves": sum(n["lineCount"] == 5 for n in neighbors),
                          "neighbors": neighbors})
        results.append({"partID": part["id"], "name": part["name"], "outputSHA256": part["sha256"],
                        "outputPages": part["outputPages"], "bands": bands,
                        "meanCropHeightPoints": sum(b["heightPoints"] for b in bands) / len(bands),
                        "neighborLineCount": sum(b["neighborLineCount"] for b in bands),
                        "wholeNeighborStaves": sum(b["wholeNeighborStaves"] for b in bands)})
    return {"sourceSHA256": manifest["sourceSHA256"],
            "method": "Detected neighboring line centers intersecting the main crop; approximate context metric, not proof of target preservation or clean isolation.",
            "parts": results,
            "neighborLineCount": sum(p["neighborLineCount"] for p in results),
            "wholeNeighborStaves": sum(p["wholeNeighborStaves"] for p in results)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory")
    parser.add_argument("--inventory", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    result = measure(args.directory, args.inventory)
    Path(args.out).write_text(json.dumps(result, indent=2) + "\n")
    print(f"{result['neighborLineCount']} neighboring line centers; {result['wholeNeighborStaves']} whole neighboring staves")
