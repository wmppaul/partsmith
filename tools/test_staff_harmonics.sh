#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
detector_source="${PARTSMITH_STAFF_DETECTOR_SOURCE:-Partsmith/Core/Detection/StaffBandDetector.swift}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "$detector_source" tools/test_staff_harmonics.swift \
  -o .build/test_staff_harmonics
.build/test_staff_harmonics "$@"
