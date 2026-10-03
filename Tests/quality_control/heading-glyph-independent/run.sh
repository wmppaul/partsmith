#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
r=Tests/quality_control/heading-glyph-independent
core=.build/heading-glyph-continuation-2026-10-03/candidate/Core/Detection
xcrun swiftc -O -module-cache-path /tmp/partsmith-heading-glyph-independent-2026-10-03/ModuleCache "$core/StaffBandDetector.swift" "$core/ScoreExtractionPlanner.swift" "$core/ScoreSharedEnding.swift" "$core/ScoreSharedEndingDetector.swift" "$core/ScoreLocalEndingPreservation.swift" "$core/ScoreSharedHeadingDetector.swift" "$r/controls.swift" -o /tmp/partsmith-heading-glyph-independent-2026-10-03/controls
/tmp/partsmith-heading-glyph-independent-2026-10-03/controls
