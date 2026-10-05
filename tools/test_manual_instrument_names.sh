#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache .build/manual-instrument-names-2026-10-05
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
core_sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
              Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache \
  "${core_sources[@]}" tools/test_manual_instrument_names.swift \
  -o .build/manual-instrument-names-2026-10-05/test-manual-names
.build/manual-instrument-names-2026-10-05/test-manual-names "$@"
