# Artist harness

Spotify's artist page mocked under its own class names and accessibility identifiers (from
`trees/clean/artist/01.txt` and `05.txt`, recorded 2026-09-16), so `Redesigned/Artist/` can be laid out and
looked at on the Mac without the phone.

    THEOS=$HOME/theos ./build.sh
    xcrun simctl install booted build/ArtistHarness.app
    xcrun simctl launch booted com.vojta.artistharness            # at rest
    xcrun simctl launch booted com.vojta.artistharness collapsed  # the header scrolled into its 100pt bar

The Music list is a real self-sizing collection view holding the sections in the order the tree has them,
the two video sections included, so `ArtistSections.x` drops them the way it does on the phone: the shelf
first, then its heading and spacer once the list lays out again. At 2 s the log lists every cell's height.

`logo` on the launch line, with `-spotifyglass.redesign.artist.logo NO` after it so Apple Music's own logo does
not arrive as well, hands the header a logo at 2.5 s and takes it away at 4.5 s, with the page on screen. The log
says, before, as each arrives or leaves and a second later, where the logo and the name are and whether they are
fading and moving: the two cross over, the logo grows out of the name's place, and gone, the logo is hidden.

`veil` / `veil-off` check the scroll veil as on the album (`../album/README.md`, `../album/hero-veil-check.h`).
`verify-play` checks the row's Play: unset, the white capsule 48pt tall in the page's color with 48pt buttons 16pt
off it; with `-spotifyglass.redesign.artist.roundPlay YES` a 64pt white circle centered on the page with its glyph
alone and "Play" as its VoiceOver name, 44pt buttons 20pt off and level with it; with
`-spotifyglass.redesign.playInPageColour NO` the glyph in the accent (Spotify's green here) instead; round with
`-spotifyglass.redesign.artist.cutOutPlay YES` too, the glyph unpainted and cut out of the circle by its mask, white or
with `-spotifyglass.redesign.accentPlay YES` the accent. It logs a PASS line and a SHOT for a screenshot, or a FAIL and
exits 1.

`cutout-check.sh` (`python3 scripts/harness-plan.py run --names "Artist cut-out Play"`) checks the cut-out Play itself,
in a Mac Catalyst app of its own: the capsule over slanted stripes, read back pixel by pixel against the stripes alone
and the capsule painted -- Play and Pause, the capsule with its word and a new font, another size, another fill, on and
off, no glyph yet, a disabled source, VoiceOver and a press -- that the mask is not drawn again when nothing changed,
that only round Play is cut out and the album's capsule is not, and the Artists page's card. `CUTOUT_PNG=<dir>` writes
every drawing it reads there; `baseline` only draws the album's capsule and round Play, to compare with another build.

What it does not cover: the repaint hook (so the mock's cells are left unpainted), the real z-order of the
pinned header bar against the list, and the element framework's own sizing.

`verify-listeners` checks the real header/section hooks. Run it with the listeners option off, on,
and on with About hidden:

    THEOS=$HOME/theos python3 harness/artist/listeners-check.py

The check allocates an isolated build directory and a simulator and runs all three cases. It removes
its builds and simulator afterwards. Existing `harness/artist/build/` is untouched.

About membership is learned from a diffable source's completed cell configuration, bound to its item
identifier and artist. Layout only confirms that receipt against the current snapshot; it cannot stamp
a previously unseen cell. The fixture uses UIKit's real snapshot reconfiguration with a retained cell,
including configuration before the header pass and a stale cell with no valid artist. The header
remains until a matching configuration is confirmed. Evidence survives
scrolling/reuse, but not a new artist, data-source replacement, reload, or collection transaction.
No About UI or native localized listener count is changed.
