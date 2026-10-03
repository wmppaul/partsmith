"""Read-only verification of frozen manual crop proposals; no Auto or export."""
import hashlib
import json
from pathlib import Path

repo = Path(__file__).resolve().parents[3]
report = Path(__file__).resolve().parent
read = lambda p: json.loads(p.read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
binding = read(report / "source-context-binding.json")
delivery = repo / binding["delivery"]
assert sha(Path(binding["source"])) == binding["sourceSHA256"]
assert sha(repo / binding["correctedSource"]) == binding["correctedSourceSHA256"]
assert sha(delivery / "manifest.json") == binding["manifestSHA256"]
assert sha(delivery / "plan.json") == binding["planSHA256"]
project = delivery / "Brahms String Quartet No. 3 Op. 67 — Auto draft.partsmithproject" / "project.json"
assert sha(project) == binding["projectSHA256"]
assert read(project)["project"]["pageRectifications"] == binding["rectifications"]
assert len(binding["rectifications"]) == 9
for context in binding["contexts"]:
    assert sha(repo / context["image"]) == context["imageSHA256"]
assert sha(report / "immutable-ten-source-guards.json") == binding["immutableTenGuardsSHA256"]
assert sha(report / "immutable-thirteen-local-obligations.json") == binding["immutableLocalObligationsSHA256"]
frozen = read(report / "frozen-source-obligations-sha256.json")
assert sha(repo / frozen["path"]) == frozen["sha256"]

manifest = read(delivery / "manifest.json")
rows = {band["id"]: band for part in manifest["parts"] for band in part["placements"]}
proposal = read(report / "manual-proposals-v1.json")
manual = {p["bandID"]: p["proposedRect"] for p in proposal["proposals"]}
assert len(rows) == 604 and len(manual) == 7
assert sum(len(row["sourceMarkings"]) for row in rows.values()) == 42
for p in proposal["proposals"]:
    assert p["currentRect"] == rows[p["bandID"]]["sourceRect"]
    for image in p["images"]:
        assert sha(repo / image["path"]) == image["sha256"]
    assert sha(repo / p["comparisonImage"]) == p["comparisonSHA256"]

def contains(crop, box):
    return crop[0] <= box[0] and crop[1] <= box[1] and crop[2] >= box[2] and crop[3] >= box[3]

def crop(band_id, changed):
    return manual.get(band_id, rows[band_id]["sourceRect"]) if changed else rows[band_id]["sourceRect"]

guards = read(report / "immutable-ten-source-guards.json")["guards"]
for changed in [False, True]:
    failures = [g["bandID"] for g in guards if not contains(crop(g["bandID"], changed), g["rect"])]
    assert failures == ["p35-s1-violin1"]
for target in read(report / "frozen-source-obligations.json")["targetRegions"]:
    assert contains(crop(target["bandID"], True), target["rect"])
owners = {"Viola": "viola", "Cello": "cello", "Violin I": "violin1", "Violin II": "violin2"}
local = read(report / "immutable-thirteen-local-obligations.json")["protectedMusicalRegions"]
assert len(local) == 13
for obligation in local:
    band_id = f'p{obligation["page"]}-s{2 if obligation["page"] == 24 else 1}-{owners[obligation["owner"]]}'
    assert contains(crop(band_id, True), obligation["pdfBounds"])
neighbor_counts = []
for changed in [False, True]:
    count = 0
    for band_id, band in rows.items():
        rect = crop(band_id, changed)
        for other_id, other in rows.items():
            if other_id != band_id and other["sourcePage"] == band["sourcePage"]:
                count += sum(rect[1] <= min(lines) and rect[3] >= max(lines) for lines in other["staffLineYs"])
    neighbor_counts.append(count)
assert neighbor_counts == [7, 0]
print("PASS: input hashes, 9 rectifications, 7 target regions, 13 local obligations; unchanged 9/10 guard result, 7→0 whole-neighbor cores. No project edit or export.")
