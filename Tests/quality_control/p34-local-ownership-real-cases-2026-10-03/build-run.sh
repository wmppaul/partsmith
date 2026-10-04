#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
p=.build/p34-local-ownership-real-cases-2026-10-03
variant=$1
if [ "$variant" = baseline ]; then
  core=.build/p34-local-ownership-2026-10-03/baseline/Core
else
  core=.build/p34-local-ownership-v2-2026-10-03/candidate/Core
fi
mkdir -p "$p/$variant"
/usr/bin/time -p xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "$core/Detection/StaffBandDetector.swift" "$core/Detection/ScoreExtractionPlanner.swift" \
  "$core/Detection/ScoreSharedEnding.swift" "$core/Detection/ScoreSharedEndingDetector.swift" \
  "$core/Detection/ScoreLocalEndingPreservation.swift" "$core/Detection/NativeScorePageAnalyzer.swift" \
  "$p/replay.swift" -o "$p/$variant/runner" > "$p/$variant/build.log" 2>&1
/usr/bin/time -p "$p/$variant/runner" "$p/$variant/result.json" > "$p/$variant/run.log" 2>&1
cat "$p/$variant/run.log"
