#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/ending-local-counterparts
core=("$root"/Core/DocumentModel/*.swift "$root"/Core/Detection/*.swift "$root"/Core/Layout/*.swift "$root"/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" "$root/controls.swift" "$root/regression.swift" -o "$root/regression"
"$root/regression" --corpus
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" tools/export_score_plan.swift -o "$root/exporter"
