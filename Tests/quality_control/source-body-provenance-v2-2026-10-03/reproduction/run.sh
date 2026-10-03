#!/bin/bash
set -euo pipefail
report="Tests/quality_control/source-body-provenance-v2-2026-10-03"
trial="${1:?Supply a new scratch output directory}"
mkdir -p "$trial"
unzip -q "$report/frozen-core.zip" -d "$trial"
core="$trial/candidate-v2/Core"
builder="$report/reproduction/build.sh"
for name in controls765 controls297 expanded336 controls180 tied36 helper-probe replay replay-plans; do
  bash "$builder" "$core" "$report/reproduction/$name.swift" "$trial/$name"
done
"$trial/controls765" > "$trial/765.log"
"$trial/controls297" "$trial/results297.json"
"$trial/expanded336" "$trial/results336.json"
"$trial/controls180" "$trial/results180.json" "$trial/sources180"
"$trial/tied36" "$trial/results36.json" "$trial/sources36"
python3 Tests/quality_control/terminal-body-independent-2026-10-03/compare.py "$trial/results180.json" "$trial/comparison180.json"
python3 Tests/quality_control/terminal-body-independent-2026-10-03/compare.py "$trial/results36.json" "$trial/comparison36.json" --tied
"$trial/helper-probe" Tests/quality_control/notehead-provenance-independent-2026-10-03/helper-inputs.json "$trial/development22-results.json"
"$trial/helper-probe" Tests/quality_control/notehead-provenance-independent-2026-10-03/local-line-helper-inputs.json "$trial/development-local4-results.json"
gzip -dc "$report/results/native-replay-inputs.json.gz" > "$trial/native-replay-inputs.json"
"$trial/replay" "$trial/native-replay-inputs.json" "$trial/replay-output"
"$trial/replay-plans" "$trial/native-replay-inputs.json" "$trial/replay-output/witnesses.json" Tests/quality_control/profiles/medium-skewed-06-brahms-string-quartet-no3-op67-imslp-93521.json "$trial/replayed-plans.json"
