#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache .build/selected-page-picking-2026-10-04
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
         Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift
         Partsmith/Features/Project/*.swift Partsmith/Features/SourceCanvas/*.swift
         Partsmith/Features/PartsSidebar/*.swift Partsmith/Features/Inspector/*.swift
         Partsmith/Features/PartPreview/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "${sources[@]}" \
    tools/test_instrument_pick_flow.swift -o .build/selected-page-picking-2026-10-04/test-flow
.build/selected-page-picking-2026-10-04/test-flow
