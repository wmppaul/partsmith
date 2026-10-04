#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
p=.build/numbered-volta-heading-independent-2026-10-03
xcrun swiftc -O -module-cache-path .build/ModuleCache "$p/Core/StaffBandDetector.swift" "$p/Core/ScoreExtractionPlanner.swift" "$p/Core/ScoreSharedEnding.swift" "$p/Core/ScoreSharedEndingDetector.swift" "$p/Core/ScoreLocalEndingPreservation.swift" "$p/Core/ScoreSharedHeadingDetector.swift" "$p/test.swift" -o "$p/audit" > "$p/build.log" 2>&1
"$p/audit" "$p/results.json" > "$p/run.log" 2>&1
