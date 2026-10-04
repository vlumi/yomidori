#!/usr/bin/env bash
# App Store screenshot capture, hands-off: for every language and every shot in
# Scripts/asc/shots.json, relaunches the demo with the arguments that stage the
# shot, waits for it to settle, and captures — no staging, no ⌘S, no renaming.
# Output lands canonically named at
#   <OUT>/<platform>/<lang>/<shot>-<platform>.png
# ready for `make asc-screenshots`.
#   PLATFORM=iphone|ipad|mac   (default iphone)
#   LANGS=en,ja                (default en,ja)
#   OUT=shots                  (default ./shots)
#   SETTLE=<seconds>           wait after launch before the capture (default 6)
#   PAUSE=1                    stop before each capture: ⏎ capture · r retake · s skip
#   ONLY=<name,name>           just these shots
# Mac: window capture needs Screen Recording permission for your terminal
# (System Settings ▸ Privacy & Security) — macOS prompts on first use.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
LANGS="${LANGS:-en,ja}"
OUT="${OUT:-shots}"
SETTLE="${SETTLE:-6}"
BUNDLE="fi.misaki.yomidori"
APP_NAME="Yomidori"
# The store's sizes: iPhone 6.9" 1320×2868, iPad 13" 2064×2752, Mac 1440×900 (@2x).
MAC_WIDTH=1440
MAC_HEIGHT=900

case "$PLATFORM" in
    mac) ;;
    iphone | ipad) make build-ios >/dev/null ;;
    *) echo "PLATFORM must be iphone | ipad | mac" >&2; exit 2 ;;
esac

# The window of the app's own process: the executable name is never localized,
# but the window owner's NAME is (ヨミドリ under ja), so names are not trusted.
mac_window_id() {
    for _ in $(seq 1 20); do
        local pid
        pid=$(pgrep -x "$APP_NAME" | head -1)
        if [ -n "$pid" ]; then
            if id=$(swift Scripts/asc/window-id.swift "$pid" 2>/dev/null); then
                echo "$id"; return 0
            fi
        fi
        sleep 1
    done
    return 1
}

# The window at the store's size, by points; a Retina screen captures it @2x.
mac_size_window() {
    osascript -e "tell application \"System Events\" to tell process \"$APP_NAME\" to set size of window 1 to {$MAC_WIDTH, $MAC_HEIGHT}" >/dev/null 2>&1 || true
}

capture() {  # $1 = output file
    mkdir -p "$(dirname "$1")"
    if [ "$PLATFORM" = mac ]; then
        screencapture -o -x -l"$WINDOW_ID" "$1" || {
            echo "The window grab failed: give your terminal Screen Recording permission" >&2
            echo "(System Settings ▸ Privacy & Security ▸ Screen & System Audio Recording) and run again." >&2
            quit_app; exit 1
        }
    else
        xcrun simctl io "$SIM_UDID" screenshot --display=internal "$1" >/dev/null
    fi
}

# Launch the demo staged for one shot; $1 = language, the rest KEY=value demo args.
launch() {
    local lang="$1"; shift
    if [ "$PLATFORM" = mac ]; then
        env DEMO=1 DEMO_LANG="$lang" BUILD=0 "$@" Scripts/run-mac.sh >/dev/null
        WINDOW_ID=$(mac_window_id) || { echo "App window never appeared." >&2; exit 1; }
        mac_size_window
    else
        local udid_file
        udid_file=$(mktemp)
        env PLATFORM="$PLATFORM" DEMO_LANG="$lang" YOMIDORI_UDID_FILE="$udid_file" "$@" \
            Scripts/demo.sh >/dev/null
        SIM_UDID=$(cat "$udid_file")
        rm -f "$udid_file"
    fi
}

quit_app() {
    if [ "$PLATFORM" = mac ]; then
        osascript -e "tell application id \"$BUNDLE\" to quit" >/dev/null 2>&1 || true
        sleep 1
        pkill -x "$APP_NAME" >/dev/null 2>&1 || true
    else
        [ -n "${SIM_UDID:-}" ] && xcrun simctl terminate "$SIM_UDID" "$BUNDLE" >/dev/null 2>&1 || true
    fi
    return 0
}

# One signed Mac build for the whole run; the launches below reuse it.
if [ "$PLATFORM" = mac ]; then
    quit_app
    DEMO=1 Scripts/run-mac.sh >/dev/null
    quit_app
fi

IFS=',' read -ra langs <<< "$LANGS"
total=$(python3 Scripts/asc/shots.py "$PLATFORM" --plain | wc -l | tr -d ' ')

for lang in "${langs[@]}"; do
    echo ""
    echo "━━━ $PLATFORM / $lang ━━━"
    i=0
    while IFS=$'\t' read -r name title args stage; do
        i=$((i + 1))
        if [ -n "${ONLY:-}" ] && ! [[ ",$ONLY," == *",$name,"* ]]; then continue; fi
        file="$OUT/$PLATFORM/$lang/${name}-${PLATFORM}.png"
        echo "[$lang $i/$total] $name — $title"
        quit_app
        # shellcheck disable=SC2086
        launch "$lang" $args
        sleep "$SETTLE"
        if [ -n "$stage" ] || [ -n "${PAUSE:-}" ]; then
            [ -n "$stage" ] && echo "  stage: $stage"
            while :; do
                printf "  ⏎ capture · s skip · q quit: "
                read -r reply </dev/tty
                [ "$reply" = q ] && { quit_app; exit 0; }
                [ "$reply" = s ] && continue 2
                capture "$file"
                printf "  saved %s — ⏎ next · r retake: " "$file"
                read -r again </dev/tty
                [ "$again" = r ] || break
            done
        else
            capture "$file"
            echo "  saved $file"
        fi
    done < <(python3 Scripts/asc/shots.py "$PLATFORM" --plain)
    quit_app
done

echo ""
echo "Done. Sets under $OUT/$PLATFORM/ — \`make asc-screenshots\` shows the upload plan."
