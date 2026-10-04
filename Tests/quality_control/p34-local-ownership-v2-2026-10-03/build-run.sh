#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
p=.build/p34-local-ownership-v2-2026-10-03
variant=$1
harness=$2
core=$p/$variant/Core
out=$p/$variant/$harness-run
mkdir -p "$out"
/usr/bin/time -p xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "$core/Detection/StaffBandDetector.swift" \
  "$core/Detection/ScoreExtractionPlanner.swift" \
  "$core/Detection/ScoreSharedEnding.swift" \
  "$core/Detection/ScoreSharedEndingDetector.swift" \
  "$core/Detection/ScoreLocalEndingPreservation.swift" \
  "$core/Detection/NativeScorePageAnalyzer.swift" \
  "$p/$harness.swift" -o "$out/runner" > "$out/build.log" 2>&1
/usr/bin/time -p "$out/runner" "$out/results.json" > "$out/run.log" 2>&1
cat "$out/run.log"
