#!/usr/bin/env bash
# Build a fresh universal .app and zip it for copying to another Mac.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build.sh" release

ZIP="dist/InMyFace.zip"
rm -f "$ZIP"
# ditto preserves the bundle + code signature correctly (better than zip).
ditto -c -k --sequesterRsrc --keepParent dist/InMyFace.app "$ZIP"

echo "==> Packaged: $ZIP"
echo "    AirDrop this to your other Mac, then on that Mac:"
echo "      unzip ~/Downloads/InMyFace.zip -d /Applications/"
echo "      xattr -dr com.apple.quarantine /Applications/InMyFace.app"
echo "      open /Applications/InMyFace.app"
