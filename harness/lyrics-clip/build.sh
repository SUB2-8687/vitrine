#!/bin/sh
# Builds the lyrics clip harness for the Mac: SGLyricsClip.m as the tweak compiles it, and main.m. motion.m
# times the words over moving artwork against SGMotionClip.m's cut, which needs Protobuf.m to link. scenes.m
# checks Messages and Vinyl. SRC=<tree> builds another source tree.
set -e
cd "$(dirname "$0")"
OUT=${OUT:-build}
SRC=${SRC:-../../tweak/Sources}
mkdir -p "$OUT"
xcrun clang -fobjc-arc -O2 -Wno-deprecated-declarations -I "$SRC" \
    -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework CoreImage \
    -framework CoreText -framework CoreGraphics -framework ImageIO -framework UniformTypeIdentifiers -framework Accelerate \
    -framework AppKit \
    main.m motion.m scenes.m "$SRC/Shared/LockScreenLyrics/SGLyricsClip.m" \
    "$SRC/Shared/LyricsBackground/LyricsBackground.m" \
    "$SRC/Shared/AnimatedArtwork/SGMotionClip.m" "$SRC/Shared/AdBlock/Protobuf.m" \
    -o "$OUT/lyrics-clip"
