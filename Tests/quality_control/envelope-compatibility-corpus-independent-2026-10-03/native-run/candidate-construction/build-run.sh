#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
p=.build/numbered-line-envelope-compatibility-2026-10-03
variant=$1
harness=$2
core=$p/$variant/Core
xcrun swiftc -O -module-cache-path .build/ModuleCache "$core/Detection/StaffBandDetector.swift" "$core/Detection/ScoreExtractionPlanner.swift" "$core/Detection/ScoreSharedEnding.swift" "$core/Detection/ScoreSharedEndingDetector.swift" "$core/Detection/ScoreLocalEndingPreservation.swift" "$core/Detection/NativeScorePageAnalyzer.swift" "$p/$harness.swift" -o "$p/$variant/$harness"
if [[ "$harness" == fourcore* ]]; then
 "$p/$variant/$harness" "$p/$variant/$harness.json" "$p/$variant/fourcore-sources"
elif [ "$harness" = existing795 ]; then
 "$p/$variant/$harness"
else
 "$p/$variant/$harness" "$p/$variant/$harness.json"
fi
