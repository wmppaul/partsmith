#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/heading-glyph-continuation-2026-10-03
core=("$root"/candidate/Core/DocumentModel/*.swift "$root"/candidate/Core/Detection/*.swift "$root"/candidate/Core/Layout/*.swift "$root"/candidate/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" .build/heading-glyph-continuation-2026-10-03/native/run_headings.swift -o .build/heading-glyph-continuation-2026-10-03/native/run_headings
