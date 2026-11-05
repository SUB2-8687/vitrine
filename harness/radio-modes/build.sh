#!/bin/sh
set -eu
cd "$(dirname "$0")"
OUT=${OUT:-build}
mkdir -p "$OUT"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror -Wno-unused-parameter -I ../shared/foundation -I ../../tweak/Sources \
    -framework Foundation check.m ../../tweak/Sources/Shared/AdBlock/RadioModes.m -o "$OUT/check"
"$OUT/check"
SG_RADIO_TEST_OFF=1 "$OUT/check"
