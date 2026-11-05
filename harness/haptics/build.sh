#!/bin/sh
# Build the requested executable only; analyzer and ring are manual modes.
set -e
cd "$(dirname "$0")"
OUT=${OUT:-build}
mkdir -p "$OUT"
case "${1:-track}" in
analyzer)
xcrun clang -fobjc-arc -O2 -Wall -Werror -I ../../tweak/Sources -framework Foundation -framework AudioToolbox \
    main.m ../../tweak/Sources/Shared/Haptics/SGMusicAnalyzer.m -o "$OUT/haptics"
    ;;
track)
xcrun clang -fobjc-arc -O2 -Wall -Werror -I ../../tweak/Sources -framework Foundation \
    track.m ../../tweak/Sources/Shared/Haptics/SGHapticTrack.m ../../tweak/Sources/Shared/AdBlock/Protobuf.m -o "$OUT/track"
    ;;
ring)
xcrun clang -fobjc-arc -O1 -g -Wall -Werror -fsanitize=thread -I ../../tweak/Sources -framework Foundation \
    ring.m -o "$OUT/ring"
    ;;
*) echo "usage: $0 [track|analyzer|ring]" >&2; exit 2 ;;
esac
