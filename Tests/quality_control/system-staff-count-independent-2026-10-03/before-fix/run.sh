#!/bin/bash
set -euo pipefail
cd /Users/will/Documents/git/partsmith
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/system-staff-count-independent-2026-10-03
xcrun swiftc -O -module-cache-path .build/ModuleCache "$root"/Core/DocumentModel/*.swift "$root"/Core/Detection/*.swift "$root"/Core/Layout/*.swift "$root"/Core/Export/*.swift "$root/tests.swift" -o "$root/tests" > "$root/build.log" 2>&1
"$root/tests" "$root" > "$root/run.log" 2>&1
