#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/brahms-continuation-release-2026-10-03/$1
core=("$root"/Core/DocumentModel/*.swift "$root"/Core/Detection/*.swift "$root"/Core/Layout/*.swift "$root"/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" "$root/native_worker.swift" -o "$root/native_worker"
