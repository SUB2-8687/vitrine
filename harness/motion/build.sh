#!/bin/sh
# Builds the moving artwork harness for the Mac: SGMotionClip.m as the tweak compiles it, with the
# protobuf reader it uses, and main.m.
set -e
cd "$(dirname "$0")"
OUT=${OUT:-build}
mkdir -p "$OUT"
sed '/^static void report/,$d' ../../tweak/Sources/Shared/Player/PlayerState.x > "$OUT/player-state.inc"
xcrun clang -fobjc-arc -O2 -I ../../tweak/Sources \
    -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo -framework CoreGraphics \
    main.m ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionClip.m ../../tweak/Sources/Shared/AdBlock/Protobuf.m \
    -o "$OUT/motion"
xcrun -sdk macosx clang -target arm64-apple-ios17.0-macabi \
    -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
    -iframework "$(xcrun --sdk macosx --show-sdk-path)/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -DSG_MOTION_TEST_STORE -I ../../tweak/Sources -I ../../tweak/Sources/Shared/Player -I "$OUT" \
    -framework UIKit -framework Foundation -framework CoreGraphics -framework AVFoundation -framework CoreMedia -framework CoreVideo \
    -framework Network \
    state-check.m ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionFollower.m ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionTicket.m ../../tweak/Sources/Core/SGLog.m \
    ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionCatalog.m \
    ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionClip.m ../../tweak/Sources/Shared/AdBlock/Protobuf.m \
    -o "$OUT/state-check"
"$OUT/state-check"
xcrun -sdk macosx clang -target arm64-apple-ios17.0-macabi \
    -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
    -iframework "$(xcrun --sdk macosx --show-sdk-path)/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -I ../../tweak/Sources \
    -framework UIKit -framework Foundation -framework CoreGraphics -framework AVFoundation -framework CoreMedia -framework CoreVideo \
    sources-check.m ../../tweak/Sources/Shared/AnimatedArtwork/MotionSources.m ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionTicket.m \
    ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionClip.m ../../tweak/Sources/Shared/AdBlock/Protobuf.m \
    -o "$OUT/sources-check"
"$OUT/sources-check"
xcrun -sdk macosx clang -target arm64-apple-ios17.0-macabi \
    -isysroot "$(xcrun --sdk macosx --show-sdk-path)" \
    -iframework "$(xcrun --sdk macosx --show-sdk-path)/System/iOSSupport/System/Library/Frameworks" \
    -fobjc-arc -I ../../tweak/Sources -framework UIKit -framework Foundation -framework AVFoundation -framework CoreMedia \
    store-check.m ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionStore.m ../../tweak/Sources/Shared/AnimatedArtwork/SGMotionTicket.m -o "$OUT/store-check"
"$OUT/store-check" "$OUT/store-data"
