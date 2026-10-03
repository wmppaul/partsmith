#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
core_sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
              Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift)
xcrun swiftc -O -D LOCAL_ENDING_STANDALONE -module-cache-path .build/ModuleCache \
  "${core_sources[@]}" tools/test_local_ending_counterparts.swift -o .build/test_local_ending_counterparts
.build/test_local_ending_counterparts "$@"
