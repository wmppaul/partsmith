#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sources=()
while IFS= read -r source; do
  sources+=("$source")
done < <(rg --files Partsmith/Core Partsmith/Features | rg '\.swift$' | sort)
xcrun swiftc -Onone -whole-module-optimization -module-cache-path .build/ModuleCache \
  "${sources[@]}" tools/test_system_selection.swift -o .build/test_system_selection
.build/test_system_selection
