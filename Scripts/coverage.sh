#!/usr/bin/env bash
# Run the package logic tests with coverage, write the report Codecov takes and print what
# is covered, file by file, least covered first. Usage: coverage.sh
#
# Only the targets that are tested count: the SwiftUI layer (YomidoriKit), the Core ML model's
# runner (YomidoriMangaOCR) and the CloudKit side (YomidoriSync) are left out here, the same
# as codecov.yml ignores them, so the figure is of the logic the tests can reach.
set -euo pipefail
cd "$(dirname "$0")/../Packages/YomidoriCore"

IGNORED='(\.build|Tests)/|/Yomidori(Kit|MangaOCR|Sync)/'

swift test --enable-code-coverage

PROF=$(find .build -name '*.profdata' | head -1)
BIN=$(find .build -name 'YomidoriCorePackageTests.xctest' -type d | head -1)/Contents/MacOS/YomidoriCorePackageTests

xcrun llvm-cov export "$BIN" -instr-profile "$PROF" -format=lcov \
    -ignore-filename-regex="$IGNORED" > coverage.lcov
# Absolute SF: paths made repo-relative, so Codecov maps the files. BSD sed, as on macOS.
sed -i '' -E 's#^SF:.*/(Packages/YomidoriCore/)#SF:\1#' coverage.lcov

echo
echo "Lines covered, least first (missed lines, file):"
xcrun llvm-cov report "$BIN" -instr-profile "$PROF" -ignore-filename-regex="$IGNORED" \
    | awk 'NR > 2 && $1 !~ /^-/ && $1 != "TOTAL" && $(NF-3) != "100.00%" {
               printf "  %8s %5d  %s\n", $(NF-3), $(NF-4), $1 }' \
    | sort -n
xcrun llvm-cov report "$BIN" -instr-profile "$PROF" -ignore-filename-regex="$IGNORED" \
    | awk '$1 == "TOTAL" { printf "  %8s %5d  of %d lines, all files\n", $(NF-3), $(NF-4), $(NF-5) }'
