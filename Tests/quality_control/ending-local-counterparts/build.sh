#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/ending-local-counterparts
core=("$root"/Core/DocumentModel/*.swift "$root"/Core/Detection/*.swift "$root"/Core/Layout/*.swift "$root"/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" "$root/run.swift" -o "$root/run"
