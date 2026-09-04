#!/usr/bin/env bash
# Build InMyFace and assemble a runnable .app bundle in dist/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="InMyFace"
APP="dist/${APP_NAME}.app"

# Release ships a universal binary (Apple Silicon + Intel). Build each
# architecture separately and merge them with lipo: asking SwiftPM to build
# multiple architectures at once requires xcbuild from a full Xcode install,
# while separate builds work with the standalone Command Line Tools too.
# Debug builds stay native-arch for speed and carry the DEVELOPER flag (see
# Package.swift).
if [[ "$CONFIG" == "release" ]]; then
    echo "==> Building (release, universal)…"
    BINS=()
    for ARCH in arm64 x86_64; do
        SCRATCH_PATH=".build/$ARCH"
        echo "    Building ${ARCH}…"
        swift build -c "$CONFIG" --arch "$ARCH" --scratch-path "$SCRATCH_PATH"
        BIN_DIR="$(swift build -c "$CONFIG" --arch "$ARCH" --scratch-path "$SCRATCH_PATH" --show-bin-path)"
        BINS+=("$BIN_DIR/$APP_NAME")
    done
else
    echo "==> Building ($CONFIG, native, DEVELOPER menu on)…"
    swift build -c "$CONFIG"
    BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
    BINS=("$BIN_DIR/$APP_NAME")
fi

for BIN in "${BINS[@]}"; do
    if [[ ! -f "$BIN" ]]; then
        echo "Build did not produce $BIN" >&2
        exit 1
    fi
done

echo "==> Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ ${#BINS[@]} -eq 1 ]]; then
    cp "${BINS[0]}" "$APP/Contents/MacOS/${APP_NAME}"
else
    lipo -create "${BINS[@]}" -output "$APP/Contents/MacOS/${APP_NAME}"
fi
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> Ad-hoc signing…"
codesign --force --sign - --timestamp=none "$APP" >/dev/null

echo "==> Done: $APP"
echo "    Run it with:  open \"$APP\""
