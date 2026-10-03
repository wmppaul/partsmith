#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
r=.build/generated-rest-join-independent-2026-10-03
xcrun swiftc -Onone -module-cache-path .build/ModuleCache "$r"/Core/DocumentModel/*.swift "$r"/Core/Detection/*.swift "$r"/Core/Layout/*.swift "$r"/Core/Export/*.swift "$r"/independent.swift -o "$r"/independent
"$r"/independent "$r"
