#!/bin/bash
set -euo pipefail
cd /Users/will/Documents/git/partsmith
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  .build/heading-glyph-continuation-2026-10-03/candidate/Core/Detection/StaffBandDetector.swift \
  .build/heading-glyph-continuation-2026-10-03/candidate/Core/Detection/ScoreExtractionPlanner.swift \
  .build/heading-glyph-continuation-2026-10-03/candidate/Core/Detection/ScoreSharedEnding.swift \
  .build/heading-glyph-continuation-2026-10-03/candidate/Core/Detection/ScoreSharedEndingDetector.swift \
  .build/heading-glyph-continuation-2026-10-03/candidate/Core/Detection/ScoreLocalEndingPreservation.swift \
  .build/heading-glyph-continuation-2026-10-03/candidate/Core/Detection/ScoreSharedHeadingDetector.swift \
  tools/test_shared_headings.swift -o .build/heading-glyph-continuation-2026-10-03/shared_heading_controls
.build/heading-glyph-continuation-2026-10-03/shared_heading_controls
