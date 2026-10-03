#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
control_core=.build/brahms-remaining-2026-10-03/upper-review/Core
xcrun swiftc -parse-as-library -O -module-cache-path .build/ModuleCache "$control_core/Detection/StaffBandDetector.swift" "$control_core/Detection/ScoreExtractionPlanner.swift" "$control_core/Detection/ScoreSharedEnding.swift" "$control_core/Detection/ScoreSharedEndingDetector.swift" "$control_core/Detection/ScoreLocalEndingPreservation.swift" "$control_core/Detection/NativeScorePageAnalyzer.swift" .build/brahms-remaining-2026-10-03/upper-review/ProbeNativeScorePageAnalyzer.swift .build/brahms-remaining-2026-10-03/upper-review/main.swift -o .build/brahms-remaining-2026-10-03/upper-review/probe
