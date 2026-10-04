#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
w=.build/local-line-ownership-corpus-2026-10-03/fresh-production-40163
core=.build/p34-local-ownership-2026-10-03/baseline/Core
/usr/bin/time -p xcrun swiftc -O -module-cache-path .build/ModuleCache \
 "$core/Detection/StaffBandDetector.swift" "$core/Detection/ScoreExtractionPlanner.swift" \
 "$core/Detection/ScoreSharedEnding.swift" "$core/Detection/ScoreSharedEndingDetector.swift" \
 "$core/Detection/ScoreLocalEndingPreservation.swift" "$core/Detection/NativeScorePageAnalyzer.swift" \
 .build/p34-local-ownership-v2-2026-10-03/permanent.swift -o "$w/runner" > "$w/build.log" 2>&1
/usr/bin/time -p "$w/runner" --inventory /Users/will/Documents/git/partsmith/sample_scores/lightly_skewed/08_mendelssohn_hear_my_prayer_woo15_imslp_40163.pdf /Users/will/Documents/git/partsmith/Tests/quality_control/profiles/lightly-skewed-08-mendelssohn-hear-my-prayer-woo15-imslp-40163.json "$w/inventory.json" > "$w/run.log" 2>&1
cat "$w/run.log"
