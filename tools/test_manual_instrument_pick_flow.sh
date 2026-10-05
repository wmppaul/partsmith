#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache .build/manual-name-ui-2026-10-05
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift
         Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift
         Partsmith/Features/Project/*.swift Partsmith/Features/SourceCanvas/*.swift
         Partsmith/Features/PartsSidebar/*.swift Partsmith/Features/Inspector/*.swift
         Partsmith/Features/PartPreview/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "${sources[@]}" \
    tools/test_manual_instrument_pick_flow.swift -o .build/manual-name-ui-2026-10-05/test-flow
.build/manual-name-ui-2026-10-05/test-flow
