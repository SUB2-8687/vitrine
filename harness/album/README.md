# Album harness

Spotify's album page mocked under its own class names and accessibility identifiers
(from `trees/clean/album/03.txt`), so `Redesigned/Album/` can be laid out and looked at
on the Mac without the phone.

    THEOS=$HOME/theos ./build.sh
    xcrun simctl install booted build/AlbumHarness.app
    xcrun simctl launch booted com.vojta.albumharness
    xcrun simctl io booted screenshot shot.png

`build.sh` runs `logos.pl -c generator=internal` over the album's `.x` files and the redesign's AMOLED rule
(`Kit/SGRAmoled.x`, so the page is painted as on the phone: a low grey field shows black) and links them with the
real `Core/` and `Redesigned/Kit/` sources; `stubs.m` stands in for the two hook files the harness
does not compile (`SGRAccent.x`, `SGRRepaint.x`).

The mock is the page as Spotify builds it: the color wash behind the header, the header itself down
its four stack views, the metadata row as a real collection view with its own cells, the action row of
explore, add, download and more, the two controls Spotify floats over the page outside the scroll
(shuffle and play), and a list of track cells followed by the footer Spotify sends — the album's own
line, the copyright, and the headings and carousels of more by, videos, merch and you might also like,
each with the 16pt spacer between them.

At 1.5 s it measures the footer the way the page's collection does, asking every cell
`preferredLayoutAttributesFittingAttributes:` and stacking the answers: that is where `AlbumSections.x`
answers 0 for what it drops, and the log says how much footer was left (108pt of 1489pt, the album's
own line and its copyright). A switch is turned off from the launch line, as an argument default, and
brings its section back: `-spotifyglass.redesign.album.hide.merch NO` measures 374pt, `.moreBy` 371pt,
`.videos` 412pt, `.youMightLike` 370pt, and `.other` 367pt for Fans also like, the section no switch names.

Since 2026-09-18 the header is the Kit's `SGRHeaderInfo` over Spotify's blanked column, so what follows no
longer tests anything the redesign moves; it still shows Spotify's column staying blank. The metadata row's
cells arrive after the header's pass, which is what `AlbumHeader.x`'s re-read answers.

