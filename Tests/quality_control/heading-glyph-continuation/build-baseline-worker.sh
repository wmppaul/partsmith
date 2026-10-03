#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/heading-glyph-continuation-2026-10-03
core=("$root"/baseline/Core/DocumentModel/*.swift "$root"/baseline/Core/Detection/*.swift "$root"/baseline/Core/Layout/*.swift "$root"/baseline/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" .build/heading-glyph-continuation-2026-10-03/native-worker/baseline/native_worker.swift -o .build/heading-glyph-continuation-2026-10-03/native-worker/baseline/native_worker
