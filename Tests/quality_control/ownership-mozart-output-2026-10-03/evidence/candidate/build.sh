#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
work=.build/ownership-mozart-output-2026-10-03/candidate
core=("$work"/Core/DocumentModel/*.swift "$work"/Core/Detection/*.swift "$work"/Core/Layout/*.swift "$work"/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core[@]}" "$work/$1.swift" -o "$work/$1"
