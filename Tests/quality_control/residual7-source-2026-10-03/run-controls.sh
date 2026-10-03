#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
base=.build/residual7-source-2026-10-03/controls
core=.build/residual7-geometry-2026-10-03/candidate-pixel-runs/Core
case "$1" in
297) harness=Tests/quality_control/residual9-boundary-independent/controls.swift ;;
336) harness=.build/residual9-boundary-2026-10-03/expanded336.swift ;;
esac
xcrun swiftc -O -module-cache-path .build/ModuleCache \
 "$core/Detection/StaffBandDetector.swift" \
 "$core/Detection/ScoreExtractionPlanner.swift" \
 "$core/Detection/ScoreSharedEnding.swift" \
 "$core/Detection/ScoreSharedEndingDetector.swift" \
 "$core/Detection/ScoreLocalEndingPreservation.swift" \
 "$core/Detection/NativeScorePageAnalyzer.swift" \
 "$harness" -o "$base/$1"
"$base/$1" "$base/$1-results.json"
"$base/$1" "$base/$1-repeat.json"
