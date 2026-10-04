#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
sources=(Partsmith/Core/DocumentModel/*.swift Partsmith/Core/Detection/*.swift Partsmith/Core/Layout/*.swift Partsmith/Core/Export/*.swift Partsmith/Features/Project/*.swift Partsmith/Features/SourceCanvas/*.swift Partsmith/Features/PartsSidebar/*.swift Partsmith/Features/Inspector/*.swift Partsmith/Features/PartPreview/*.swift)
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "${sources[@]}" .build/literal-layout-ui-2026-10-04/LiteralLayoutUITests.swift -o .build/literal-layout-ui-2026-10-04/test-ui
