#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
fixture="Tests/quality_control/system-template-workflow-2026-10-03"
out=".build/system-template-workflow-2026-10-03"
mkdir -p "$out/replay" .build/ModuleCache
/usr/bin/unzip -q -o "$fixture/implementation-snapshot.zip" -d "$out/replay"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
core="$out/replay/Core"
xcrun swiftc -O -parse-as-library -module-cache-path .build/ModuleCache \
  "$core"/DocumentModel/*.swift "$core"/Detection/*.swift \
  "$core"/Layout/*.swift "$core"/Export/*.swift \
  "$out/replay/ExportScorePlan.swift" "$fixture/workflow.swift" -o "$out/workflow-replay"
"$out/workflow-replay" --inventory "$out/workflow-inventory.json" \
  --profile "$fixture/profile.json" --overrides "$out/workflow-overrides.json" \
  --title 'Erlkönig — D 328' --composer 'Franz Schubert' --out "$out/parts"
