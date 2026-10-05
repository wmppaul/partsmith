"""Compare a native rest run against the independent Mozart source expectations.

This checks assignments, exact source geometry and rest eligibility, and renders
every PDF page for a separate visual review. It is not a substitute for reading
the rendered rest counts, clefs and directions.
"""
import argparse
import hashlib
import json
from pathlib import Path
import pymupdf

parser = argparse.ArgumentParser()
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--fixture", type=Path, required=True)
parser.add_argument("--review", type=Path, required=True)
parser.add_argument("--allow-abstentions", action="store_true",
                    help="Record missed eligible rests explicitly, while still rejecting any false positive")
args = parser.parse_args()
args.review.mkdir(parents=True, exist_ok=True)
package = args.output / args.fixture.name
before = json.loads((args.fixture / "project.json").read_text())["project"]
after = json.loads((package / "project.json").read_text())["project"]
source_hash = hashlib.sha256((args.fixture / "source.pdf").read_bytes()).hexdigest()
assert hashlib.sha256((package / "source.pdf").read_bytes()).hexdigest() == source_hash
assert len(before["bands"]) == len(after["bands"]) == 72
by_id = {b["id"]: b for b in after["bands"]}
assert set(by_id) == {b["id"] for b in before["bands"]}
names = {p["id"]: p["name"] for p in before["parts"]}
positive = []
abstentions = []
for part in before["parts"]:
    bands = sorted([b for b in before["bands"] if b["partID"] == part["id"]],
                   key=lambda b: (b["pageIndex"], b["topFraction"]))
    assert len(bands) == 8
    for index, original in enumerate(bands):
        new = by_id[original["id"]]
        expected = index == 0 and part["name"] in {
            "Flute", "Clarinet in A", "Bassoon", "French Horn in A", "Piano"
        } or index == 7 and part["name"] in {"Flute", "Clarinet in A", "French Horn in A"}
        rest = new.get("restReplacement")
        assert not rest or expected, (part["name"], index + 1, "false positive compression", rest)
        if expected and not rest:
            abstentions.append({"part": part["name"], "system": index + 1, "eligibleBarCount": 5})
        for key in ("pageIndex", "partID", "topFraction", "bottomFraction", "leftFraction",
                    "rightFraction", "excluded", "sourceMarkings", "editorialLabel", "exclusions"):
            assert new.get(key) == original.get(key), (part["name"], index + 1, key, "changed")
        if original.get("generatedRest"):
            assert new["generatedRest"]["barCount"] == original["generatedRest"]["barCount"]
            assert new["generatedRest"].get("startBarNumber") == original["generatedRest"].get("startBarNumber")
        if rest:
            assert rest["barCount"] == 5
            positive.append({"part": part["name"], "system": index + 1, "barCount": rest["barCount"]})
assert len(positive) + len(abstentions) == 8
assert not abstentions or args.allow_abstentions, abstentions
assert {("Clarinet in A", 1), ("Piano", 1)} <= {(p["part"], p["system"]) for p in positive}
pdfs = []
for part in before["parts"]:
    path = args.output / f"{part['name']}.pdf"
    assert path.exists(), path
    doc = pymupdf.open(path)
    for index, page in enumerate(doc):
        page.get_pixmap(matrix=pymupdf.Matrix(1.5, 1.5)).save(
            args.review / f"{part['name']}-p{index+1}.png")
    pdfs.append({"part": part["name"], "pages": len(doc),
                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
report = {"sourceSHA256": source_hash, "originalItemsRetained": 72,
          "partCount": 9, "sourceGeometryAndMarkingsUnchanged": True,
          "positiveWholeRestStrips": positive,
          "musicallyEligibleWholeRestStrips": 8,
          "eligibleButNotCompressed": abstentions,
          "mixedAndPlayingStripsPreserved": True, "pdfs": pdfs,
          "visualReviewStatus": "pending separate image inspection"}
(args.review / "output-structure-check.json").write_text(json.dumps(report, indent=2) + "\n")
print(f"PASS:72 source items,{len(positive)} of8 eligible rest strips detected,{len(abstentions)} abstentions; all playing controls unchanged; nine-part PDFs rendered.")
