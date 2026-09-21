#!/usr/bin/env python3
"""Refresh exact local input metadata; requires PyMuPDF, never changes source PDFs."""
import collections
import datetime
import hashlib
import json
from pathlib import Path
import re
import pymupdf

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Tests/quality_control"


def main():
    (OUT / "profiles").mkdir(parents=True, exist_ok=True)
    originals = sorted((ROOT / "sample_scores").rglob("*.pdf"))
    excerpts = sorted((ROOT / "Tests/extraction/sources").glob("*.pdf"))
    old = json.loads((ROOT / "Tests/full_scores/sources.json").read_text())
    historic = {row["source"]: (key, row) for key, row in old.items()}
    additions = {}
    for name in ("corpus-profile-additions.json", "profile-additions-2.json"):
        for row in json.loads((OUT / name).read_text())["additions"]:
            assert row["id"] not in additions, "Duplicate source initialization registry entry"
            additions[row["id"]] = dict(row, registry=name)
    scores = []
    for path in sorted(originals + excerpts):
        relative = str(path.relative_to(ROOT))
        excerpt = path in excerpts
        family = "excerpt" if excerpt else path.relative_to(ROOT).parts[1]
        slug = re.sub("[^a-z0-9]+", "-", path.stem.lower()).strip("-")
        score_id = family.replace("_", "-") + "-" + slug
        with pymupdf.open(path) as document:
            pages = len(document)
            scan_pages = sum(bool(page.get_images()) for page in document)
        row = {
            "id": score_id, "path": relative,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes": path.stat().st_size, "pageCount": pages,
            "corpusFamily": family,
            "sourceKind": "lossless_excerpt" if excerpt else "original_download",
            "renderContent": "raster_scan" if scan_pages == pages else "vector_or_mixed",
            "instrumentation": "not_yet_verified", "profilePath": None,
            "profileEvidence": None, "legacyEvidence": [],
            "currentReviewStatus": "not_run_or_visually_reviewed",
            "evaluationRequirements": [
                "Every physical PDF page analyzed, including covers, blanks and movement boundaries.",
                "All intended staves and outlying target notation retained; staff-count divisibility alone is insufficient.",
                "Part identity/order and every system reconciled against the source.",
                "Full output rendered and independently reviewed; generated bands are not proof of correctness."
            ]
        }
        profile = None
        if family in ("lightly_skewed", "medium_skewed"):
            row["scanVariantNote"] = "Separate downloaded edition/filter/scan identified in sibling shortlist; not a synthetically distorted copy. Evaluate independently."
        if relative in historic:
            key, previous = historic[relative]
            map_name = "brahms-" + key if key in ("quartet", "trio") else key
            row["legacyEvidence"] = ["Tests/full_scores/" + map_name + "-map.json"]
            row["instrumentation"] = "fixed_profile_previously_reviewed"
            profile = {"parts": previous["profile"]["parts"], "cropMode": "compact"}
            for part in profile["parts"]:
                if part["id"] in ("voice", "soprano", "alto", "tenore", "basso"):
                    part["hasLyrics"] = True
            row["profileEvidence"] = "Instrument identity/order from Tests/full_scores/sources.json; compact crop mode with no historical padding or crop overrides."
        if "114012" in path.name:
            row["instrumentation"] = "fixed_profile_previously_reviewed"
            row["profilePath"] = "Tests/trio_medium/profile.json"
            row["profileEvidence"] = "Existing full 35-page medium Trio source review."
            row["legacyEvidence"] = ["Tests/trio_medium/source-layout.json", "Tests/trio_medium/source-map.json"]
        if "kv488_mvt1" in path.name or path.name == "mozart-k488-page-17.pdf":
            row["instrumentation"] = "variable_verified"
            fixture = "Tests/extraction/mozart-variable-instrumentation-fixtures.json"
            profile = json.loads((ROOT / fixture).read_text())["profile"]
            row["profileEvidence"] = "Nine instruments from existing Mozart variable-instrumentation fixtures. Explicit system assignment required."
            row["legacyEvidence"] = [fixture]
            row["evaluationRequirements"].append("Each omitted instrument needs a counted rest span; do not apply a fixed staff cadence.")
        if "op67_mvt2_mutopia1437" in path.name:
            row["instrumentation"] = "variable_documented"
            row["profileEvidence"] = "sample_scores/rest_detection/README.md documents omitted silent staves."
        if any(name in path.name for name in ("la_boheme", "hear_my_prayer", "gesang_der_parzen", "brahms_2_motets", "symphony_no1", "concertpiece", "egmont", "magic_flute", "symphony_no18", "op67_complete")):
            row["instrumentation"] = "variable_or_movement_changes_require_review"
            row["evaluationRequirements"].append("Verify instrument roster in each system/movement; a single fixed profile has not been established for this complete source.")
        if "kv488_flute" in path.name:
            row["instrumentation"] = "single_part"
            profile = {"parts": [{"id": "flute", "name": "Flute", "staffCount": 1}], "cropMode": "compact"}
            row["profileEvidence"] = "Publisher flute part named on pages; existing rest README visually reviewed page 1."
            row["evaluationRequirements"].append("Preserve printed multibar-rest counts and context. One compressed symbol is not one bar. Preserve incomplete finale material as supplied.")
        if score_id in additions:
            initialized = additions[score_id]
            assert initialized["sourceSHA256"] == row["sha256"], "Reviewed profile source changed"
            profile_path = ROOT / initialized["profilePath"]
            assert hashlib.sha256(profile_path.read_bytes()).hexdigest() == initialized["profileSHA256"], "Reviewed initialization changed"
            row["profilePath"] = initialized["profilePath"]
            row["instrumentation"] = initialized["instrumentation"]
            row["profileEvidence"] = "Source-render initialization recorded in Tests/quality_control/" + initialized["registry"] + "; consult its explicit scope and roster limitations."
            row["profileSHA256"] = initialized["profileSHA256"]
            if "rosterStatus" in initialized:
                row["rosterStatus"] = initialized["rosterStatus"]
            row["profileSourcePagesCheckedOneBased"] = initialized["sourcePagesVisuallyCheckedOneBased"]
            row["evaluationRequirements"].extend(initialized.get("knownExceptions", []))
        elif profile is not None:
            profile_path = OUT / "profiles" / (score_id + ".json")
            profile_path.write_text(json.dumps(profile, indent=2, ensure_ascii=False) + "\n")
            row["profilePath"] = str(profile_path.relative_to(ROOT))
        if excerpt:
            metadata = json.loads(path.with_suffix(".json").read_text())
            row["derivedFrom"] = {
                "sha256": metadata["originalPDFSHA256"],
                "sourcePagesOneBased": metadata.get("originalPDFPages", [metadata.get("originalPDFPage")]),
                "method": metadata["method"]
            }
            if "beethoven" in path.name:
                row["instrumentation"] = "fixed_excerpt_only"
            row["evaluationRequirements"].append("Excerpt regression only; completion does not establish full-source coverage.")
        scores.append(row)
    for row in scores:
        if "derivedFrom" in row:
            parent = next(other for other in scores if other["sha256"] == row["derivedFrom"]["sha256"])
            row["derivedFrom"]["path"] = parent["path"]
    by_hash = collections.defaultdict(list)
    for row in scores:
        by_hash[row["sha256"]].append(row["path"])
    summary = {
        "inputPDFs": len(scores), "inputPages": sum(row["pageCount"] for row in scores),
        "originalPDFs": len(originals),
        "originalPages": sum(row["pageCount"] for row in scores if row["sourceKind"] == "original_download"),
        "excerptPDFs": len(excerpts),
        "duplicateHashes": [paths for paths in by_hash.values() if len(paths) > 1],
        "profilesAvailable": sum(row["profilePath"] is not None for row in scores)
    }
    output = {
        "schemaVersion": 1,
        "scope": "Every PDF in sample_scores recursively plus Tests/extraction/sources. Excludes generated extraction outputs, app bundles, build artifacts and exported parts elsewhere.",
        "inventoryDate": datetime.date.today().isoformat(), "summary": summary,
        "limitations": [
            "Corpus metadata is not detector accuracy evidence.",
            "Existing profiles initialize instrument identity manually; they do not test OCR name discovery.",
            "Raw inventory CLI does not execute Magic Wand rectification before detection.",
            "Legacy reviewed maps and overrides need separate hash binding and review before reuse."
        ], "scores": scores
    }
    (OUT / "corpus.json").write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
