#!/usr/bin/env python3
"""Package the completed five-score review without scratch previews or old drafts."""
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / "output/pdf/full-score-sets"
DESTINATION = ROOT / "artifacts/Partsmith-complete-score-parts.zip"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


summary = json.loads((BASE / "review-summary.json").read_text())
assert summary["status"] == "pass" and summary["parts"] == 19
for key, filename in summary["scores"].items():
    record = json.loads((BASE / filename).read_text())
    assert record["status"] == "pass"
    assert digest(BASE / key / "manifest.json") == record["manifestSHA256"]
    assert digest(BASE / key / "pixel-fidelity.json") == record["fidelityReportSHA256"]
    for part in record["parts"]:
        assert digest(BASE / key / part["file"]) == part["sha256"]
    manifest = json.loads((BASE / key / "manifest.json").read_text())
    assert digest(BASE / key / manifest["project"] / "source.pdf") == record["sourceSHA256"]

files = [p for p in BASE.rglob("*") if p.is_file()
         and "review" not in p.relative_to(BASE).parts
         and not any(v.startswith(".") for v in p.relative_to(BASE).parts)]
temporary = DESTINATION.with_suffix(".zip.tmp")
with zipfile.ZipFile(temporary, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(files):
        archive.write(path, Path("Partsmith-complete-score-parts") / path.relative_to(BASE))
with zipfile.ZipFile(temporary) as archive:
    assert archive.testzip() is None
    names = archive.namelist()
    assert len([n for n in names if n.endswith(".pdf") and ".partsmithproject/" not in n]) == 19
    assert len([n for n in names if n.endswith(".partsmithproject/source.pdf")]) == 5
temporary.replace(DESTINATION)
print(f"{DESTINATION}: {len(files)} files, {DESTINATION.stat().st_size:,} bytes, SHA256 {digest(DESTINATION)}")
