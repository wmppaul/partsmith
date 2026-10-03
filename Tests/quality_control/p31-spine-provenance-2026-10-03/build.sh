#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
work=.build/p31-spine-provenance-2026-10-03
control_core="$work/Core"
xcrun swiftc -parse-as-library -O -module-cache-path .build/ModuleCache "$control_core/Detection/StaffBandDetector.swift" "$control_core/Detection/ScoreExtractionPlanner.swift" "$control_core/Detection/ScoreSharedEnding.swift" "$control_core/Detection/ScoreSharedEndingDetector.swift" "$control_core/Detection/ScoreLocalEndingPreservation.swift" "$control_core/Detection/NativeScorePageAnalyzer.swift" "$work/ProbeNativeScorePageAnalyzer.swift" "$work/main.swift" -o "$work/probe"
"$work/probe" > "$work/trace.jsonl"
