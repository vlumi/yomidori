#!/usr/bin/env bash
# Build, install and launch the iOS app on a paired iPhone or iPad, signed with
# the committed team's automatic signing.
#   Usage: run-device.sh [device-name-substring]
# The camera exists only on a real device, so this is how the capture flow is
# tried over a real book; the simulator lane is run-ios.sh. The device must be
# plugged in or reachable over Wi-Fi, unlocked, and in Developer Mode.
set -euo pipefail
cd "$(dirname "$0")/.."

bundle_id="fi.misaki.yomidori"
derived=".build-xcode"
device="${1:-}"

# Pick a device from CoreDevice's list (the phones Xcode has paired). With no
# filter, the one connected device wins, or the only paired one; with a name
# substring, the best name match — exact, then shortest — and fail on none.
list="$(mktemp)"
trap 'rm -f "$list"' EXIT
xcrun devicectl list devices --json-output "$list" >/dev/null
picked="$(DEVICE="$device" python3 - "$list" <<'PY'
import json, os, sys
want = os.environ.get("DEVICE", "").strip().lower()
devices = json.load(open(sys.argv[1]))["result"]["devices"]
matches = []
for d in devices:
    hw = d.get("hardwareProperties", {})
    name = d.get("deviceProperties", {}).get("name", "")
    if hw.get("platform") != "iOS" or (want and want not in name.lower()):
        continue
    connected = d.get("connectionProperties", {}).get("tunnelState") == "connected"
    matches.append((name.lower() != want, not connected, len(name), name, d["identifier"], hw.get("udid", "")))
if not matches:
    sys.exit(0)
if not want and len(matches) > 1 and not any(m[1] is False for m in matches):
    print("\n".join(f"  {m[3]}" for m in sorted(matches)), file=sys.stderr)
    sys.exit(2)
_, _, _, name, identifier, udid = sorted(matches)[0]
print(f"{identifier}\t{udid}\t{name}")
PY
)" || {
    echo "error: several paired devices and none connected; pick one: make run-device DEVICE=<name>" >&2
    exit 1
}
[ -n "$picked" ] || {
    echo "error: no paired iOS device${device:+ matching '$device'} found (xcrun devicectl list devices)" >&2
    exit 1
}
IFS=$'\t' read -r identifier udid name <<<"$picked"
echo "Device: $name ($udid)"

echo "Building Yomidori-iOS for the device..."
xcodebuild -project Yomidori.xcodeproj -scheme Yomidori-iOS \
    -destination "id=$udid" -derivedDataPath "$derived" -configuration Debug \
    -allowProvisioningUpdates build >/dev/null 2>&1 || {
    echo "build failed; re-running with full output:" >&2
    xcodebuild -project Yomidori.xcodeproj -scheme Yomidori-iOS \
        -destination "id=$udid" -derivedDataPath "$derived" -configuration Debug \
        -allowProvisioningUpdates build
    exit 1
}

products="$derived/Build/Products/Debug-iphoneos"
app="$(find "$products" -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"
[ -n "$app" ] && [ -d "$app" ] || {
    echo "error: no built .app found in $products" >&2
    exit 1
}

echo "Installing and launching $bundle_id on $name"
xcrun devicectl device install app --device "$identifier" "$app"
xcrun devicectl device process launch --device "$identifier" "$bundle_id"
