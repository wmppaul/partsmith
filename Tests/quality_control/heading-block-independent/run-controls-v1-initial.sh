#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
heading_qc_core="${1:-.build/heading-blocks-2026-10-03/candidate/Core}"
mkdir -p .build/heading-block-independent .build/ModuleCache
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  "$heading_qc_core/Detection/StaffBandDetector.swift" \
  "$heading_qc_core/Detection/ScoreExtractionPlanner.swift" \
  "$heading_qc_core/Detection/ScoreSharedEnding.swift" \
  "$heading_qc_core/Detection/ScoreSharedEndingDetector.swift" \
  "$heading_qc_core/Detection/ScoreLocalEndingPreservation.swift" \
  "$heading_qc_core/Detection/ScoreSharedHeadingDetector.swift" \
  Tests/quality_control/heading-block-independent/controls.swift \
  -o .build/heading-block-independent/controls
.build/heading-block-independent/controls .build/heading-block-independent/results.json
