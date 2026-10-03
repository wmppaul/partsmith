#!/bin/bash
set -euo pipefail
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
crop_core="$1"
crop_binary="$2"
core_sources=("$crop_core"/DocumentModel/*.swift "$crop_core"/Detection/*.swift
              "$crop_core"/Layout/*.swift "$crop_core"/Export/*.swift)
xcrun swiftc -O -module-cache-path .build/ModuleCache "${core_sources[@]}" \
 Tests/quality_control/crop-edit-ending-provenance-2026-10-03/local-ending-fixture.swift \
 Tests/quality_control/crop-edit-ending-provenance-2026-10-03/controls.swift \
 -o "$crop_binary"
