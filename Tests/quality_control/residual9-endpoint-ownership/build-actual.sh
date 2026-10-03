#!/bin/bash
set -euo pipefail
cd /Users/will/Documents/git/partsmith
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
r=.build/residual9-endpoint-ownership-2026-10-03
variant=$1
sources=()
while IFS= read -r f; do [[ "$f" == *'/NativeScorePageAnalyzer.swift' ]] || sources+=("$f"); done < <(find "$r/Core" -name '*.swift' -print | sort)
analyzer="$r/NativeScorePageAnalyzer.$variant.swift"
if [[ "$variant" == baseline ]]; then analyzer="$r/Core/Detection/NativeScorePageAnalyzer.swift"; fi
xcrun swiftc -O -module-cache-path .build/ModuleCache "${sources[@]}" "$analyzer" "$r/actual.swift" -o "$r/$variant-actual"
"$r/$variant-actual" .build/ending-local-app-native-2026-10-03/brahms-inventory.json Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json "$r/$variant-actual.json"
