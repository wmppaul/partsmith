#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  Partsmith/Core/Detection/StaffBandDetector.swift \
  Partsmith/Core/Detection/ScoreExtractionPlanner.swift \
  Partsmith/Core/Detection/ScoreSharedNavigationDetector.swift \
  tools/test_shared_navigation.swift -o .build/test_shared_navigation
.build/test_shared_navigation
