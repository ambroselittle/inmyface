#!/usr/bin/env bash
# Build InMyFace and assemble a runnable .app bundle in dist/.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="${1:-release}"
APP_NAME="InMyFace"
APP="dist/${APP_NAME}.app"

# Build a universal binary so the .app runs on both Apple Silicon and Intel.
ARCHS=(--arch arm64 --arch x86_64)

echo "==> Building ($CONFIG, universal)…"
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
