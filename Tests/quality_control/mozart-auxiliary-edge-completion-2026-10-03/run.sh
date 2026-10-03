#!/bin/bash
set -euo pipefail
root=.build/mozart-auxiliary-review-2026-10-03/edge-completion
for variant in baseline candidate; do
 core=$root/$variant/Core/Detection
 xcrun swiftc -O -module-cache-path .build/ModuleCache "$core/StaffBandDetector.swift" "$core/ScoreExtractionPlanner.swift" "$core/ScoreSharedEnding.swift" "$core/ScoreSharedEndingDetector.swift" "$core/ScoreLocalEndingPreservation.swift" "$root/probe.swift" -o "$root/$variant/probe"
 if [ "$variant" = baseline ]; then "$root/$variant/probe" --baseline; else "$root/$variant/probe"; fi
 "$root/$variant/probe" replay .build/ownership-mozart-output-2026-10-03/candidate/mozart-inventory.json Tests/quality_control/profiles/medium-skewed-01-mozart-piano-quartet-k478-imslp-86903.json "$root/results/$variant-mozart-plan.json"
 "$root/$variant/probe" replay .build/ownership-alternatives-output-2026-10-03/brahms-inventory.json Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json "$root/results/$variant-brahms-plan.json"
done
