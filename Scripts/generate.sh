#!/usr/bin/env bash
# Regenerate Yomidori.xcodeproj from project.yml.
# Refuses only if *this* project is open in Xcode: regenerating it on disk
# while Xcode holds its in-memory model causes a save conflict and can clobber
# the regenerated file. Unrelated projects open in Xcode are fine.
set -euo pipefail

cd "$(dirname "$0")/.."

project_name="Yomidori.xcodeproj"

if pgrep -x Xcode >/dev/null; then
    # Ask Xcode which documents it has open; refuse only if ours is among them.
    open_docs="$(osascript -e 'tell application "Xcode" to get name of documents' 2>/dev/null || true)"
    if printf '%s' "$open_docs" | grep -q "$project_name"; then
        echo "error: $project_name is open in Xcode. Close it before regenerating." >&2
        exit 1
    fi
fi

if ! command -v xcodegen >/dev/null; then
    echo "error: xcodegen not found (brew install xcodegen)." >&2
    exit 1
fi

# The bundled dictionary is built, not committed; the project must be generated
# with it present or the app ships without it. Every path to a project (make,
# the release lane) comes through here.
dictionary="Sources/Shared/Dictionaries/jmdict.sqlite"
[ -f "$dictionary" ] || Scripts/data/build-jmdict.py --output "$dictionary"

xcodegen generate
echo "Generated Yomidori.xcodeproj"
