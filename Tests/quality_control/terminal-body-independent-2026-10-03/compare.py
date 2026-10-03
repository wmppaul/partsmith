#!/usr/bin/env python3
"""Compare a candidate against frozen source masks; never modifies the oracle."""
from pathlib import Path
import argparse, hashlib, json

parser = argparse.ArgumentParser()
parser.add_argument("candidate", type=Path)
parser.add_argument("output", type=Path)
parser.add_argument("--tied", action="store_true", help="Compare the separately frozen tied-head supplement")
args = parser.parse_args()
root = Path(__file__).resolve().parent
read = lambda p: json.loads(Path(p).read_text())
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
prefix = "tied-" if args.tied else ""
protocol = read(root / (prefix + "frozen-protocol.json"))
assert sha(root / (prefix + "controls.swift")) == protocol["fixtureSHA256"]
before = {r["name"]: r for r in read(root / (prefix + "baseline-results.json"))}
candidate_rows = read(args.candidate)
after = {r["name"]: r for r in candidate_rows}
assert len(after) == len(candidate_rows) == len(before) == protocol["sourceDefinedCases"]
assert after.keys() == before.keys()
differences, worse, new_failures, repaired = [], [], [], []
for name, old in before.items():
    new = after[name]
    for field in ["kind", "sourceClass", "transform", "rasterScale", "expectedSharedMusicalConnection", "expectedStructuralSeparation"]:
        assert new[field] == old[field], (name, field)
    for a, b in zip([old["sourceImage"]] + old["ownerMasks"], [new["sourceImage"]] + new["ownerMasks"]):
        assert sha(a) == sha(b), (name, "source or owner-mask pixels changed")
    assert len(old["targets"]) == len(new["targets"]) == 2
    changed_targets = []
    for a, b in zip(old["targets"], new["targets"]):
        for field in ["owner", "envelope", "sourcePixelCount"]:
            assert a[field] == b[field], (name, field)
        if a != b:
            rec = {"owner": a["owner"], "before": a, "after": b}
            changed_targets.append(rec)
            if b["sourcePixelsOutsideCrop"] > a["sourcePixelsOutsideCrop"]:
                worse.append({"name": name, **rec})
    if old["allMusicalTargetsPreserved"] and not new["allMusicalTargetsPreserved"]:
        new_failures.append(name)
    if not old["allMusicalTargetsPreserved"] and new["allMusicalTargetsPreserved"]:
        repaired.append(name)
    if changed_targets or old["wholeNeighborCount"] != new["wholeNeighborCount"]:
        differences.append({"name": name, "sourceClass": old["sourceClass"], "changedTargets": changed_targets,
                            "beforeWholeNeighbors": old["wholeNeighborCount"], "afterWholeNeighbors": new["wholeNeighborCount"]})
result = {
    "sourceMasksAndObligationsUnchanged": True,
    "cases": protocol["sourceDefinedCases"],
    "caseSet": "tied-head supplement" if args.tied else "original source controls",
    "baselineResultsSHA256": sha(root / (prefix + "baseline-results.json")),
    "candidateResultsSHA256": sha(args.candidate),
    "fixtureSHA256": protocol["fixtureSHA256"],
    "baselineEnvelopeFailures": sum(not r["allMusicalTargetsPreserved"] for r in before.values()),
    "candidateEnvelopeFailures": sum(not r["allMusicalTargetsPreserved"] for r in after.values()),
    "newFailingCases": new_failures,
    "repairedCases": repaired,
    "worsenedOwnerEnvelopes": worse,
    "changedCases": differences,
    "baselineStructuralNeighborCases": sum(r["expectedStructuralSeparation"] and r["wholeNeighborCount"] > 0 for r in before.values()),
    "candidateStructuralNeighborCases": sum(r["expectedStructuralSeparation"] and r["wholeNeighborCount"] > 0 for r in after.values()),
    "nonRegressionPass": not new_failures and not worse,
    "noFullPreservationClaim": True,
}
args.output.write_text(json.dumps(result, indent=2) + "\n")
print(json.dumps({k: v for k, v in result.items() if k not in ["changedCases", "worsenedOwnerEnvelopes"]}, indent=2))
