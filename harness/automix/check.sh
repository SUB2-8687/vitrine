#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC=${SRC:-$(cd "$HERE/../../tweak/Sources" && pwd)}
FACTS_SOURCE=${FACTS_SOURCE:-$SRC/Shared/AutoMix/SGTransitionFacts.m}
OUT=$(mktemp -d "${TMPDIR:-/tmp}/automix-check.XXXXXX")
trap 'rm -rf "$OUT"' EXIT
xcrun clang -fobjc-arc -fblocks -Wno-objc-property-implementation \
    -I"$HERE/../shared/foundation" -I"$SRC" -I"$SRC/Shared/AutoMix" "$HERE/check.m" "$FACTS_SOURCE" \
    -framework Foundation -o "$OUT/automix-facts-check"
"$OUT/automix-facts-check"
