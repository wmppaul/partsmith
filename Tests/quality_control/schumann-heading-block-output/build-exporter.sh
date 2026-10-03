#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
core_root=.build/heading-blocks-2026-10-03/candidate-final
out_root=.build/schumann-heading-output-2026-10-03
core=("$core_root"/Core/DocumentModel/*.swift "$core_root"/Core/Detection/*.swift "$core_root"/Core/Layout/*.swift "$core_root"/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" "$out_root/export_score_plan.swift" -o "$out_root/exporter"
