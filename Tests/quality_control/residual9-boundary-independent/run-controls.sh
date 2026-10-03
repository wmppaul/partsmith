#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
boundary_core="${1:-.build/residual9-boundary-independent/Core}"
boundary_output="${2:-.build/residual9-boundary-independent/baseline.json}"
mkdir -p .build/residual9-boundary-independent .build/ModuleCache
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "$boundary_core/Detection/StaffBandDetector.swift" \
  "$boundary_core/Detection/ScoreExtractionPlanner.swift" \
  "$boundary_core/Detection/ScoreSharedEnding.swift" \
  "$boundary_core/Detection/ScoreSharedEndingDetector.swift" \
  "$boundary_core/Detection/ScoreLocalEndingPreservation.swift" \
  "$boundary_core/Detection/NativeScorePageAnalyzer.swift" \
  Tests/quality_control/residual9-boundary-independent/controls.swift \
  -o .build/residual9-boundary-independent/controls
.build/residual9-boundary-independent/controls "$boundary_output" Tests/quality_control/residual9-boundary-independent/fixtures
