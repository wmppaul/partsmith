#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache .build/system-bar-request-review
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
core_sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
              Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache \
  "${core_sources[@]}" tools/test_system_bar_request.swift -o .build/system-bar-request-review/test-request
.build/system-bar-request-review/test-request
