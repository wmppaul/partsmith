#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
control_core="$1"
control_binary="$2"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
 "$control_core/Detection/StaffBandDetector.swift" \
 "$control_core/Detection/ScoreExtractionPlanner.swift" \
 "$control_core/Detection/ScoreSharedEnding.swift" \
 "$control_core/Detection/ScoreSharedEndingDetector.swift" \
 "$control_core/Detection/ScoreLocalEndingPreservation.swift" \
 "$control_core/Detection/NativeScorePageAnalyzer.swift" \
 Tests/quality_control/terminal-body-independent-2026-10-03/tied-controls.swift \
 -o "$control_binary"
