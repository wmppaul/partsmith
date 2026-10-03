#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache .build/shared-ending-tests
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  Partsmith/Core/Detection/StaffBandDetector.swift \
  Partsmith/Core/Detection/ScoreExtractionPlanner.swift \
  Partsmith/Core/Detection/ScoreSharedEnding.swift \
  Partsmith/Core/Detection/ScoreLocalEndingPreservation.swift \
  Partsmith/Core/Detection/ScoreSharedEndingDetector.swift \
  tools/test_shared_endings.swift -o .build/shared-ending-tests/test_shared_endings
.build/shared-ending-tests/test_shared_endings "$@"