`late` on the launch line (`xcrun simctl launch booted com.vojta.albumharness late`) opens the album the way a
first open has it, with no add in the row, and adds it at 2.5 s as an arranged subview of the row, which lays out
nothing above the row. At 3 s the log says what the row shows on Play's right: "Add" once `AlbumHeader.x` watches
the row, "Download" before it did (issue #19).

At 3.5 s it puts Spotify's own frames back on the title block, its stack and the action row and asks
both groups for a layout pass, which is what the redesign's `SGRObserveLayout` watches have to survive.
The log says what the redesign answered with.

`motion` on the launch line, with `SIMCTL_CHILD_HARNESS_CANVAS_FILE` set to any mp4, hands the hero that clip at
2 s the way Apple Music's catalog would. The log says the clip was added at opacity 0 and not yet fading, that by
2.5 s its first frame was ready and it had faded in and was playing, and that taken out of the window at 4.5 s it
stopped and put back it played again.

`SGLog` goes to the unified log rather than stdout, so the redesign's own lines are read with

    xcrun simctl spawn booted log stream --predicate 'eventMessage CONTAINS "spotifyglass"' --style compact

What it does not cover: the real element framework's autolayout and the heights it measures, the page
scrolling (Spotify fades the header out by alpha as it goes, which the mock does not), and the flags
`AlbumField.x` forces.

`download` on the launch line plays the download button's states instead of the header's (issue #65), from
`../download-mock.h`: Spotify's button drawn by Lottie with no image view, its state in its accessibility
identifier and in a mock of the Encore object behind it (`currentState`, `progress`), and shuffle's "on" dot.
None, waiting, downloading (held at 50%), downloaded, shuffle on, removed with shuffle off, error, each held a
few seconds and announced with a `[harness] state:` line to take a screenshot on. Nothing in it lays anything
out, as on the phone.

The track rows carry Spotify's explicit badge on some of them and two guests the header does not explain (one named
in the title with no "feat.", one not at all). At 2.5 s the log says, row by row, whether its artist line was
dropped, how far the title moved and where the badge was drawn against the end of the title's text; at 4 s the first
row is prepared for reuse and has to come back as Spotify drew it, then be dropped again by its next pass. At 3 s
the log also says the first card of each carousel, painted the base surface, was cleared and the gray one was not.

The artist row's picture (an `Encore.ImageView`) gets its image at 1.5 s, after the header has laid out. At 2.2 s the
log says where the redesign drew it: a round face a line and a point across just before the name, 8pt off it, the two
centered together (`{{138, 370.33}, {22, 22}}` and the name at `{{168, 371}, {96, 21}}` on an iPhone 17 Pro).

`faces-more-check.sh` (`python3 scripts/harness-plan.py run --names "Album faces and row more"`, after `build.sh`) runs
two scenarios of this harness in a simulator of its own and asserts them. `faces` (`faces-check.h`) builds the artist
row again for one to four artists, a hidden face, one under a hidden view and a square badge after the names, pictures
that land late or are emptied, pictures landing in views hidden since the header's pass, a row whose name is only its
accessibility label with a square badge after the faces (no faces), five layouts that change nothing (no cut-ring
path made again), the header reused for another album, and the rows the phone dumped
(`.mixdog/review-shots/phone-v100/trees/*-artist-parent-annotated.txt`: Trio, Love for Sale and 21, each face a 24pt
square avatar holding its initial letter and a clipped image view, Trio's last one 32x24, the names in one label after
them; every artist's face must show, and with Dolly's picture or the square clipping it hidden while her initial
shows, the other two), and checks the Albums page's Artist picture
(`spotifyglass.redesign.album.artistPicture`) against the spec: at most three faces in the row's order, each
min(ceil(line height) + 1, 22) across, round(0.85 x that) apart, 8pt before the name, centred with it, a clear 1.5pt
ring around each face cut out of the next (read off the drawn pixels), a tap on them the line's (Spotify's row fired
once), not accessibility elements; switched off live, the name alone centred with no room kept. It runs left to right,
right to left (`-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES`) and at the largest text size, where the
22pt cap holds. `more` (`more-check.h`, on `-coverFixture colourful`) gives track rows a baked white ⋯, Spotify's template
symbol, one that lands late, one replaced by another picture, none, one under a mask of its own and one reused as no
track row, and reads the drawn glyph in OKLab: lightness 0.80 (0.88 with Increase Contrast, set on the simulator), the
page's hue, chroma at most min(page's, 0.08) and at least half that; white and unmasked where it is to be left alone; ⋯'s action and what VoiceOver
reads unchanged. Mutants built from a copy of the sources (`faces-more-mutation.py`) must fail at their assertion:
four faces allowed, a picture in a view hidden since the pass drawn, an avatar's initial taken for the name and a face
told by its image view's own shape (both at the phone's Trio row), an avatar known only by a shown picture (at Trio with
Dolly's picture hidden, left to right and right to left), and a baked ⋯ given only a tint. `SHOTS=<dir>` keeps
`album-faces-two-on.png`, `album-faces-two-off.png`, `album-faces-trio.png` and `album-more.png` (and the variants, suffixed).

The pinned download and ⋯ are watched from the first frame the page draws: after every Core Animation commit while the
field's veil is up and a second past it, ⋯ must have glass behind it, its own or download's capsule with download
right under ⋯ in the page, nothing (the veil) between the two. "PASS pinned hold: N frames, M under the veil" or
"FAIL pinned hold" with the page's top subviews at the first bare frame; `verify-actions` checks it and logs then exits nonzero on failure. `rtl` lays the page
out right to left (its `semanticContentAttribute`), and `verify-actions` then expects ⋯ 16pt in from the left edge,
download on its right, the 88x44 capsule the left-to-right one mirrored ("pinned frames rtl" against "pinned frames
ltr"). `freeze` pauses the veil's fade and holds the main thread 4 s on the first frame under the veil, for a
screenshot of what a page opening shows.

`veil` on the launch line, with `-spotifyglass.redesign.hero.scrollVeil YES`, checks the page headers' scroll veil
(`Redesigned/Kit/SGRHeroVeil.h`, `hero-veil-check.h`): the blur's radius and the dim's alpha at the spec's distances,
the picture's parallax and pull zoom, the dim in the page's color and the header fading in over the 14pt under the top
bar; `veil-card`, with `-spotifyglass.redesign.album.fullCover NO -spotifyglass.redesign.album.motion NO` as well,
checks the same blur and dim on the square's picture alone, the square left where it is; `veil-off`, without the
setting, checks that none of it is drawn. Each holds d = 0, 190 and 400 (with the veil on, "mid" too: the title half
under the bar) for screenshots first, then exits 0 or logs a FAIL and exits 1. `veil-check.sh <UDID> [OUT]` builds this, the playlist and the artist harness and runs all of
it, the artist's Play checks too (`../artist/README.md`), with the screenshots in OUT.

`cover-check.sh` checks the picture-aware cover (`-spotifyglass.redesign.album.adaptiveCover`, Full screen only;
`Redesigned/Kit/SGRCoverRead.h`, the hero in `Redesigned/Album/AlbumHeader.x`) as Mac Catalyst programs, no simulator
(`python3 scripts/harness-plan.py run --names "Album cover"`). The covers are drawn in code (`cover-fixtures.h`).
The hero builds compile the redesign's AMOLED rule (`Kit/SGRAmoled.x`) as `build.sh` does.
`cover-read-check.m` reads each: solid dark, light and red sleeves with centred art, the same sleeve broken along 8% of
its border (still solid) and with art over 72% of it (not), a tiny logo on black, a dark cover with a large orange
accent, the old rectangle portrait (confirmed to produce zero real Vision faces) with an injected face box through
the foot to check exclusion, a softened drawn face detected by real Vision with a sharp boundary below it,
colourful bands, Vision failing, a transparent
and a too narrow cover, the same picture twice (the cache's reading), and page colours brought into sRGB by chroma
alone. `cover-hero-check.m` draws five of them in the album's hero on a page with its field: the field in the read
colour, the cover itself down to where the spec lets it stop being sharp, the drawing over it from there continuous with
it and ending in the colour the field paints just under the hero (read off the rendered field, the hero's gradients
composited over the drawing; at most 2 levels apart), and the title's area held to L 0.58 over 90% of it. One of them is
Adele's 21 as the phone showed it (`darkPortraitCover`, `dark-portrait`): a black-and-white portrait reading #0D0C0C,
which the AMOLED rule paints black; the `field-asked` mutant (the field reporting the colour it was asked for rather than
the one it paints) must fail there with the phone's 13,13,13 over 0,0,0. The scanned sleeve checks the
pale border and reflected square edge, including the actual layer composition: adjacent-row mean absolute linear
sRGB luminance difference must not exceed 0.02 within 24pt of the edge. The layer composition also checks
24pt above the scanned sleeve's stripe at 94% through the square's extension; the drawing must be opaque.
The runner reintroduces a one-pixel bright row in a generated-source copy and requires the edge assertion to reject it.
`still-swap` reuses a hero from A with a clip to B without one: both an installed still and late poster/read replies
must leave B blue. A -> B -> A reuses the identical clip URL and checks both delayed stages against the new album
lifetime, then accepts its current still. Media lookup, poster delivery and player readiness are test doubles;
the field and hero are real. `cache-reuse` aliases only the address prefix of cache keys after the first source
deallocates; a mirrored cover with identical size, page colour and geometry must draw blue, not the old magenta.
Generated-source mutations remove album-change invalidation, both still-generation guards, or cache source
validation, and each must fail at the corresponding colour/pixel assertion. `Kit/SGRCoverRead` is not modified.
The blur reaches its maximum over 40pt rather than 80pt: 80pt left a measured 19/255 step at the scanner border.
Also checked: a cover replaced mid read whose
colour never reaches the page; and, with the setting off, the hero written to a PNG. `BASELINE=<rev>` draws that
revision's off hero too and requires the same bytes.

`-coverFixture colourful|portrait|darkAccent|solidLight|solidDark|darkPortrait` on this harness's launch line shows one of those
covers instead of the scanned sleeve (`portrait` uses the real-Vision drawn face), and `cover-stats` logs the process's memory footprint and its peak at 6 s with a
`[harness] SHOT album-cover-<cover>-<on|off>` line; the hero's own log says how long the read and the drawing took.
The drawing log separates queue wait from rendering and reports canvas, blur, colour mix and title measurement
times on the utility queue. The transition image is capped at 2x; the sharp cover stays at native display scale.
The radius bands use Gaussian blur rather than an all-white variable-blur mask: the latter did no spatial
masking but consumed 2249ms of a measured 2404ms warm dark-accent render.
`cover-stats` also writes the unmodified fixture to the app's Documents/cover-fixture.png for pixel comparisons.
`cover-profile -spotifyglass.redesign.album.adaptiveCover YES -spotifyglass.redesign.album.motion NO` changes
through the five fixtures in one process, so stage timings include the normal reused CIContext, not only cold
application launches. It exits after the final cover; timings are in the unified log.
Use `-spotifyglass.redesign.album.motion NO` for fixture screenshots, otherwise the album's fetched animated
artwork can replace the fixture before the screenshot marker.

`stubs.m` also stands in for `SGRegisterCustomFont`, which `Shared/Fonts/Fonts.x` calls and which lives in a file
that pulls in the settings rows.
