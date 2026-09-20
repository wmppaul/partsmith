#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  Partsmith/Core/Detection/StaffBandDetector.swift \
  Partsmith/Core/Detection/ScoreExtractionPlanner.swift \
  Partsmith/Core/Detection/NativeScorePageAnalyzer.swift \
  Partsmith/Core/Detection/ScoreInstrumentNameDetector.swift \
  Partsmith/Core/Detection/ScoreSourceHeaderDetector.swift \
  Partsmith/Core/DocumentModel/ProjectModels.swift \
  Partsmith/Core/DocumentModel/PageRectificationEstimator.swift \
  Partsmith/Core/DocumentModel/BarNumberDetector.swift \
  Partsmith/Core/DocumentModel/PartsmithDocument.swift \
  tools/test_staff_detection.swift -o .build/test_staff_detection
.build/test_staff_detection "$@"
