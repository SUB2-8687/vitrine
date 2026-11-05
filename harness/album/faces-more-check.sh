#!/bin/sh
# The album header's artist faces (faces-check.h) and the track rows' ⋯ in the page's colour (more-check.h), in a
# simulator of its own, made for the run and deleted after it, on the album harness build.sh built (in build/, or
# HARNESS_BUILD_DIR): the faces left to right, right to left and at the largest text size, the ⋯ with and without
# Increase Contrast. Exits nonzero on any failure.
# SHOTS=<dir> keeps the screenshots the runs ask for (album-faces-two-on/-off, album-faces-trio, album-more, suffixed
# for the variants).
#     THEOS=$HOME/theos sh harness/album/build.sh && THEOS=$HOME/theos sh harness/album/faces-more-check.sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
APP=${HARNESS_BUILD_DIR:-$HERE/build}/AlbumHarness.app
THEOS=${THEOS:-$HOME/theos}
export THEOS
WORK=$(mktemp -d "${TMPDIR:-/tmp}/album-faces-more.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
SHOTS=${SHOTS:-}

TYPE=$(xcrun simctl list devicetypes | sed -n 's/.*(\(com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro\))$/\1/p' | head -1)
RUNTIME=$(xcrun simctl list runtimes available | sed -n 's/.* - \(com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*\)$/\1/p' | tail -1)
UDID=$(xcrun simctl create "AlbumFacesMore-$$" "$TYPE" "$RUNTIME")
trap 'xcrun simctl shutdown "$UDID" >/dev/null 2>&1; xcrun simctl delete "$UDID" >/dev/null 2>&1; rm -rf "$WORK"' EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" > /dev/null
xcrun simctl install "$UDID" "$APP"

RUN="python3 $HERE/run-scenario.py $UDID"
RTL="-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES"
COLOURED="-coverFixture colourful -spotifyglass.redesign.album.motion NO"
status=0
# shellcheck disable=SC2086
$RUN "PASS album faces ltr" --shots "$SHOTS" -- faces || status=1
# shellcheck disable=SC2086
$RUN "PASS album faces rtl" --shots "$SHOTS" --suffix=-rtl -- $RTL faces || status=1
xcrun simctl ui "$UDID" content_size accessibility-extra-extra-extra-large
# shellcheck disable=SC2086
$RUN "capped at 22" --shots "$SHOTS" --suffix=-largest -- faces || status=1
xcrun simctl ui "$UDID" content_size large
# shellcheck disable=SC2086
$RUN "PASS album more: ⋯ at L 0.80" --shots "$SHOTS" -- $COLOURED more || status=1
xcrun simctl ui "$UDID" increase_contrast enabled
# shellcheck disable=SC2086
$RUN "PASS album more: ⋯ at L 0.88" --shots "$SHOTS" --suffix=-contrast -- $COLOURED more || status=1
xcrun simctl ui "$UDID" increase_contrast disabled

exit $status
