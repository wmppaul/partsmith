#!/usr/bin/env python3
"""Resumable native diagnostic run. Completion of detection never means quality pass."""
import argparse
import collections
import copy
from concurrent.futures import ThreadPoolExecutor
import datetime
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import threading

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".writing")
    temporary.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")
    temporary.replace(path)


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def live_native_process(progress_path, executable, score):
    """Validate an orphan worker before any resumed invocation touches its files."""
    if not progress_path.exists():
        return None
    previous = read(progress_path)
    pid = previous.get("processID")
    if not isinstance(pid, int) or previous.get("sourceSHA256") != score["sha256"]:
        return None
    try:
        os.kill(pid, 0)
        command = subprocess.check_output(["ps", "-p", str(pid), "-o", "command="], text=True).strip()
    except (ProcessLookupError, subprocess.CalledProcessError):
        return None
    # PID alone could have been reused. Confirm the actual executable too.
    if str(executable) not in command:
        return None
    return {"processID": pid, "observedCommand": command, "observedAt": now(),
            "progressPath": str(progress_path)}


def validate_inventory(path, score):
    inventory = read(path)
    if inventory.get("sourceSHA256") != score["sha256"]:
        raise ValueError("Native inventory source hash differs from corpus")
    if len(inventory.get("pages", [])) != score["pageCount"]:
        raise ValueError("Native inventory does not include every physical page")
    if [page["pageIndex"] for page in inventory["pages"]] != list(range(score["pageCount"])):
        raise ValueError("Native inventory page indices missing, duplicated or reordered")
    return inventory


