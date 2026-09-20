#!/usr/bin/env python3
"""Reproduce real-score fidelity controls without modifying production PDFs.

Requires the final score sets, PyMuPDF/NumPy/Pillow, and macOS swiftc/CoreGraphics.
Run with .build/extraction-venv/bin/python Tests/full_scores/test_pixel_comparator.py.
Generated fixture PDFs, logs, and result JSON live under .build by default.
"""
import argparse
import contextlib
import copy
import hashlib
import importlib.util
import io
import json
from pathlib import Path

import pymupdf as fitz

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("score_reviewer", ROOT / "tools/review_score_output.py")
reviewer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(reviewer)


def recorded_path(path):
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path.resolve())


def transform_region(region, placement):
    source = fitz.Rect(placement["sourceRect"])
    destination = fitz.Rect(placement["destinationRect"])
    scale = destination.width / source.width
    return fitz.Rect(destination.x0 + (region.x0 - source.x0) * scale,
                     destination.y0 + (region.y0 - source.y0) * scale,
                     destination.x0 + (region.x1 - source.x0) * scale,
                     destination.y0 + (region.y1 - source.y0) * scale)


def run_case(base, sets, name, score, part_id, source_page, damage=None):
    original = sets / score
    manifest = json.loads((original / "manifest.json").read_text())
    map_name = f"brahms-{score}" if score in {"trio", "quartet"} else score
    mapping = json.loads((ROOT / f"Tests/full_scores/{map_name}-map.json").read_text())
    part = copy.deepcopy(next(p for p in manifest["parts"] if p["id"] == part_id))
    original_pdf_path = original / part["file"]
    original_pdf_digest = reviewer.digest(original_pdf_path)
    placement = copy.deepcopy(next(p for p in part["placements"]
                                   if p["sourcePage"] == source_page and p["system"] == 1))
    page = next(p for p in mapping["pages"] if p["pageIndex"] == source_page - 1)
    system = next(s for s in page["systems"] if s["systemIndex"] == 0)
    band = copy.deepcopy(next(b for b in system["bands"] if b["partID"] == part_id))
    work = base / name
    work.mkdir(parents=True, exist_ok=True)
    report_path = work / "review/pixel-fidelity.json"
    # A guard rejection occurs before a pixel report is written. Remove only
    # this harness's previous report so a rerun cannot reuse stale evidence.
    report_path.unlink(missing_ok=True)

    with fitz.open(original_pdf_path) as pdf:
        pdf.select([placement["outputPage"] - 1])
        placement["outputPage"] = 1
        if damage == "note":
            # Visually verified first entering Clarinet triplet note, Trio p2s1.
            region = transform_region(fitz.Rect(248, 79, 257, 91), placement)
            pdf[0].draw_rect(region, color=None, fill=(1, 1, 1), overlay=True)
        elif damage == "cue":
            region = fitz.Rect(placement["sourceMarkings"][0]["destinationRect"])
            pdf[0].draw_rect(region, color=None, fill=(1, 1, 1), overlay=True)
        elif damage == "vector_staff":
            region = transform_region(fitz.Rect(band["protectedRegions"][0]["rect"]), placement)
            pdf[0].draw_rect(region, color=None, fill=(1, 1, 1), overlay=True)
        elif damage == "crop":
            source, destination = placement["sourceRect"], placement["destinationRect"]
            scale = (destination[2] - destination[0]) / (source[2] - source[0])
            source[1] = band["protectedRegions"][0]["rect"][1] + 1
            destination[3] = destination[1] + (source[3] - source[1]) * scale
        elif damage is not None:
            raise ValueError(damage)
        fixture = work / part["file"]
        pdf.save(fixture)

    part.update(placements=[placement], bandCount=1, outputPages=1, sha256=reviewer.digest(fixture))
    manifest["parts"] = [part]
    manifest["status"] = "isolated_regression_fixture"
    manifest.pop("reviewRecord", None)
    (work / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    mapping["pages"] = [{"pageIndex": source_page - 1, "expectedSystems": 1,
                         "systems": [{"systemIndex": 0, "bands": [band]}]}]
    (work / "map.json").write_text(json.dumps(mapping, indent=2, ensure_ascii=False) + "\n")
    log = io.StringIO()
    error = None
    try:
        with contextlib.redirect_stdout(log):
            reviewer.review(work, work / "map.json", True)
    except AssertionError as exception:
        error = str(exception)
        log.write(error + "\n")
    log_path = work / "review.log"
    log_path.write_text(log.getvalue())
    report = json.loads(report_path.read_text()) if report_path.exists() else None
    if report is not None:
        assert report["sourceMapSHA256"] == reviewer.digest(work / "map.json")
        assert report["normalizedManifestSHA256"] == reviewer.normalized_manifest_digest(manifest)
    assert reviewer.digest(original_pdf_path) == original_pdf_digest, "Production PDF changed"
    result = {"case": name, "expected": "fail" if damage else "pass",
              "actual": "fail" if error else "pass", "error": error,
              "differentPixels": sum(r["differentPixels"] for r in report["regions"]) if report else None,
              "report": recorded_path(report_path) if report else None,
              "log": recorded_path(log_path)}
    if damage == "crop":
        assert error and error.startswith("Crop cuts protected target:"), result
    elif damage:
        assert report and report["status"] == "fail" and result["differentPixels"] > 0, result
    else:
        assert not error and report and report["status"] == "pass", result
    return result


def binding_controls(sets):
    manifest = json.loads((sets / "trio/manifest.json").read_text())
    clean = {key: value for key, value in manifest.items() if key not in {"status", "reviewRecord"}}
    expected = hashlib.sha256(json.dumps(clean, sort_keys=True, separators=(",", ":"),
                                        ensure_ascii=False).encode("utf-8")).hexdigest()
    assert reviewer.normalized_manifest_digest(manifest) == expected
    stamped = copy.deepcopy(manifest)
    stamped.update(status="reviewed", reviewRecord={"reviewer": "Regression test — not a real approval"})
    assert reviewer.normalized_manifest_digest(stamped) == expected
    changed = copy.deepcopy(manifest)
    changed["parts"][0]["placements"][0]["sourceRect"][1] += 0.01
    assert reviewer.normalized_manifest_digest(changed) != expected
    return {"normalizationMatchesSpecification": True, "reviewStateStampDoesNotInvalidate": True,
            "placementChangeInvalidates": True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sets-dir", type=Path, default=ROOT / "output/pdf/full-score-sets")
    parser.add_argument("--output-dir", type=Path, default=ROOT / ".build/pixel-comparator-regressions")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    bindings = binding_controls(args.sets_dir)
    cases = [("real-trio-positive", "trio", "clarinet", 2, None),
             ("removed-clarinet-note", "trio", "clarinet", 2, "note"),
             ("crop-cuts-protected-target", "trio", "clarinet", 2, "crop"),
             ("removed-shared-tempo", "quartet", "violin2", 1, "cue"),
             ("real-vector-positive", "ave", "soprano", 1, None),
             ("removed-vector-staff", "ave", "soprano", 1, "vector_staff")]
    results = [run_case(args.output_dir, args.sets_dir, *case) for case in cases]
    (args.output_dir / "regression-results.json").write_text(json.dumps(results, indent=2) + "\n")
    (args.output_dir / "binding-control-results.json").write_text(json.dumps(bindings, indent=2) + "\n")
    print(json.dumps({"regressions": results, "bindingControls": bindings}, indent=2))


if __name__ == "__main__":
    main()
