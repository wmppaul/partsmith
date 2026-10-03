#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
snapshot="$1"
binary="$2"
c="$snapshot/candidate/Core/Detection"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
    "$c/StaffBandDetector.swift" "$c/ScoreExtractionPlanner.swift" \
    "$c/ScoreSharedEnding.swift" "$c/ScoreSharedEndingDetector.swift" \
    "$c/ScoreLocalEndingPreservation.swift" "$c/NativeScorePageAnalyzer.swift" \
    "$snapshot/BaselineAnalyzer.swift" "$snapshot/challenge.swift" -o "$binary"
