#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache .build/shared-ending-app-tests
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
core_sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
              Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "${core_sources[@]}" tools/test_shared_ending_app.swift \
  -o .build/shared-ending-app-tests/test_shared_ending_app
.build/shared-ending-app-tests/test_shared_ending_app "$@"
