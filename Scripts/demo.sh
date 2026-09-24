#!/usr/bin/env bash
# Launch the app in DEMO mode on a simulator: every store routed to a folder wiped and
# reseeded at launch with fixed public-domain data (some hundred cards from four novel
# openings at every rank, collections with covers, a history) and a rendered page open under Read, so the
# screens can be looked at without a camera. The real simulator data is never touched.
#   PLATFORM=iphone|ipad   (default iphone)
#   DEVICE=<name pattern>  override the simulator pick
#   TAB=home|read|study|cards|search   open on that tab (default: where it was left)
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
BUNDLE="fi.misaki.yomidori"

case "$PLATFORM" in
    iphone) pat="${DEVICE:-iPhone 1[6-9] Pro}" ;;
    ipad) pat="${DEVICE:-iPad Pro 13-inch}" ;;
    *) echo "PLATFORM must be iphone | ipad" >&2; exit 2 ;;
esac

udid=$(xcrun simctl list devices available | grep -E "$pat" \
    | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" | tail -1)
[ -n "$udid" ] || { echo "No simulator matching /$pat/ installed." >&2; exit 1; }
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
open -a Simulator

# The pristine status bar, as for screenshots: 9:41, full battery.
offset=$(date +%z)
xcrun simctl status_bar "$udid" override \
    --time "2007-01-09T09:41:00.000${offset:0:3}:${offset:3}" \
    --batteryState charged --batteryLevel 100 --wifiBars 3 --dataNetwork wifi

app="$(find .build-xcode/Build/Products/Debug-iphonesimulator \
    -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"
[ -n "$app" ] && [ -d "$app" ] || { echo "Build the app first (make build-ios)." >&2; exit 1; }

xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" "$BUNDLE" -yomidori-demo ${TAB:+-yomidori-tab "$TAB"} >/dev/null
echo "Demo launched on $udid — seeded cards, collections and a page; nothing persists."
