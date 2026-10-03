#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -Onone -module-cache-path .build/ModuleCache \
  Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift \
  Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift \
  tools/test_generated_rest_joins.swift -o .build/test_generated_rest_joins
.build/test_generated_rest_joins "$@"
