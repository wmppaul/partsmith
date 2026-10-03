#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
core=Partsmith/Core
xcrun swiftc -O -module-cache-path .build/ModuleCache "$core/Detection/StaffBandDetector.swift" "$core/Detection/ScoreExtractionPlanner.swift" "$core/Detection/ScoreSharedEnding.swift" "$core/Detection/ScoreSharedEndingDetector.swift" "$core/Detection/ScoreLocalEndingPreservation.swift" "$core/Detection/NativeScorePageAnalyzer.swift" "$1" .build/system-template-independent-2026-10-03/challenge.swift -o "$2"
