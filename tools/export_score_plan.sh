#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path .build/ModuleCache \
  Partsmith/Core/DocumentModel/ProjectModels.swift \
  Partsmith/Core/DocumentModel/PartsmithDocument.swift \
  Partsmith/Core/DocumentModel/BarNumberDetector.swift \
  Partsmith/Core/DocumentModel/PageRectificationEstimator.swift \
  Partsmith/Core/Detection/StaffBandDetector.swift \
  Partsmith/Core/Detection/ScoreExtractionPlanner.swift \
  Partsmith/Core/Detection/NativeScorePageAnalyzer.swift \
  Partsmith/Core/Layout/PartLayoutEngine.swift \
  Partsmith/Core/Export/PartPDFExporter.swift \
  tools/export_score_plan.swift -o .build/export_score_plan
.build/export_score_plan "$@"
