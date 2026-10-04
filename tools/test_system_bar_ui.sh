#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache .build/system-bar-request-review
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 - <<'PY'
from pathlib import Path
import hashlib,json
root=Path('.');out=root/'.build/system-bar-request-review'; snapshot=out/'source-snapshot'
paths=sorted(list((root/'Partsmith/Core').rglob('*.swift'))+list((root/'Partsmith/Features').rglob('*.swift')))
hashes={}
for path in paths:
    data=path.read_bytes(); target=snapshot/path
    target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    hashes[str(path)]=hashlib.sha256(data).hexdigest()
assert all(hashlib.sha256(Path(p).read_bytes()).hexdigest()==h for p,h in hashes.items())
(out/'source-hashes.json').write_text(json.dumps(hashes,indent=2,sort_keys=True)+'\n')
(out/'source-files.txt').write_text(''.join(str(snapshot/path)+'\n' for path in paths))
PY
sources=()
while IFS= read -r source; do sources+=("$source"); done < .build/system-bar-request-review/source-files.txt
xcrun swiftc -Onone -whole-module-optimization -module-cache-path .build/ModuleCache \
  "${sources[@]}" tools/test_system_bar_ui.swift -o .build/system-bar-request-review/test-ui
.build/system-bar-request-review/test-ui
