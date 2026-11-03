#!/usr/bin/env bash
# Launch the app in DEMO mode on a simulator: every store routed to a folder wiped and
# reseeded at launch with fixed public-domain data (some hundred cards from four novel
# openings at every rank, collections with covers, a history) and a rendered page open under Read, so the
# screens can be looked at without a camera. The real simulator data is never touched.
#   PLATFORM=iphone|ipad   (default iphone)
#   DEVICE=<name pattern>  narrow the pick (a regex on the name, or a udid)
#   HEADLESS=1             any matching simulator, not only one DeviceHub shows (shoot.sh)
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

# Where the demo runs. Interactively: only on a device a DeviceHub window shows, since a
# simulator outside DeviceHub is invisible (Xcode 27 has no Simulator.app); none fits, it
# stops and says what DeviceHub shows. HEADLESS=1 (shoot.sh): any matching simulator,
# booted if need be, as screenshots don't need to be seen.
#   DEVICE=<pattern>   narrows the pick, a grep regex on the name (or a udid)
case "$PLATFORM" in
    iphone) family="iPhone" ;;
    ipad) family="iPad" ;;
    *) echo "PLATFORM must be iphone | ipad" >&2; exit 2 ;;
esac
pat="${DEVICE:-$family}"

if [ -z "${HEADLESS:-}" ]; then
    shown=$(osascript -e 'tell application "System Events"
        if not (exists process "DeviceHub") then return ""
        tell process "DeviceHub" to set n to name of every window
        set AppleScript'"'"'s text item delimiters to linefeed
        return n as text
    end tell' 2>/dev/null) || shown=""
    [ -n "$shown" ] || {
        echo "DeviceHub shows no simulator. Open an iOS 26+ $family in DeviceHub, then run again." >&2
        exit 1
    }
    # Each window ("iPhone 17 – iOS 26.4.1") to the booted simulator of that name and
    # runtime; kept when it is the family, iOS 26 or later, and matches DEVICE.
    udid=$(xcrun simctl list devices booted --json | SHOWN="$shown" PAT="$pat" FAMILY="$family" \
        python3 -c '
import json, os, re, sys
devices = json.load(sys.stdin)["devices"]
pat, family = os.environ["PAT"], os.environ["FAMILY"]
by_udid = re.fullmatch(r"[0-9A-Fa-f-]{36}", pat) is not None
for window in os.environ["SHOWN"].splitlines():
    m = re.match(r"(.+?) [–-] iOS (\d+)\.(\d+)", window.strip())
    if not m:
        continue
    name, major, minor = m.group(1), int(m.group(2)), int(m.group(3))
    udid = next((d["udid"] for rt, devs in devices.items() if rt.endswith(f"iOS-{major}-{minor}")
                 for d in devs if d["name"] == name), None)
    if family not in name:
        why = "not an " + family
    elif major < 26:
        why = f"iOS {major}.{minor}, the app needs iOS 26"
    elif by_udid and udid != pat.upper() or not by_udid and not re.search(pat, name):
        why = f"not DEVICE={pat}"
    elif not udid:
        why = "not found among the booted simulators"
    else:
        print(udid)
        sys.exit(0)
    print(f"  {window.strip()}: {why}", file=sys.stderr)
sys.exit(1)
') || {
        echo "None of the simulators DeviceHub shows can run the demo (above)." >&2
        echo "Open an iOS 26+ $family in DeviceHub (File › New Simulator, or the sidebar), then run again." >&2
        exit 1
    }
else
    # shellcheck source=Scripts/simulator.sh
    . "$(dirname "$0")/simulator.sh"
    udid_re="[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
    # Only devices under an "-- iOS 26 --" or later heading: the app's minimum.
    ios26='/^-- /{v=($2=="iOS")?$3+0:0; next} v>=26'
    udids=$(xcrun simctl list devices available | awk "$ios26" | grep -E "$pat" \
        | grep -oE "$udid_re" | tail -r)
    [ -n "$udids" ] || { echo "No iOS 26+ simulator matching /$pat/ installed." >&2; exit 1; }
    # shellcheck disable=SC2086
    udid=$(boot_first_simulator $udids) || {
        echo "No simulator matching /$pat/ boots." >&2
        exit 1
    }
fi

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
where=$(xcrun simctl list devices | awk -v u="$udid" \
    '/^-- /{rt=$2" "$3} index($0,u){sub(/^ +/,""); sub(" \\(" u "\\).*$",""); print $0", "rt; exit}')
echo "Demo launched on ${where:-$udid} ($udid) — seeded cards, collections and a page; nothing persists."
