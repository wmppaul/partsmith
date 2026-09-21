#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
core_sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
              Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "${core_sources[@]}" \
  tools/score_extraction_batch.swift -o .build/score_extraction_batch
if [[ "${1:-}" == "--build-only" ]]; then exit 0; fi
.build/score_extraction_batch "$@"
