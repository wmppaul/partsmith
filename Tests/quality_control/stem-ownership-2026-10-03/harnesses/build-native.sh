#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
core="$1"
harness="$2"
output="$3"
files=("$core"/DocumentModel/*.swift "$core"/Detection/*.swift "$core"/Layout/*.swift "$core"/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${files[@]}" "$harness" -o "$output"
