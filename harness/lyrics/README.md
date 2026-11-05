# Lyrics harness

The redesign's lyrics view (`Redesigned/Lyrics/SGRKaraokeView.m`) playing a song on a clock of the
harness's own, so lines sung over each other, instrumental breaks, pronunciations and translations can
be looked at on the Mac without the phone. The songs are TTML read by the real `SGTTML.m`, or LRC timed
by the real estimate in `KaraokeTiming.m`.

    ./build.sh                  # this checkout; ./build.sh old builds HEAD's for a before and after, OPT=-O2 optimized
    xcrun simctl install <udid> build/new/LyricsHarness.app
    xcrun simctl launch <udid> com.vojta.lyricsharness.new -song duet -at 114000 -pauseAt 117600
    xcrun simctl io <udid> screenshot shot.png

`stubs.m` stands in for the player and the store: the position runs from `-at` at `-rate` and holds at
`-pauseAt` (for `-holdFor` seconds, then runs on). `main.m` lists every launch argument; the lyrics'
own settings are taken by their keys, e.g. `-spotifyglass.redesign.lyricsPronunciation 1`.

The fixtures are real TTML and LRC with every word swapped for filler of the same script and length
(`fixtures/anonymise.py`), so each keeps its song's timing and structure without its lyrics:

- `duet` two voices and a group over each other, three at once in places (from about 99 s)
- `romanised` Japanese with Apple's word timed pronunciation, backing rows, an 11 s break at 114.7 s
- `translated` Spanish with Apple's English translation and backing rows carried into it
- `both` Korean with both, and English lines the pronunciation leaves out
- `plain` line timed LRC, the words estimated, with a 13 s intro and a break after the first line
- `linetimed` TTML timed by the line only (BiniLyrics' line timed shape): two voices, two lines sung
  over each other at 42.4 s, a Hebrew line at 50.6 s, a 9 s break at 85.4 s, translations
- `spotify-line`, `spotify-static` Spotify's own color-lyrics JSON, LINE_SYNCED and UNSYNCED, read by
  the real `SGKaraokeLinesFromBody`; `static` plain text, as LRCLIB's plainLyrics
  (these four are written by `fixtures/linetimed.py` from `plain`'s timing)
- `scripts` (built in) a line in each of Japanese, Korean, Chinese, Russian, Greek, Thai, Hindi, Arabic and
  Hebrew among English ones, every other one translated, for `-spotifyglass.lyricsRomanised 1`
- `rtl` (built in) right to left lines among left to right ones, a second voice, a break before the
  last line; `rtlx` the same with translations and a romanization

Lines timed by the line light up whole; `-spotifyglass.lyricsSimulateWords 1` sweeps them on the
estimate instead, as the Lyrics page's switch does. Untimed lyrics show every line lit, whatever `-at`.

Run it on an iOS 26 simulator, by UDID: iOS 27 refuses an app without a scene delegate and crashes it
at launch. `-dumpTo PATH` writes the dump to a file, for when `--console` shows nothing.

`./translation-check.sh` runs the lyrics menu's translation checks (`translation-check.m`) on the Mac, built for
Mac Catalyst, with no simulator: two views on one song, the real menu items tapped, stubs.m's saved translations
and job tokens behind them. It exits with the number of failures.
The build is build.sh's with three changes: the target is `arm64-apple-ios17.0-macabi`, the SDK is the macOS one
with `-iframework $SDK/System/iOSSupport/System/Library/Frameworks`, and the binary goes into
`Check.app/Contents/MacOS/` in a new `mktemp -d` folder under /tmp, which it then launches with `-translationCheck 1`.

`SG_LYRICS_REVIEW_ONLY=1 bash harness/lyrics/translation-check.sh` runs the focused regressions:
background layout snapshots, style changes during first measurement, stale AI actions, preview siblings,
track changes during a seek hold, cancellation during the download glyph's ring-closing delay, and
stale song-language actions (manual, Automatic, and Keep) with current-track controls.
The glyph is production code; the clock, providers and Spotify view-tree reader are test doubles.
Artwork association in `SGRBridges.x` still needs a Spotify/device check.

`SG_LYRICS_WRAP_ONLY=1 bash harness/lyrics/translation-check.sh` runs joined-group, oversize,
Japanese and ordinary-word wrapping plus ruby and generated-pronunciation row-fragment checks.
Set `HARNESS_BUILD_DIR` to your own `mktemp -d` directory to select the build location; the
script removes that directory on exit.

A real file goes in with `-file /path/song.ttml`: the simulator reads the Mac's paths.

`-perf LABEL` logs the view's per frame cost (its display link's `tick`) every 240 frames; run with
`simctl launch --console` to read it. `-dump 1` prints the lines as read, with their pronunciations,
translations and romanized readings, and quits. `-romanise 1` checks the romanized readings
(`Shared/Lyrics/Romanise.m`) and logs then exits nonzero if any failed. `-light 1` puts the window in light mode.
Menu actions, AI requests and text-role toggles are owned by `translation-check.sh`, including
`review-check.inc`, `extras-check.inc` and `round-one-check.inc`; timed screenshot rehearsals are omitted.

A screen recording catches the motion: `simctl io <udid> recordVideo -f run.mp4`, then e.g.
`ffmpeg -i run.mp4 -vf "fps=10,crop=1206:520:0:560,scale=233:-1,tile=12x1" -frames:v 1 strip.png`.

What it does not cover: Spotify's pages around the view (the player's stage is only its size, `-player 1`),
the lyrics arriving late or changing track, and the device's frame pacing.


`translation-check.sh` also runs `auto-check.inc` on Mac Catalyst, without a simulator or network.
It links the actual automatic scheduler, provider chain and lyrics view with scripted providers and
an in-memory saved-results store. Two separately hosted views exercise default-off, order validation,
failure fallback, partial preservation, cached replay, removal/manual suppression, bounded failed
attempts, disabling/reordering during a request, target/track changes, hidden/detached views, language
rules, enabling a service later and clear-all cancellation. Layout and display ticks are driven explicitly;
the asynchronous checks start from a timer so a nested run loop can drain main-queue completions.
The existing manual translation and AI-view checks run in the same invocation. Live provider accuracy,
phone layout and real Apple language downloads remain outside this harness.

The same Catalyst check also exercises generation-guarded translation status, per-song retry,
no-ready-service versus failed/partial results, cancellation and removal clearing stale status, and
live word-timing changes in two views. The actual tools menu identifies all timing modes and its
estimate toggle changes both views immediately. `TranslationStatusView.m` is linked unchanged;
running/failed status visibility is asserted without screenshot output.
The separate `harness/connection-test-settings/` smoke covers the connection-test row and result alerts.
