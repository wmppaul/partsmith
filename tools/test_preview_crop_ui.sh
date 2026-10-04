#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
core_sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "${core_sources[@]}" Partsmith/Features/Inspector/InspectorView.swift Partsmith/Features/PartPreview/PartPreviewView.swift tools/test_preview_crop_ui.swift -o .build/test_preview_crop_ui
.build/test_preview_crop_ui
