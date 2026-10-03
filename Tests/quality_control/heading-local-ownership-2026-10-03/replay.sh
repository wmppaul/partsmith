#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
repo="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$repo"
report=Tests/quality_control/heading-local-ownership-2026-10-03
work="${1:-.build/heading-local-archived-replay-2026-10-03}"
mkdir -p "$work"
unzip -qo "$report/evidence.zip" -d "$work"
core=("$work"/lifecycle/Core/DocumentModel/*.swift "$work"/lifecycle/Core/Detection/*.swift "$work"/lifecycle/Core/Layout/*.swift "$work"/lifecycle/Core/Export/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "${core[@]}" "$report/controls-final.swift" -o "$work/lifecycle-controls"
"$work/lifecycle-controls" "$work/lifecycle-results.json"
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "${core[@]}" "$report/global-mutation-controls.swift" -o "$work/global-mutation-controls"
set +e
"$work/global-mutation-controls" "$work/global-mutation-results.json"
mutation_status=$?
set -e
test "$mutation_status" -eq 1
python3 - "$work" "$report" <<'PY'
import json, pathlib, sys
work, report = map(pathlib.Path, sys.argv[1:])
checks = json.loads((work / 'global-mutation-results.json').read_text())
failed = [c for c in checks if not c['passed']]
assert len(checks) == 53 and len(failed) == 1
assert failed[0]['name'] == 'expanded global block invalidates old local proof for smaller block'
driver = (report / 'matcher-controls.swift').read_text()
original = 'Tests/quality_control/heading-local-ownership-2026-10-03/matcher-results.json'
assert driver.count(original) == 1
driver = driver.replace(original, str(work / 'matcher-results.json'))
(work / 'matcher-replay.swift').write_text(driver)
PY
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "$work/root-probe/ExactHeadingBlockMatch.swift" "$work/matcher-replay.swift" -o "$work/matcher-controls"
"$work/matcher-controls"
