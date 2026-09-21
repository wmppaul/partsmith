#!/usr/bin/env python3
"""Compare full native inventories; these diagnostics do not certify parts."""
import argparse
import hashlib
import json
from pathlib import Path


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def stats(page):
    components = page.get("inkComponents") or []
    multiple = [c for c in components if len(c["staffIDs"]) > 1]
    return {"staves": len(page["staves"]), "components": len(components),
            "multiStaffComponents": len(multiple),
            "threeOrMoreStaffComponents": sum(len(c["staffIDs"]) >= 3 for c in multiple)}


def compare(before_path, after_path):
    before = json.loads(Path(before_path).read_text())
    after = json.loads(Path(after_path).read_text())
    b_scores = {s["id"]: s for s in before["scores"]}
    a_scores = {s["id"]: s for s in after["scores"]}
    assert b_scores.keys() == a_scores.keys(), "Both runs must cover the same complete input set"
    scores = []
    for ident, b in b_scores.items():
        a = a_scores[ident]
        assert b["analysisStatus"] == a["analysisStatus"] == "complete", ident
        assert b["sourceSHA256"] == a["sourceSHA256"] == digest(b["path"]), ident
        bi = json.loads(Path(b["inventoryPath"]).read_text())
        ai = json.loads(Path(a["inventoryPath"]).read_text())
        assert bi["sourceSHA256"] == ai["sourceSHA256"] == b["sourceSHA256"], ident
        assert (bi.get("rectifications") or []) == (ai.get("rectifications") or []), "Compare the same display geometry"
        assert len(bi["pages"]) == len(ai["pages"]) == b["pageCount"] == a["pageCount"], ident
        pages = []
        for index, (bp, ap) in enumerate(zip(bi["pages"], ai["pages"])):
            assert bp["pageIndex"] == ap["pageIndex"] == index, ident
            for key in ("pageWidth", "pageHeight", "imageWidth", "imageHeight"):
                assert bp[key] == ap[key], (ident, index + 1, key)
            old_lines = [s["staffLineFractions"] for s in bp["staves"]]
            new_lines = [s["staffLineFractions"] for s in ap["staves"]]
            pages.append({"page": index + 1, "staffGeometryIdentical": old_lines == new_lines,
                          "before": stats(bp), "after": stats(ap)})
        totals = {version: {key: sum(p[version][key] for p in pages)
                            for key in pages[0][version]} for version in ("before", "after")}
        scores.append({"id": ident, "source": b["path"], "sourceSHA256": b["sourceSHA256"],
                       "pages": len(pages), "totals": totals,
                       "staffGeometryChangedPages": [p["page"] for p in pages if not p["staffGeometryIdentical"]],
                       "pageDiagnostics": pages, "qualityStatus": "requires_source_and_output_review"})
    return {"schemaVersion": 1, "scope": before["scope"], "inputPDFs": len(scores),
            "inputPages": sum(s["pages"] for s in scores),
            "beforeExecutableSHA256": before["nativeExecutableSHA256"],
            "afterExecutableSHA256": after["nativeExecutableSHA256"],
            "beforeAggregateSHA256": digest(before_path), "afterAggregateSHA256": digest(after_path),
            "interpretation": "A connected component touching multiple staves can be structural or real music. Reductions are diagnostics, not proof of target-note preservation, correct identity, or readable extraction.",
            "qualityStatus": "not_proven_by_inventory_comparison", "scores": scores}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    result = compare(args.before, args.after)
    Path(args.out).write_text(json.dumps(result, indent=2) + "\n")
    changes = sum(len(s["staffGeometryChangedPages"]) for s in result["scores"])
    counts = [sum(s["totals"][v]["multiStaffComponents"] for s in result["scores"])
              for v in ("before", "after")]
    print(f"{result['inputPDFs']} PDFs / {result['inputPages']} pages; {changes} changed staff geometries; multi-staff components {counts[0]} -> {counts[1]}")
