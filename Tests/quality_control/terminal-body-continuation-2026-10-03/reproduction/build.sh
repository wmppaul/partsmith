#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
core="$1"
harness="$2"
output="$3"
xcrun swiftc -O -module-cache-path .build/ModuleCache "$core/Detection/StaffBandDetector.swift" "$core/Detection/ScoreExtractionPlanner.swift" "$core/Detection/ScoreSharedEnding.swift" "$core/Detection/ScoreSharedEndingDetector.swift" "$core/Detection/ScoreLocalEndingPreservation.swift" "$core/Detection/NativeScorePageAnalyzer.swift" "$harness" -o "$output"
