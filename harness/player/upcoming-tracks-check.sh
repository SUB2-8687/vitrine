#!/bin/sh
# Compile the production data helpers as plain Objective-C, without UIKit or Logos hooks.
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC=${SRC:-$(cd "$HERE/../../tweak/Sources" && pwd)}
OUT=$(mktemp -d /tmp/player-upcoming-check.XXXXXX)
trap 'rm -rf "$OUT"' EXIT
python3 - "$SRC/Shared/Player/PlayerState.x" "$OUT/player-state-data.inc" <<'PY'
import pathlib
import re
import sys

source = pathlib.Path(sys.argv[1]).read_text()
functions = []
for name in ("SGURIString", "SGPlayerUpcomingTracks"):
    matches = re.findall(r"^[^\n]*\b" + name + r"\([^\n]*\) \{\n.*?^\}", source, re.M | re.S)
    if len(matches) != 1:
        raise SystemExit(f"expected one complete definition of {name}, found {len(matches)}")
    functions.append(matches[0])
pathlib.Path(sys.argv[2]).write_text("\n\n".join(functions) + "\n")
PY
xcrun clang -fobjc-arc -I"$OUT" "$HERE/upcoming-tracks-check.m" -framework Foundation -o "$OUT/check"
"$OUT/check"
# The audio quality badge's rules, read from the same player reports, compiled from their own file as it ships.
xcrun clang -fobjc-arc -I"$SRC" "$HERE/audio-quality-check.m" "$SRC/Shared/Player/AudioQualityRules.m" -framework Foundation -o "$OUT/quality"
"$OUT/quality"
