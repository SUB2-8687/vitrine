#!/bin/sh
# Builds the sleep timer harness for the Mac: SleepTimer.m as the tweak compiles it, the UIKit headers it
# imports stood in for by stub/, SpotifySleepTimer.m (Spotify's own timer followed) and main.m.
set -e
cd "$(dirname "$0")"
OUT=${OUT:-build}
mkdir -p "$OUT"
xcrun clang -fobjc-arc -O2 -Wall -Werror -I stub -I ../../tweak/Sources -framework Foundation \
    main.m clock.m timer-source.m spotify-source.m \
    ../../tweak/Sources/Core/SGLocalize.m \
    -o "$OUT/sleep-timer"
echo "built $OUT/sleep-timer"
