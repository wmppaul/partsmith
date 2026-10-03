#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
r=.build/residual9-boundary-2026-10-03/agent-probe
xcrun swiftc -O -module-cache-path .build/ModuleCache "$r/StaffBandDetector.swift" "$r/ScoreExtractionPlanner.swift" "$r/ScoreSharedEnding.swift" "$r/ScoreSharedEndingDetector.swift" "$r/ScoreLocalEndingPreservation.swift" "$r/NativeScorePageAnalyzer.swift" "$r/UnmodifiedNativeScorePageAnalyzer.swift" "$r/trace.swift" -o "$r/trace"
"$r/trace" > "$r/trace.jsonl"
