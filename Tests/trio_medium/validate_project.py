#!/usr/bin/env python3
"""Read-only consistency check for the reviewed medium-scan Trio project.

Run with the repository's extraction Python environment. This checks the saved
project and source contract; it does not replace source/output visual review.
Prints one JSON result and exits nonzero on failure. It never stamps or edits PDFs.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

import pymupdf


ROOT = Path(__file__).resolve().parents[2]
TOLERANCE = 0.0001  # PDF points; accommodates PDFKit/PyMuPDF float serialization.


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def equal_rect(actual, expected, context):
    require(len(actual) == len(expected) == 4, f"{context}: invalid rectangle")
    require(all(math.isfinite(v) for v in [*actual, *expected]),
            f"{context}: nonfinite rectangle")
    require(all(abs(a - b) < TOLERANCE for a, b in zip(actual, expected)),
            f"{context}: rectangles differ: {actual} != {expected}")


def rect(item, size):
    return [item.get("leftFraction", 0) * size.width,
            item["topFraction"] * size.height,
            (1 - item.get("rightFraction", 0)) * size.width,
            item["bottomFraction"] * size.height]


def unique(items, key, context):
    result = {key(item): item for item in items}
    require(len(result) == len(items), f"{context}: duplicate identity")
    return result


def validate(folder, map_path):
    manifest_path, plan_path = folder / "manifest.json", folder / "plan.json"
    manifest, plan, source_map = read(manifest_path), read(plan_path), read(map_path)
    project = folder / manifest["project"]
    model_path = project / "project.json"
    model = read(model_path)["project"]
    watched = [manifest_path, plan_path, map_path, model_path, project / "source.pdf"]
    hashes = {path: sha(path) for path in watched}
    source_path = Path(source_map["source"])
    source_path = source_path if source_path.is_absolute() else ROOT / source_path
    require(sha(source_path) == source_map["sourceSHA256"] == manifest["sourceSHA256"]
            == hashes[project / "source.pdf"], "Original/embedded source hashes differ")
    require(not model.get("pageRectifications"), "Unexpected rectification changes source coordinates")
    require(model["pageCount"] == len(source_map["pages"]) == 35, "Expected 35 source pages")
    require(len(model["parts"]) == len(manifest["parts"]) == len(plan["parts"]) == 3,
            "Expected exactly three parts")
    require(len(model["bands"]) == 393, "Expected exactly 393 saved bands")
    require(source_map["expectedSystems"] == 131, "Expected 131 systems per part")
    require(all(not b.get("excluded") and not b.get("exclusions") for b in model["bands"]),
            "Saved project contains excluded bands or whiteout masks")
    unique(model["bands"], lambda b: b["id"], "Saved bands")
    native_parts = unique(model["parts"], lambda p: p["name"], "Saved part names")
    native_ids = unique(model["parts"], lambda p: p["id"], "Saved part IDs")
    require(all(b["partID"] in native_ids for b in model["bands"]), "Unassigned saved band")

    profile = manifest["profile"]
    setup = dict(model["projectSettings"]["instrumentationSetup"])
    setup["parts"] = setup.pop("instruments")
    require(setup == profile, "Saved instrumentation/crop settings differ from manifest")
    require(plan["parts"] == profile["parts"], "Plan instrumentation differs from saved setup")
    # The source review uses printed/long names such as Violoncello; the saved
    # profile may use Cello. Stable IDs and staff counts establish its identity.
    require([(p["id"], p["staffCount"]) for p in source_map["parts"]]
            == [(p["id"], p["staffCount"]) for p in profile["parts"]],
            "Source-map instrumentation differs from saved setup")

    mapped_pages = unique(source_map["pages"], lambda p: p["pageIndex"], "Source-map pages")
    planned_pages = unique(plan["pages"], lambda p: p["pageIndex"], "Plan pages")
    require(set(mapped_pages) == set(planned_pages) == set(range(35)), "Incomplete page accounting")
    planned = unique([b for p in plan["pages"] for b in p["assignments"]],
                     lambda b: b["id"], "Planned bands")
    mapped = {}
    nonmusic = []
    for index, page in mapped_pages.items():
        proposed = planned_pages[index]
        require(not proposed["unresolvedReasons"], f"Source page {index + 1}: unresolved assignments")
        require(len(page["systems"]) == page["expectedSystems"],
                f"Source page {index + 1}: source-map system count differs")
        if page["classification"] != "music":
            nonmusic.append(index + 1)
            require(not proposed["assignments"] and not page["systems"],
                    f"Non-music page {index + 1} has bands")
            require({o["partID"] for o in proposed["omissions"]} == {p["id"] for p in plan["parts"]}
                    and all(o.get("reason", "").strip() for o in proposed["omissions"]),
                    f"Non-music page {index + 1}: missing explicit exclusion reasons")
        else:
            require(not proposed["omissions"], f"Music page {index + 1}: omitted part")
        for system in page["systems"]:
            for band in system["bands"]:
                key = (index, system["systemIndex"], band["partID"])
                require(key not in mapped, f"Duplicate source-map band {key}")
                mapped[key] = band
                require(not band.get("exclusions"), f"Source-map band {key} has masks")
    require(len(planned) == len(mapped) == 393, "Plan/source-map band count differs")
    require(nonmusic == [34, 35], "Unexpected non-music page exclusions")

    seen, marking_count, guard_count, outputs = set(), 0, 0, []
    with pymupdf.open(project / "source.pdf") as source_pdf:
        require(len(source_pdf) == 35, "Embedded PDF page count differs")
        for part in manifest["parts"]:
            require(part["name"] in native_parts, f"Missing saved part {part['name']}")
            native = native_parts[part["name"]]
            stored = sorted((b for b in model["bands"] if b["partID"] == native["id"]),
                            key=lambda b: (b["pageIndex"], b["topFraction"]))
            placements = part["placements"]
            require(len(stored) == len(placements) == part["bandCount"] == 131,
                    f"{part['name']}: expected 131 bands")
            expected_order = sorted(key for key in mapped if key[2] == part["id"])
            actual_order = [(p["sourcePage"] - 1, p["system"] - 1, part["id"]) for p in placements]
            require(actual_order == expected_order, f"{part['name']}: source reading order differs")
            for band, placement, key in zip(stored, placements, actual_order):
                identity = placement["id"]
                require(identity not in seen and identity in planned, f"Duplicate/unknown placement {identity}")
                seen.add(identity)
                proposed, reviewed = planned[identity], mapped[key]
                require((proposed["pageIndex"], proposed["systemIndex"], proposed["partID"]) == key,
                        f"{identity}: plan instrument/system identity differs")
                require(band["pageIndex"] == key[0], f"{identity}: saved source page differs")
                require(proposed["candidateIDs"] == reviewed["candidateIDs"] == placement["candidateIDs"],
                        f"{identity}: staff assignment differs")
                size = source_pdf[key[0]].rect
                for value, label in ((rect(band, size), "saved"), (rect(proposed, size), "planned"),
                                     (reviewed["sourceRect"], "source-map")):
                    equal_rect(value, placement["sourceRect"], f"{identity} {label} crop")
                require(band.get("editorialLabel", "") == proposed.get("editorialLabel", "")
                        == placement["editorialLabel"], f"{identity}: editorial label differs")
                require(band.get("pageBreakBefore", False) == proposed.get("pageBreakBefore", False),
                        f"{identity}: explicit page break differs")
                for guard in reviewed.get("protectedRegions", []):
                    crop, protected = placement["sourceRect"], guard["rect"]
                    require(crop[0] <= protected[0] + TOLERANCE and crop[1] <= protected[1] + TOLERANCE
                            and crop[2] >= protected[2] - TOLERANCE and crop[3] >= protected[3] - TOLERANCE,
                            f"{identity}: source protected region exceeds saved crop")
                    guard_count += 1
                fragments = placement["sourceMarkings"]
                fragment_sets = [(list(map(lambda x: rect(x, size), band.get("sourceMarkings", []))), "saved"),
                                 (list(map(lambda x: rect(x, size), proposed.get("sourceMarkings", []))), "planned"),
                                 (reviewed.get("sourceMarkings", []), "source-map")]
                for values, label in fragment_sets:
                    require(len(values) == len(fragments), f"{identity}: {label} source-marking count differs")
                    for value, fragment in zip(values, fragments):
                        equal_rect(value, fragment["sourceRect"], f"{identity} {label} source marking")
                marking_count += len(fragments)
            output_path = folder / part["file"]
            require(sha(output_path) == part["sha256"], f"{part['file']}: PDF hash differs from manifest")
            hashes[output_path] = part["sha256"]
            with pymupdf.open(output_path) as pdf:
                require(len(pdf) == part["outputPages"], f"{part['file']}: output page count differs")
            outputs.append({k: part[k] for k in ("name", "file", "sha256", "outputPages", "bandCount")})
    require(seen == set(planned), "Plan contains undelivered bands")
    require(all(sha(path) == digest for path, digest in hashes.items()), "Inputs changed during validation; rerun")
    return {"status": "pass", "scope": "Editable project consistency; does not certify visual music review",
            "sourcePages": 35, "musicPages": 33, "explicitNonMusicPages": nonmusic,
            "parts": 3, "bands": 393, "protectedRegions": guard_count, "sourceMarkings": marking_count,
            "excludedBands": 0, "whiteoutMasks": 0, "savedInstrumentation": "matches manifest and source map",
            "sourceSHA256": manifest["sourceSHA256"], "manifestSHA256": hashes[manifest_path],
            "planSHA256": hashes[plan_path], "sourceMapSHA256": hashes[map_path],
            "projectJSONSHA256": hashes[model_path], "outputs": outputs}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder", type=Path, default=ROOT / "output/pdf/brahms-trio-medium")
    parser.add_argument("--source-map", type=Path, default=ROOT / "Tests/trio_medium/source-map.json")
    args = parser.parse_args()
    try:
        result = validate(args.folder, args.source_map)
    except (ValueError, KeyError, TypeError, OSError, IndexError) as error:
        print(json.dumps({"status": "fail", "error": str(error)}, indent=2))
        return 1
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
