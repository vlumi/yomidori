#!/usr/bin/env bash
# The bundled dictionary is built, not committed; the project must be generated
# with it present or the app ships without it. Run before every xcodegen
# (slipway.yml's pre_generate), so make and the release lane both see to it.
set -euo pipefail
cd "$(dirname "$0")/.."

dictionary="Sources/Shared/Dictionaries/jmdict.sqlite"
[ -f "$dictionary" ] || Scripts/data/build-jmdict.py --output "$dictionary"
