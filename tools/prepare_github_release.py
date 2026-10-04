#!/usr/bin/env python3
"""Stage the reviewed Mac archive for a versioned GitHub release; never rebuild it."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("tag")
parser.add_argument("--output", type=Path, default=Path("dist"))
args = parser.parse_args()
if not re.fullmatch(r"v\d+\.\d+\.\d+(?:-[A-Za-z0-9.]+)?", args.tag):
    parser.error("Expected a version tag such as v0.1.0-alpha.3")

root = Path(__file__).resolve().parents[1]
record = json.loads((root / "docs/releases" / f"{args.tag}.json").read_text())
review = root / record["reviewDirectory"]
publication = json.loads((review / "publication.json").read_text())
source_hashes = json.loads((review / "source-hashes.json").read_text())
archive = root / publication["publicPath"]
sha256 = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
assert sha256(archive) == record["sha256"] == publication["publicSHA256"], "Archive differs from reviewed release"
actual_swift = {str(path.relative_to(root)) for path in (root / "Partsmith").rglob("*.swift")}
assert actual_swift == {name for name in source_hashes if name.endswith(".swift")}, "App source roster changed"
required = actual_swift | {
    "Partsmith/Resources/Info.plist", "Partsmith.xcodeproj/project.pbxproj",
    "Partsmith.xcodeproj/xcshareddata/xcschemes/Partsmith.xcscheme",
}
for name in required:
    assert sha256(root / name) == source_hashes[name], f"App changed since review: {name}"
notes = root / "docs/releases" / f"{args.tag}.md"
assert notes.is_file() and notes.stat().st_size > 0, "Release notes missing"
with zipfile.ZipFile(archive) as zipped:
    assert zipped.testzip() is None, "Damaged ZIP"
    assert "Partsmith.app/Contents/MacOS/Partsmith" in zipped.namelist(), "App executable missing"
args.output.mkdir(parents=True, exist_ok=True)
destination = args.output / f"Partsmith-{args.tag}-macos.zip"
shutil.copyfile(archive, destination)
assert sha256(destination) == record["sha256"]
(destination.with_suffix(".zip.sha256")).write_text(f"{record['sha256']}  {destination.name}\n")
print(f"Verified {len(required)} app/build inputs; staged {destination} ({sha256(destination)})")
