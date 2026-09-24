#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
# Pass a frozen Detection directory to audit a scratch candidate.
review_detection_dir="${1:-Partsmith/Core/Detection}"
mkdir -p .build/heading-ink-independent/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/heading-ink-independent/ModuleCache \
  "$review_detection_dir/StaffBandDetector.swift" \
  "$review_detection_dir/ScoreExtractionPlanner.swift" \
  "$review_detection_dir/ScoreSharedHeadingDetector.swift" \
  Tests/quality_control/heading-ink-independent-review/review_tests.swift \
  -o .build/heading-ink-independent/independent_tests
.build/heading-ink-independent/independent_tests
