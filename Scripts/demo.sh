#!/usr/bin/env bash
# Launch the app in DEMO mode on a simulator: every store routed to a folder wiped and
# reseeded at launch with fixed public-domain data (some hundred cards from four novel
# openings at every rank, collections with covers, a history) and a rendered page open under Read, so the
# screens can be looked at without a camera. The real simulator data is never touched.
#   PLATFORM=iphone|ipad   (default iphone)
#   DEVICE=<name pattern>  override the simulator pick (a grep regex, or a udid); without it
#                          a booted match is preferred, one DeviceHub already shows
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
#   NOPAGE=1                           Read opened at the camera, no page seeded (with SPREAD=1: after the first page)
#   PICTURE=<path>                     a picture file as the page, read by the recognizers
#   DEMO_LANG=en|ja                    the app's language (the simulator's otherwise)
#   APPEARANCE=light|dark              the simulator's look (light unless asked)
#   YOMIDORI_UDID_FILE=<path>          the simulator's udid written there, for shoot.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
BUNDLE="fi.misaki.yomidori"

# Any recent iPhone or a 13-inch iPad; the store's sizes are shoot.sh's business.
case "$PLATFORM" in
    iphone) pat="${DEVICE:-iPhone 1[6-9]}" ;;
    ipad) pat="${DEVICE:-iPad Pro 13-inch}" ;;
    *) echo "PLATFORM must be iphone | ipad" >&2; exit 2 ;;
esac

# The booted matches first (a window in DeviceHub, where the demo can be seen), then the
# rest, newest first either way; the first that boots is used: see simulator.sh.
# shellcheck source=Scripts/simulator.sh
. "$(dirname "$0")/simulator.sh"
udid_re="[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
# Only devices under an "-- iOS 26 --" or later heading: the app's minimum.
ios26='/^-- /{v=($2=="iOS")?$3+0:0; next} v>=26'
udids=$( {
    xcrun simctl list devices booted | awk "$ios26" | grep -E "$pat" | grep -oE "$udid_re" | tail -r
    xcrun simctl list devices available | awk "$ios26" | grep -E "$pat" | grep -oE "$udid_re" \
        | tail -r
} | awk 'NF && !seen[$0]++')
[ -n "$udids" ] || { echo "No simulator matching /$pat/ installed." >&2; exit 1; }
# shellcheck disable=SC2086
udid=$(boot_first_simulator $udids) || { echo "No simulator matching /$pat/ boots." >&2; exit 1; }
# Shows the simulator where there is a Simulator.app to show it in; Xcode 27 has none (its
# devices live in DeviceHub), and the demo runs headless just as well.
open -g -a Simulator 2>/dev/null || true

# The pristine status bar, as for screenshots: 9:41, full battery. Cosmetic, so a device
# that refuses the override (a watch, say) still gets the demo.
offset=$(date +%z)
xcrun simctl status_bar "$udid" override \
    --time "2007-01-09T09:41:00.000${offset:0:3}:${offset:3}" \
    --batteryState charged --batteryLevel 100 --wifiBars 3 --dataNetwork wifi \
    || echo "Status bar not overridden (fine for a look, not for a store shot)." >&2

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
  ${MODE:+-yomidori-mode "$MODE"} ${RECOGNIZE:+-yomidori-recognize} ${NOPAGE:+-yomidori-nopage} ${BEGIN:+-yomidori-begin} ${CARD:+-yomidori-card "$CARD"} ${ENTRY:+-yomidori-entry "$ENTRY"} ${PICTURE:+-yomidori-picture "$PICTURE"} \
  ${DEMO_LANG:+-AppleLanguages "($DEMO_LANG)"} >/dev/null
[ -n "${YOMIDORI_UDID_FILE:-}" ] && echo "$udid" > "$YOMIDORI_UDID_FILE"
# Named, with its runtime: DeviceHub shows only the devices opened in it, so the reader
# needs to know which one to open.
where=$(xcrun simctl list devices | awk -v u="$udid" \
    '/^-- /{rt=$2" "$3} index($0,u){sub(/^ +/,""); sub(" \\(" u "\\).*$",""); print $0", "rt; exit}')
echo "Demo launched on ${where:-$udid} ($udid) — seeded cards, collections and a page; nothing persists."
echo "Not on your screen? Open that simulator in DeviceHub (File › New Window, or the sidebar)."
