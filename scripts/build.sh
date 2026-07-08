#!/usr/bin/env bash
# Build InMyFace and assemble a runnable .app bundle in dist/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="InMyFace"
APP="dist/${APP_NAME}.app"

# Release ships a universal binary (Apple Silicon + Intel). Debug builds stay
# native-arch for speed and carry the DEVELOPER flag (see Package.swift).
if [[ "$CONFIG" == "release" ]]; then
    ARCHS=(--arch arm64 --arch x86_64)
    echo "==> Building (release, universal)…"
else
    ARCHS=()
    echo "==> Building ($CONFIG, native, DEVELOPER menu on)…"
fi

swift build -c "$CONFIG" "${ARCHS[@]}"

BIN="$(swift build -c "$CONFIG" "${ARCHS[@]}" --show-bin-path)/${APP_NAME}"
if [[ ! -f "$BIN" ]]; then
    echo "Build did not produce $BIN" >&2
    exit 1
fi

echo "==> Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/${APP_NAME}"
cp Resources/Info.plist "$APP/Contents/Info.plist"

echo "==> Ad-hoc signing…"
codesign --force --sign - --timestamp=none "$APP" >/dev/null

echo "==> Done: $APP"
echo "    Run it with:  open \"$APP\""
