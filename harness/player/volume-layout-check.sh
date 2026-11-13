#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC=${SRC:-$(cd "$HERE/../../tweak/Sources" && pwd)}
OUT=$(mktemp -d /tmp/volume-layout-check.XXXXXX)
trap 'rm -rf "$OUT"' EXIT
python3 -B - "$SRC/Redesigned/Player" "$OUT" <<'PY'
from pathlib import Path
import sys
source = (Path(sys.argv[1]) / "PlayerFooter.x").read_text()
constants = source[source.index("static const CGFloat kRowAboveSafeArea"):source.index('// "airplayaudio"')]
layout = source[source.index("#pragma mark - lower down"):source.index("%hook _TtC20NowPlaying_ModesImpl18FooterElementsUnit")]
(Path(sys.argv[2]) / "volume-layout-production.inc").write_text(constants + "\n" + layout)
source = (Path(sys.argv[1]) / "PlayerVolume.m").read_text()
constants = source[source.index("static const CGFloat kRowHeight"):source.index("// iOS 26's thumbless")]
placement = source[source.index("static char kVolumeKey"):]
(Path(sys.argv[2]) / "volume-placement-production.inc").write_text(constants + "\n" + placement)
PY
SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun clang -target arm64-apple-ios17.0-macabi -fobjc-arc -isysroot "$SDK" \
    -iframework "$SDK/System/iOSSupport/System/Library/Frameworks" -I"$OUT" \
    "$HERE/volume-layout-check.m" -framework UIKit -framework Foundation -framework CoreGraphics -o "$OUT/volume-layout-check"
"$OUT/volume-layout-check"
