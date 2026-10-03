#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
heading_core="${1:-.build/heading-glyph-continuation-2026-10-03/candidate/Core}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "$heading_core/Detection/StaffBandDetector.swift" \
  "$heading_core/Detection/ScoreExtractionPlanner.swift" \
  "$heading_core/Detection/ScoreSharedEnding.swift" \
  "$heading_core/Detection/ScoreSharedEndingDetector.swift" \
  "$heading_core/Detection/ScoreLocalEndingPreservation.swift" \
  "$heading_core/Detection/ScoreSharedHeadingDetector.swift" \
  Tests/quality_control/heading-glyph-continuation/source_regions.swift \
  -o .build/heading-glyph-continuation-2026-10-03/source_regions
.build/heading-glyph-continuation-2026-10-03/source_regions
