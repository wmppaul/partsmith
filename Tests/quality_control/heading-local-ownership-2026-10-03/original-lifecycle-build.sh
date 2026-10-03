#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
work=.build/heading-local-ownership-2026-10-03
core=("$work"/Core/DocumentModel/*.swift "$work"/Core/Detection/*.swift "$work"/Core/Layout/*.swift "$work"/Core/Export/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "${core[@]}" "$work/controls.swift" -o "$work/controls"