def run_logged(command, log_path, progress_path, progress):
    """Stream a specific process's progress; no implicit retry on observation timeout."""
    start = time.monotonic()
    with log_path.open("w") as log:
        process = subprocess.Popen(command, cwd=ROOT, text=True, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, bufsize=1)
        progress.update(processID=process.pid, command=command, startedAt=now())
        write(progress_path, progress)
        for line in process.stdout:
            log.write(line)
            log.flush()
            match = re.search(r" page (\d+): (\d+) staves", line)
            if match:
                page, staves = map(int, match.groups())
                progress.update(pagesObserved=page, latestPageStaves=staves, updatedAt=now())
                write(progress_path, progress)
                if page == 1 or page % 20 == 0 or page == progress["pageCount"]:
                    print(f"  {progress['id']}: page {page}/{progress['pageCount']}, {staves} staves", flush=True)
        code = process.wait()
    progress.update(exitCode=code, processID=None, finishedAt=now(), elapsedSeconds=round(time.monotonic() - start, 3))
    write(progress_path, progress)
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--corpus", default="Tests/quality_control/corpus.json")
    parser.add_argument("--executable", default=".build/score_extraction_batch")
    parser.add_argument("--out", default=".build/auto-qc/baseline")
    parser.add_argument("--inventory-only", action="store_true")
    parser.add_argument("--jobs", type=int, default=1, choices=(1, 2, 3), help="Independent native inventory workers; default 1")
    parser.add_argument("--id", action="append", help="Limit to exact corpus ID; repeatable")
    parser.add_argument("--baseline-git-revision", help="Defaults to current git HEAD")
    parser.add_argument("--adopt-inventory", action="append", default=[], metavar="JSON",
                        help="Explicitly attest this just-finished inventory was produced by --executable; source/page/hash checks still run")
    args = parser.parse_args()
    corpus_path = (ROOT / args.corpus).resolve()
    executable = (ROOT / args.executable).resolve()
    out = (ROOT / args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)
    lock = (out / "runner.lock").open("a+")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("A corpus runner is live in this output directory. Observe it instead of restarting.")
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise SystemExit("Build the current native batch executable first; --executable must be executable")
    corpus = read(corpus_path)
    known_ids = {score["id"] for score in corpus["scores"]}
    if set(args.id or []) - known_ids:
        raise SystemExit("Unknown corpus IDs: " + str(sorted(set(args.id) - known_ids)))
    selected = [score for score in corpus["scores"] if args.id is None or score["id"] in args.id]
    revision = args.baseline_git_revision or subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    exe_hash = digest(executable)
    binding = {"nativeExecutable": str(executable), "nativeExecutableSHA256": exe_hash,
               "baselineGitRevision": revision, "corpusSHA256": digest(corpus_path)}
    adopted = {}
    for value in args.adopt_inventory:
        path = (ROOT / value).resolve()
        value = read(path)
        if value.get("sourceSHA256") in adopted:
            raise SystemExit("More than one adopted inventory supplied for the same source")
        adopted[value["sourceSHA256"]] = path
    report = {"schemaVersion": 1, "startedAt": now(), **binding,
              "scope": corpus["scope"], "requestedInputPDFs": len(selected),
              "requestedInputPages": sum(score["pageCount"] for score in selected),
              "qualityStatus": "not_proven_by_detection_or_planning", "scores": []}

    report_lock = threading.Lock()
    report["scores"] = [{"id": score["id"], "pageCount": score["pageCount"], "analysisStatus": "pending", "extractionStatus": "not_run"} for score in selected]
    score_positions = {score["id"]: i for i, score in enumerate(selected)}

    def publish(row=None):
        with report_lock:
            if row is not None:
                report["scores"][score_positions[row["id"]]] = copy.deepcopy(row)
            publish_locked()

    def publish_locked():
        report["updatedAt"] = now()
        report["summary"] = {
            "completedInputPDFs": sum(row.get("analysisStatus") == "complete" for row in report["scores"]),
            "completedInputPages": sum(row["pageCount"] for row in report["scores"] if row.get("analysisStatus") == "complete"),
            "analysisStatuses": dict(collections.Counter(row.get("analysisStatus") for row in report["scores"])),
            "extractionStatuses": dict(collections.Counter(row.get("extractionStatus") for row in report["scores"]))
        }
        write(out / "aggregate.json", report)

    def run_one(index, score):
        target = out / score["id"]
        target.mkdir(parents=True, exist_ok=True)
        progress_path = target / "progress.json"
        row = {"id": score["id"], "path": score["path"], "sourceSHA256": score["sha256"],
               "pageCount": score["pageCount"], "analysisStatus": "running",
               "extractionStatus": "not_run", "visualReviewStatus": "not_reviewed"}
        publish(row)
        print(f"[{index}/{len(selected)}] {score['id']} ({score['pageCount']} pages)", flush=True)
        try:
            live = live_native_process(progress_path, executable, score)
            if live is not None:
                row.update(analysisStatus="already_running", liveProcess=live)
                publish(row)
                print(f"  Worker {live['processID']} is still live; leaving it running.", flush=True)
                return
            if digest(executable) != exe_hash:
                raise RuntimeError("Native executable changed during run; stop and use a stable executable")
            if digest(ROOT / score["path"]) != score["sha256"]:
                raise ValueError("Source PDF changed; refresh corpus metadata and review changes before running")
            cache_path = target / "cache.json"
            key = {"sourceSHA256": score["sha256"], "nativeExecutableSHA256": exe_hash}
            cache = read(cache_path) if cache_path.exists() else {}
            inventory_path = None
            if cache.get("key") == key:
                possible = Path(cache["inventoryPath"])
                if possible.is_file() and digest(possible) == cache["inventorySHA256"]:
                    validate_inventory(possible, score)
                    inventory_path = possible
                    row["reusedInventory"] = True
            if inventory_path is None and score["sha256"] in adopted:
                inventory_path = adopted[score["sha256"]]
                validate_inventory(inventory_path, score)
                row["adoption"] = "Explicit current-executable attestation via --adopt-inventory; native inventory has no built-in executable hash."
            if inventory_path is None:
                inventory_dir = target / "inventory"
                inventory_dir.mkdir(exist_ok=True)
                inventory_path = inventory_dir / "inventory.json"
                if inventory_path.exists():
                    inventory_path.unlink()
                command = [str(executable), "inventory", "--source", str(ROOT / score["path"]), "--out", str(inventory_dir)]
                code = run_logged(command, target / "inventory.log", progress_path,
                                  {**row, **binding, "phase": "inventory"})
                if code:
                    raise RuntimeError(f"Native inventory exited {code}; inspect {target / 'inventory.log'}")
            inventory = validate_inventory(inventory_path, score)
            write(cache_path, {"key": key, "inventoryPath": str(inventory_path),
                               "inventorySHA256": digest(inventory_path), "binding": binding,
                               "adoption": row.get("adoption"), "completedAt": now()})
            row.update(analysisStatus="complete", inventoryPath=str(inventory_path),
                       totalDetectedStaves=sum(len(page["staves"]) for page in inventory["pages"]),
                       zeroStaffPagesOneBased=[page["pageIndex"] + 1 for page in inventory["pages"] if not page["staves"]],
                       pageStaffCounts=[len(page["staves"]) for page in inventory["pages"]],
                       warnings=[{"page": page["pageIndex"] + 1, "warnings": page["warnings"]}
                                 for page in inventory["pages"] if page.get("warnings")])
            if args.inventory_only:
                row["extractionStatus"] = "not_requested_inventory_only"
            elif score.get("profilePath") is None:
                row["extractionStatus"] = "missing_verified_instrument_profile"
            else:
                profile_path = ROOT / score["profilePath"]
                plan_path = target / "plan.json"
                command = [str(executable), "plan", "--inventory", str(inventory_path),
                           "--profile", str(profile_path), "--out", str(plan_path)]
                code = run_logged(command, target / "plan.log", progress_path,
                                  {**row, **binding, "phase": "plan"})
                if code:
                    row["extractionStatus"] = "native_plan_error"
                    row["planExitCode"] = code
                else:
                    plan = read(plan_path)
                    unresolved = [{"page": page["pageIndex"] + 1, "reasons": page["unresolvedReasons"]}
                                  for page in plan["pages"] if page.get("unresolvedReasons")]
                    bands = [band for page in plan["pages"] for band in page["assignments"]]
                    row.update(planPath=str(plan_path), profilePath=score["profilePath"],
                               profileSHA256=digest(profile_path), bandCount=len(bands), unresolvedPages=unresolved,
                               extractionStatus="unresolved_native_plan" if unresolved else "planned_visual_review_pending")
            write(target / "result.json", {**row, **binding})
            write(progress_path, {**row, **binding, "phase": "finished", "processID": None, "finishedAt": now()})
        except Exception as error:
            if row["analysisStatus"] != "complete":
                row["analysisStatus"] = "error"
            row["error"] = str(error)
            write(target / "result.json", {**row, **binding})
            write(progress_path, {**row, **binding, "phase": "error", "processID": None, "finishedAt": now()})
            print(f"  ERROR: {error}", file=sys.stderr, flush=True)
        publish(row)

    publish()
    with ThreadPoolExecutor(max_workers=args.jobs) as workers:
        futures = [workers.submit(run_one, index, score) for index, score in enumerate(selected, 1)]
        for future in futures:
            future.result()
    report["finishedAt"] = now()
    publish()
    print(json.dumps(report["summary"], indent=2), flush=True)
    if any(row.get("analysisStatus") == "already_running" for row in report["scores"]):
        return 2
    return 1 if any(row.get("analysisStatus") == "error" or "error" in row or row.get("planExitCode", 0) != 0 for row in report["scores"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
