"""Create an unchanged-crop eight-system excerpt from the native K488 QA project.

The original full source remains embedded. No staff/crop geometry is synthesized
and no rest compression is preset. Use this as input to compress_score_rests.sh.
"""
from pathlib import Path
import copy
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / "output/pdf/auto-qc-2026-10-03/mozart-k488-variable-layout-draft/Mozart K488 — I. Allegro.partsmithproject"
OUT = ROOT / ".build/mozart_rest_regression_2026-10-04"
QA = ROOT / "Tests/quality_control/mozart_rest_source_review_2026-10-04"
envelope = json.loads((ORIGINAL / "project.json").read_text())
project = envelope["project"]
project["bands"] = [b for b in project["bands"] if b["pageIndex"] < 4]
assert len(project["parts"]) == 9 and len(project["bands"]) == 72
assert len([b for b in project["bands"] if b.get("generatedRest")]) == 7
assert not any(b.get("restReplacement") or b.get("exclusions") for b in project["bands"])
project["projectName"] = "Mozart K488 — opening 39 bars — rest regression"
project["projectSettings"]["defaultTitleText"] = "Mozart K488 — opening 39 bars"
for part in project["parts"]:
    assert len([b for b in project["bands"] if b["partID"] == part["id"]]) == 8

outputs = {}
for variant in ("numbered", "unnumbered"):
    value = copy.deepcopy(envelope)
    if variant == "unnumbered":
        for band in value["project"]["bands"]:
            band["barNumberMode"] = "automatic"
            band.pop("barNumberValue", None)
            if band.get("generatedRest"):
                band["generatedRest"].pop("startBarNumber", None)
    path = OUT / f"{variant}.partsmithproject"
    path.mkdir(parents=True, exist_ok=True)
    (path / "project.json").write_text(json.dumps(value, indent=2) + "\n")
    shutil.copyfile(ORIGINAL / "source.pdf", path / "source.pdf")
    outputs[variant] = {
        "package": str(path.relative_to(ROOT)),
        "projectSHA256": hashlib.sha256((path / "project.json").read_bytes()).hexdigest(),
        "sourceSHA256": hashlib.sha256((path / "source.pdf").read_bytes()).hexdigest(),
    }
manifest = {
    "originalProject": str(ORIGINAL.relative_to(ROOT)),
    "originalProjectSHA256": hashlib.sha256((ORIGINAL / "project.json").read_bytes()).hexdigest(),
    "construction": "Subset unchanged native crops, source markings and reviewed assignments to source pages1–4. Full36-page original retained. No new Auto staff-analysis run or manual crop cleanup.",
    "scope": "9 parts × 8 systems =72 items; 65 printed crops plus7 assigned Piano rest passages",
    "numberedVariant": "Keeps reviewed start measures1,6,11,17,22,26,30,35",
    "unnumberedVariant": "Removes optional first-bar values, simulating Assign a System with only Bars in system filled",
    "outputs": outputs,
}
QA.mkdir(parents=True, exist_ok=True)
(QA / "fixture-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(json.dumps(outputs, indent=2))
