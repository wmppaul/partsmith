#!/bin/bash
set -euo pipefail
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project .build/manual-name-release-2026-10-05/Partsmith.xcodeproj \
  -scheme Partsmith -configuration Release \
  -derivedDataPath .build/manual-name-release-2026-10-05/DerivedData \
  CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO 'ARCHS=arm64 x86_64' build \
  > .build/manual-name-release-2026-10-05/build.log 2>&1
