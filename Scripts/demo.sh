#!/usr/bin/env bash
# Launch the app in DEMO mode on a simulator: every store routed to a folder wiped and
# reseeded at launch with fixed public-domain data (some hundred cards from four novel
# openings at every rank, collections with covers, a history) and a rendered page open under Read, so the
# screens can be looked at without a camera. The real simulator data is never touched.
#   PLATFORM=iphone|ipad   (default iphone)
#   DEVICE=<name pattern>  override the simulator pick
#   TAB=home|read|study|cards|search   open on that tab (default: where it was left)
#   SCREEN=review|lesson|progress|settings|about|collections   pushed on that tab
#   SEARCH=<text>                      the search field filled
#   SPREAD=1                           Read opened on two pages
#   SELECT=1                           the card list opened selecting, a few cards picked
#   PICK=<text>                        Read opened with that text selected: on the demo's page
#                                      where it stands there, else as a page of its own
#   DRAWER=0.2|0.5|0.8                 the drawer under the page at that share of the screen
#   MODE=livetext|vision|closeup       the recognizer the page opens in
#   RECOGNIZE=1                        the page read by the recognizers, not taken from its text
#   DEMO_LANG=en|ja                    the app's language (the simulator's otherwise)
#   APPEARANCE=light|dark              the simulator's look (light unless asked)
#   YOMIDORI_UDID_FILE=<path>          the simulator's udid written there, for shoot.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
BUNDLE="fi.misaki.yomidori"

case "$PLATFORM" in
    iphone) pat="${DEVICE:-iPhone 1[6-9] Pro Max}" ;;
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

# The light look, the store's default, unless asked otherwise.
xcrun simctl ui "$udid" appearance "${APPEARANCE:-light}" >/dev/null 2>&1 || true
xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" "$BUNDLE" -yomidori-demo ${TAB:+-yomidori-tab "$TAB"} ${SCREEN:+-yomidori-screen "$SCREEN"} \
  ${SEARCH:+-yomidori-search "$SEARCH"} ${SPREAD:+-yomidori-spread} \
  ${SELECT:+-yomidori-select} ${PICK:+-yomidori-pick "$PICK"} ${DRAWER:+-yomidori-drawer "$DRAWER"} \
  ${MODE:+-yomidori-mode "$MODE"} ${RECOGNIZE:+-yomidori-recognize} \
  ${DEMO_LANG:+-AppleLanguages "($DEMO_LANG)"} >/dev/null
[ -n "${YOMIDORI_UDID_FILE:-}" ] && echo "$udid" > "$YOMIDORI_UDID_FILE"
echo "Demo launched on $udid — seeded cards, collections and a page; nothing persists."
