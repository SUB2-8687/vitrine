#!/bin/sh
# The tabs' glyphs and the now playing card's edges (README, `glyphs` and `edges`) in an iOS simulator of the run's
# own, made for the run and deleted after it, plus `symbols` (Apple symbols) and `audit` (single-tab minimizing and a
# tab's icon view replaced).
# Exits nonzero on the first failed check.
#     THEOS=$HOME/theos OUT=/tmp/<dir> ./bar-check.sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT=${OUT:-$HERE/build}
OUT=$OUT sh "$HERE/build.sh"

TYPE=$(xcrun simctl list devicetypes | sed -n 's/.*(\(com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro\))$/\1/p' | head -1)
RUNTIME=$(xcrun simctl list runtimes available | sed -n 's/.* - \(com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*\)$/\1/p' | tail -1)
UDID=$(xcrun simctl create "TabBarHarness-$$" "$TYPE" "$RUNTIME")
trap 'xcrun simctl shutdown "$UDID" >/dev/null 2>&1; xcrun simctl delete "$UDID" >/dev/null 2>&1' EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" >/dev/null
xcrun simctl install "$UDID" "$OUT/TabBarHarness.app"

# A launch that ends itself: the line it must print.
run() {
    expected=$1
    shift
    xcrun simctl launch --console-pty --terminate-running-process "$UDID" com.vojta.tabbarharness "$@" > "$OUT/run.log" 2>&1 || true
    grep '\[harness\] \(PASS\|FAIL\)' "$OUT/run.log" || true
    grep -q "$expected" "$OUT/run.log" || { echo "FAILED: $*"; exit 1; }
}

run "PASS all glyphs" glyphs
run "PASS all glyphs" glyphs swift
run "PASS all symbols" symbols
run "PASS single-tab minimization" audit
run "PASS all edges" none edges
run "PASS all edges" split edges
run "PASS all edges" split2 edges
run "PASS all edges" jam edges
run "PASS all edges" none edges regular
run "PASS all edges" none edges rtl
echo "PASS tab bar glyph and edge checks"
