#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
base=.build/residual7-source-2026-10-03/isolated
core=.build/residual7-geometry-2026-10-03/candidate-connector-target/Core
variant=$1
xcrun swiftc -O -module-cache-path .build/ModuleCache \
 "$core/Detection/StaffBandDetector.swift" "$core/Detection/ScoreExtractionPlanner.swift" \
 "$core/Detection/ScoreSharedEnding.swift" "$core/Detection/ScoreSharedEndingDetector.swift" \
 "$core/Detection/ScoreLocalEndingPreservation.swift" "$base/$variant/NativeScorePageAnalyzer.swift" \
 "$base/fixture.swift" -o "$base/$variant/probe"
"$base/$variant/probe" "$base/$variant" > "$base/$variant/trace.jsonl"
