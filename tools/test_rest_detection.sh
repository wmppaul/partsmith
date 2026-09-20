#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  Partsmith/Core/Detection/StaffBandDetector.swift \
  Partsmith/Core/Detection/ScoreExtractionPlanner.swift \
  Partsmith/Core/Detection/NativeScorePageAnalyzer.swift \
  Partsmith/Core/Detection/ScoreRestDetector.swift \
  tools/test_rest_detection.swift -o .build/test_rest_detection
.build/test_rest_detection "$@"
