#!/usr/bin/env bash
# Build the Mac app signed for this Mac (iCloud and pushes need a signature) and open it.
#   DEMO=1                             the seeded demo, every store in a folder of its own
#   TAB=home|read|study|cards|search   open on that tab (demo only)
#   SCREEN=review|lesson|progress|settings|about|collections   pushed on that tab
#   SEARCH=<text>                      the search field filled
#   SHOTS=<seconds>                    a picture of the window saved to the app's container that often
set -euo pipefail
cd "$(dirname "$0")/.."

scheme="Yomidori-macOS"
derived=".build-xcode"

build() {
    xcodebuild -project Yomidori.xcodeproj -scheme "$scheme" \
        -destination "generic/platform=macOS" -derivedDataPath "$derived" \
        -allowProvisioningUpdates build
}
echo "Building ${scheme}..."
if command -v xcbeautify >/dev/null; then
    set -o pipefail
    build | xcbeautify
else
    build
fi

app="$derived/Build/Products/Debug/Yomidori.app"
[ -d "$app" ] || { echo "No app at $app" >&2; exit 1; }

args=()
# SHOTS=<seconds>: the app saves a picture of its window to its container that often, for
# a session that cannot see the screen.
[ -n "${SHOTS:-}" ] && args+=(-yomidori-shots "$SHOTS")
if [ -n "${DEMO:-}" ]; then
    args+=(-yomidori-demo)
    [ -n "${TAB:-}" ] && args+=(-yomidori-tab "$TAB")
    [ -n "${SCREEN:-}" ] && args+=(-yomidori-screen "$SCREEN")
    [ -n "${SEARCH:-}" ] && args+=(-yomidori-search "$SEARCH")
fi
# Quit the running one properly, so it leaves no half-written window state behind: a
# window restored from that never appears.
osascript -e 'tell application id "fi.misaki.yomidori" to quit' >/dev/null 2>&1 || true
sleep 1
pkill -x Yomidori >/dev/null 2>&1 || true
if [ ${#args[@]} -gt 0 ]; then
    open -n "$app" --args "${args[@]}"
else
    open -n "$app"
fi
