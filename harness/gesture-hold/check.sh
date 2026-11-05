#!/bin/sh
# Builds and runs the hold-speed helper check on the Mac. SRC may point at a copy of tweak/Sources.
set -eu
cd "$(dirname "$0")"
SRC=${SRC:-../../tweak/Sources}
OUT=${OUT:-build}
mkdir -p "$OUT"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Werror -Wno-unused-parameter -I "$SRC" \
    -framework Foundation check.m "$SRC/Shared/Gestures/GestureHold.m" "$SRC/Core/SGPrefs.m" "$SRC/Core/SGLocalize.m" \
    -o "$OUT/check"
"$OUT/check"
