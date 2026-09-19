#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  Partsmith/Core/DocumentModel/ProjectModels.swift \
  Partsmith/Core/Layout/PartLayoutEngine.swift \
  tools/test_layout.swift -o .build/test_layout
.build/test_layout
core_sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
              Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "${core_sources[@]}" tools/test_exclusions.swift -o .build/test_exclusions
.build/test_exclusions "${1:-output/pdf/notte/Notte e giorno.partsmithproject}"
