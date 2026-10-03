#!/bin/bash
set -euo pipefail
cd /Users/will/Documents/git/partsmith
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
r=.build/residual9-endpoint-ownership-2026-10-03
variant=$1
harness=$2
analyzer="$r/NativeScorePageAnalyzer.$variant.swift"
if [[ "$variant" == baseline ]]; then analyzer="$r/Core/Detection/NativeScorePageAnalyzer.swift"; fi
xcrun swiftc -O -module-cache-path .build/ModuleCache \
 "$r/Core/Detection/StaffBandDetector.swift" \
 "$r/Core/Detection/ScoreExtractionPlanner.swift" \
 "$r/Core/Detection/ScoreSharedEnding.swift" \
 "$r/Core/Detection/ScoreSharedEndingDetector.swift" \
 "$r/Core/Detection/ScoreLocalEndingPreservation.swift" \
 "$analyzer" "$r/$harness.swift" -o "$r/$variant-$harness"
if [[ "$harness" == existing755 ]]; then "$r/$variant-$harness"; else "$r/$variant-$harness" "$r/$variant-$harness.json"; fi
