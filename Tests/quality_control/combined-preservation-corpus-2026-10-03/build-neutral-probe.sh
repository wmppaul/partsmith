#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
review_core=.build/ownership-alternatives-2026-10-03/Core
xcrun swiftc -O -module-cache-path .build/ModuleCache \
 "$review_core/Detection/StaffBandDetector.swift" \
 "$review_core/Detection/ScoreExtractionPlanner.swift" \
 "$review_core/Detection/ScoreSharedEnding.swift" \
 "$review_core/Detection/ScoreSharedEndingDetector.swift" \
 "$review_core/Detection/ScoreLocalEndingPreservation.swift" \
 "$review_core/Detection/NativeScorePageAnalyzer.swift" \
 Tests/quality_control/combined-preservation-corpus-2026-10-03/neutral-staff-plans.swift \
 -o .build/combined-corpus-independent-2026-10-03/neutral-staff-plans
