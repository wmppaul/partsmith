#!/bin/bash
set -euo pipefail
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project .build/system-assignment-release-2026-10-04/Partsmith.xcodeproj \
  -scheme Partsmith -configuration Release \
  -derivedDataPath .build/system-assignment-release-2026-10-04/DerivedData \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' build \
  > .build/system-assignment-release-2026-10-04/build.log 2>&1
