#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  Partsmith/Core/Detection/StaffBandDetector.swift \
  Partsmith/Core/Detection/ScoreExtractionPlanner.swift \
  Partsmith/Core/Detection/ScoreSharedEnding.swift \
  Partsmith/Core/Detection/ScoreSharedEndingDetector.swift \
  Partsmith/Core/Detection/ScoreLocalEndingPreservation.swift \
  Partsmith/Core/Detection/NativeScorePageAnalyzer.swift \
  tools/test_crop_quality.swift -o .build/test_crop_quality
.build/test_crop_quality "$@"
