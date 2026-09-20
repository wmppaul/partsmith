#!/usr/bin/env python3
"""Bind completed human reviews and passing automated checks to the frozen corpus.

This does not review music. Run only after the named independent review reports
are complete; their exact output hashes must already match every delivered PDF.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil

import pymupdf

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "output/pdf/full-score-sets"
FIXTURES = ROOT / "Tests/full_scores"
SCORES = ["ave", "notte", "quartet", "schumann", "trio"]
MAPS = {key: f"{key}-map.json" for key in SCORES}
MAPS.update(quartet="brahms-quartet-map.json", trio="brahms-trio-map.json")
REVIEWS = {key: ["small-score-independent-review.md"] for key in SCORES}
REVIEWS.update(quartet=["brahms-quartet-review.md", "quartet-independent-review.md"],
               trio=["brahms-trio-review.md", "trio-independent-review.md"])


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def normalized_manifest(data):
    value = copy.deepcopy(data)
    value.pop("status", None)
    value.pop("reviewRecord", None)
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"),
                                     ensure_ascii=False).encode()).hexdigest()


def main(validate_only=False):
    prepared = []
    for key in SCORES:
        folder = BASE / key
        manifest_path = folder / "manifest.json"
        m = read(manifest_path)
        compact = m["profile"].get("cropMode") == "compact"
        map_name = ({"ave": "ave-tight-map.json", "quartet": "brahms-quartet-tight-map.json"}.get(key)
                    if compact else None) or MAPS[key]
        review_names = (["ave-compact-final-review.md" if key == "ave" else "quartet-compact-independent-review.md"]
                        if compact and key in ("ave", "quartet") else REVIEWS[key])
        original = copy.deepcopy(m)
        geometry = read(folder / "review/geometry.json")
        fidelity = read(folder / "review/pixel-fidelity.json")
        map_hash = sha(FIXTURES / map_name)
        manifest_hash = normalized_manifest(m)
        for report in (geometry, fidelity):
            assert report["sourceMapSHA256"] == map_hash, (key, "Stale reviewed source map")
            assert report["normalizedManifestSHA256"] == manifest_hash, (key, "Stale placement review")
        assert fidelity["status"] == "pass", (key, "Fidelity review failed")
        assert geometry["status"] == "geometry_pass_visual_review_pending"
        assert m["sourceSHA256"] == geometry["sourceSHA256"] == fidelity["sourceSHA256"]
        assert sha(Path(m["source"])) == m["sourceSHA256"]
        project = folder / m["project"]
        assert sha(project / "source.pdf") == m["sourceSHA256"]
        model = read(project / "project.json")["project"]
        assert len(model["parts"]) == len(m["parts"])
        assert len(model["bands"]) == sum(p["bandCount"] for p in m["parts"])
        assert model["projectSettings"]["instrumentationSetup"]["instruments"] == m["profile"]["parts"]
        assert all(not b.get("exclusions") and not b.get("excluded") for b in model["bands"])
        plan = read(folder / "plan.json")
        planned = {b["id"]: b for page in plan["pages"] for b in page["assignments"]}
        with pymupdf.open(project / "source.pdf") as source_pdf:
            for part in m["parts"]:
                native_parts = [p for p in model["parts"] if p["name"] == part["name"]]
                assert len(native_parts) == 1, (key, "Ambiguous native project part")
                stored = sorted((b for b in model["bands"] if b["partID"] == native_parts[0]["id"]),
                                key=lambda b: (b["pageIndex"], b["topFraction"]))
                assert len(stored) == len(part["placements"])
                for band, placement in zip(stored, part["placements"]):
                    assert band["pageIndex"] == placement["sourcePage"] - 1
                    page_size = source_pdf[band["pageIndex"]].rect
                    def source_rect(item):
                        return [item.get("leftFraction", 0) * page_size.width,
                                item["topFraction"] * page_size.height,
                                (1 - item.get("rightFraction", 0)) * page_size.width,
                                item["bottomFraction"] * page_size.height]
                    assert all(abs(a-b) < 0.0001 for a, b in zip(source_rect(band), placement["sourceRect"])), \
                        (key, placement["id"], "Editable project crop differs from PDF manifest")
                    assert band.get("editorialLabel", "") == placement["editorialLabel"]
                    assert band.get("pageBreakBefore", False) == planned[placement["id"]]["pageBreakBefore"]
                    fragments = band.get("sourceMarkings", [])
                    assert len(fragments) == len(placement["sourceMarkings"])
                    for fragment, checked in zip(fragments, placement["sourceMarkings"]):
                        assert all(abs(a-b) < 0.0001 for a, b in zip(source_rect(fragment), checked["sourceRect"])), \
                            (key, placement["id"], "Editable project marking differs from PDF manifest")
        placements = {(b["sourcePage"] - 1, b["system"] - 1, p["id"]): b
                      for p in m["parts"] for b in p["placements"]}
        crop_corrections = []
        for page in m["reviewedOverrides"]:
            for system in page.get("systems", []):
                for band in system["bands"]:
                    if band.get("rect"):
                        key_tuple = (page["pageIndex"], system["systemIndex"], band["partID"])
                        placement = placements[key_tuple]
                        assert all(abs(a-b) < 0.0001 for a, b in zip(band["rect"], placement["sourceRect"])), \
                            (key, placement["id"], "Reviewed correction differs from delivered geometry")
                        crop_corrections.append(placement["id"])
        review_text = "\n".join((FIXTURES / name).read_text() for name in review_names)
        generation = folder / "generation-manifest.json"
        if generation.exists():
            assert normalized_manifest(read(generation)) == manifest_hash, (key, "Generation changed after review")
        visual = folder / "visual-review.json"
        visual_data = read(visual) if visual.exists() else None
        if visual_data:
            assert visual_data["status"] == "visual-review-pass", (key, "Visual review failed")
            assert visual_data["manifestSHA256"] == sha(manifest_path), (key, "Stale visual manifest binding")
            assert visual_data["sourceMapSHA256"] == map_hash, (key, "Stale visual source-map binding")
            assert visual_data["sourceSHA256"] == m["sourceSHA256"]
        else:
            assert map_hash in review_text, (key, "Missing independent source-map review binding")
        for p in m["parts"]:
            assert sha(folder / p["file"]) == p["sha256"] == fidelity["outputs"][p["file"]]
            assert p["sha256"] in review_text, (key, p["name"], "Missing independent review binding")
            with pymupdf.open(folder / p["file"]) as pdf:
                assert len(pdf) == p["outputPages"]
                for index, page in enumerate(pdf):
                    footer = page.get_text(clip=pymupdf.Rect(0, 756, 612, 792)).strip()
                    assert footer == f"{index + 1} / {len(pdf)}"
        m["status"] = "reviewed — target preservation and complete-page layout pass"
        m["reviewRecord"] = "review-record.json"
        before, after = copy.deepcopy(original), copy.deepcopy(m)
        for value in (before, after):
            value.pop("status", None)
            value.pop("reviewRecord", None)
        assert before == after, "Finalization must not change musical content or geometry"
        record = {
            "status": "pass", "notationPolicy": "preserve-target",
            "sourceSHA256": m["sourceSHA256"], "sourceMapSHA256": map_hash,
            "sourceMap": f"../evidence/{map_name}",
            "visualReviewReports": [f"../evidence/{name}" for name in review_names],
            "scope": "Every source band and final output page reviewed; target preservation and remaining neighboring context assessed separately.",
            "limits": "Manual instrument setup and shared-direction review. Explicit crop corrections are counted below; these are reviewed native exports, not unattended musical interpretation or performance-tested page turns.",
            "manualStaffPositionCorrections": 0, "explicitCropRectangleOverrides": len(crop_corrections),
            "correctedBandIDs": crop_corrections,
            "whiteoutMasks": 0, "pageFooterChecks": sum(p["outputPages"] for p in m["parts"]),
            "geometryReport": "geometry-review.json", "fidelityReport": "pixel-fidelity.json",
            "fidelityReportSHA256": sha(folder / "review/pixel-fidelity.json"),
            "parts": [{k: p[k] for k in ("name", "file", "sha256", "bandCount", "outputPages")} for p in m["parts"]],
        }
        prepared.append((key, m, record, visual_data))

    # Validation above completes for every score before publishing any status.
    # Pagination changes when reviewed crops improve. Coverage is invariant;
    # actual page counts were checked against every PDF and footer above.
    assert (sum(len(m["parts"]) for _, m, _, _ in prepared),
            sum(p["bandCount"] for _, m, _, _ in prepared for p in m["parts"])) == (19, 1131)
    if validate_only:
        print(json.dumps({"status": "ready_for_finalization", "parts": 19, "bands": 1131,
                          "outputPages": sum(r["pageFooterChecks"] for _, _, r, _ in prepared),
                          "explicitCropRectangleOverrides": {key: record["explicitCropRectangleOverrides"]
                                                             for key, _, record, _ in prepared}}, indent=2))
        return
    evidence = BASE / "evidence"
    evidence.mkdir(exist_ok=True)
    for path in FIXTURES.iterdir():
        if path.suffix in (".json", ".md"):
            shutil.copy2(path, evidence / path.name)
    for key, m, record, visual_data in prepared:
        folder = BASE / key
        manifest_path = folder / "manifest.json"
        generation = folder / "generation-manifest.json"
        if not generation.exists():
            shutil.copy2(manifest_path, generation)
        write(manifest_path, m)
        record["manifestSHA256"] = sha(manifest_path)
        record["generationManifestSHA256"] = sha(generation)
        visual = folder / "visual-review.json"
        if visual_data:
            data = visual_data
            data.setdefault("reviewedGenerationManifestSHA256", data["manifestSHA256"])
            data["manifestSHA256"] = sha(manifest_path)
            data["metadataFinalization"] = "Only manifest status/reviewRecord changed; all original geometry and PDF hashes verified unchanged. Original manifest retained."
            write(visual, data)
        shutil.copy2(folder / "review/geometry.json", folder / "geometry-review.json")
        shutil.copy2(folder / "review/pixel-fidelity.json", folder / "pixel-fidelity.json")
        write(folder / "review-record.json", record)
    summary = {
        "status": "pass", "parts": sum(len(m["parts"]) for _, m, _, _ in prepared),
        "outputPages": sum(r["pageFooterChecks"] for _, _, r, _ in prepared),
        "partBands": sum(p["bandCount"] for _, m, _, _ in prepared for p in m["parts"]),
        "sourcePDFPages": 84, "physicalMusicStaves": 1357,
        "independentReview": "Complete source/crop and final-page reviews; exact hashes bound in per-set records.",
        "scores": {key: f"{key}/review-record.json" for key in SCORES},
    }
    write(BASE / "review-summary.json", summary)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sets-dir", type=Path, default=BASE)
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    BASE = args.sets_dir.resolve()
    main(args.validate_only)
