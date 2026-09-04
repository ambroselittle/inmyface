#!/usr/bin/env bash
# Run the Swift Testing suite with standalone Command Line Tools support.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

DEVELOPER_ROOT="${DEVELOPER_DIR:-$(xcode-select -p)}"
FRAMEWORKS="$DEVELOPER_ROOT/Library/Developer/Frameworks"
DEVELOPER_LIB="$DEVELOPER_ROOT/Library/Developer/usr/lib"
TEST_ARGS=(--enable-swift-testing --disable-xctest)

# Full Xcode normally supplies these search paths automatically. Some
# standalone Command Line Tools releases install Swift Testing in the same
# locations without exposing them to SwiftPM, so add them when present.
if [[ -d "$FRAMEWORKS/Testing.framework" ]]; then
    TEST_ARGS+=(
        -Xswiftc -F
        -Xswiftc "$FRAMEWORKS"
        -Xlinker "-F$FRAMEWORKS"
        -Xlinker -rpath
        -Xlinker "$FRAMEWORKS"
    )
fi

if [[ -f "$DEVELOPER_LIB/lib_TestingInterop.dylib" ]]; then
    TEST_ARGS+=(
        -Xlinker -rpath
        -Xlinker "$DEVELOPER_LIB"
    )
fi

swift test "${TEST_ARGS[@]}"
