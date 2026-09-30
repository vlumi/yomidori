#!/usr/bin/env bash
# Build the app unsigned: iOS for the simulator, or the Mac app. Usage: build.sh [ios|macos]
# Assumes the Xcode project is already generated (the Makefile handles that).
set -euo pipefail
cd "$(dirname "$0")/.."

platform="${1:-ios}"
case "$platform" in
    ios) scheme="Yomidori-iOS"; destination="generic/platform=iOS Simulator" ;;
    macos) scheme="Yomidori-macOS"; destination="generic/platform=macOS" ;;
    *) echo "usage: build.sh [ios|macos]" >&2; exit 2 ;;
esac

build() {
    xcodebuild -project Yomidori.xcodeproj -scheme "$scheme" \
        -destination "$destination" -derivedDataPath .build-xcode \
        CODE_SIGNING_ALLOWED=NO build
}

echo "Building ${scheme}..."
# Pipe through xcbeautify if it's installed (nicer output); otherwise raw.
if command -v xcbeautify >/dev/null; then
    set -o pipefail
    build | xcbeautify
else
    build
fi
