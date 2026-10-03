#!/bin/bash
set -euo pipefail
if [ "$#" -ne 3 ]; then
  echo 'usage: run.sh FROZEN_CORE_DIRECTORY INPUTS_DIRECTORY OUTPUT_DIRECTORY' >&2
  exit 2
fi
review_dir="$(cd "$(dirname "$0")" && pwd)"
core_dir="$1"
input_dir="$2"
output_dir="$3"
mkdir -p "$output_dir" "$output_dir/module-cache"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc -O -module-cache-path "$output_dir/module-cache" \
 "$core_dir/Detection/StaffBandDetector.swift" \
 "$core_dir/Detection/ScoreExtractionPlanner.swift" \
 "$core_dir/Detection/ScoreSharedEnding.swift" \
 "$core_dir/Detection/ScoreSharedEndingDetector.swift" \
 "$core_dir/Detection/ScoreLocalEndingPreservation.swift" \
 "$core_dir/Detection/NativeScorePageAnalyzer.swift" \
 "$review_dir/evaluate.swift" -o "$output_dir/evaluate" > "$output_dir/build.log" 2>&1
"$output_dir/evaluate" "$input_dir" "$output_dir/results.json" > "$output_dir/run.log" 2>&1
