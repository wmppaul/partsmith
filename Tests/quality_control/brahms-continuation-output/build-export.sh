#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/brahms-continuation-release-2026-10-03
variant="$1"
core=("$root/$variant"/Core/DocumentModel/*.swift "$root/$variant"/Core/Detection/*.swift "$root/$variant"/Core/Layout/*.swift "$root/$variant"/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" "$root"/output-review/export_reopened.swift -o "$root/output-review/export_$variant"
