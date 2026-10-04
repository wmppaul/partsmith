#!/bin/bash
set -euo pipefail
cd /Users/will/Documents/git/partsmith
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
root=.build/motets-source-equivalence-2026-10-03
xcrun swiftc -O -module-cache-path .build/ModuleCache "$root/Renderer.swift" "$root/render.swift" -o "$root/render" > "$root/build.log" 2>&1
"$root/render" "$root" > "$root/run.log" 2>&1
