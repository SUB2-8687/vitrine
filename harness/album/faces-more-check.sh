#!/bin/sh
# The album header's artist faces (faces-check.h) and the track rows' ⋯ in the page's colour (more-check.h), in a
# simulator of its own, made for the run and deleted after it, on the album harness build.sh built (in build/, or
# HARNESS_BUILD_DIR): the faces left to right, right to left and at the largest text size, the ⋯ with and without
# Increase Contrast. Then mutants, built from a copy of the sources (faces-more-mutation.py), must each fail at their
# own assertion: faces not held to three, a picture in a view hidden since the pass drawn, an avatar's initial taken
# for the name, a face told by its image view's own shape, an avatar known only by a shown picture (left to right and
# right to left), and a baked ⋯ given only a tint. Exits nonzero on any failure.
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

# mutant <name> <pass text> <expected failure> <launch arguments...>
mutant() {
    name=$1 passed=$2 failure=$3
    shift 3
    cp -R "$HERE/../../tweak/Sources" "$WORK/src-$name" || return 1
    python3 "$HERE/faces-more-mutation.py" "$WORK/src-$name" "$name" || return 1
    HARNESS_SRC="$WORK/src-$name" HARNESS_BUILD_DIR="$WORK/build-$name" sh "$HERE/build.sh" > "$WORK/build-$name.log" 2>&1 \
        || { cat "$WORK/build-$name.log"; return 1; }
    xcrun simctl install "$UDID" "$WORK/build-$name/AlbumHarness.app" || return 1
    $RUN "$passed" --fail "$failure" -- "$@"
}
mutant faces-cap "PASS album faces" "more than three faces" faces || status=1
mutant faces-hidden "PASS album faces" "hidden before their pictures landed" faces || status=1
mutant faces-initials "PASS album faces" "the phone's Trio row" faces || status=1
mutant faces-image-shape "PASS album faces" "the phone's Trio row" faces || status=1
mutant faces-hidden-initial "PASS album faces" "Dolly's picture hidden" faces || status=1
# The same mutant right to left, on the build just made.
# shellcheck disable=SC2086
{ xcrun simctl install "$UDID" "$WORK/build-faces-hidden-initial/AlbumHarness.app" \
    && $RUN "PASS album faces" --fail "Dolly's picture hidden" -- $RTL faces; } || status=1
# shellcheck disable=SC2086
mutant more-mask "PASS album more" "baked ⋯" $COLOURED more || status=1
exit $status
