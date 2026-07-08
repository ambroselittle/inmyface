# InMyFace tasks. Run `just` to list, `just <recipe>` to run one.

# Show available recipes.
_default:
    @just --list

# Build the release .app bundle (universal).
build:
    ./scripts/build.sh

# Build a debug .app with the Developer menu enabled.
build-dev:
    ./scripts/build.sh debug

# Pull latest, rebuild, kill the running app, and relaunch it.
update:
    git pull --ff-only
    ./scripts/build.sh
    -pkill -f InMyFace.app
    sleep 1
    open dist/InMyFace.app

# Rebuild and relaunch without pulling (local iteration).
restart:
    ./scripts/build.sh
    -pkill -f InMyFace.app
    sleep 1
    open dist/InMyFace.app

# Run the test suite.
test:
    swift test

# Build and zip a distributable bundle for copying to another Mac.
package:
    ./scripts/package.sh
