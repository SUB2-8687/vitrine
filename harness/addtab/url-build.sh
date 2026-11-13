#!/bin/sh
set -eu
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
xcrun --sdk macosx clang -fobjc-arc -framework Foundation \
    -I"$ROOT/tweak/Sources/Shared/Navigation" \
    "$ROOT/harness/addtab/url-check.m" "$ROOT/tweak/Sources/Shared/Navigation/LinkURL.m" \
    "$ROOT/tweak/Sources/Shared/Navigation/InboundLinks.m" \
    -o "$WORK/url-check"
"$WORK/url-check"
