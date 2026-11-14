# Harnesses in CI

`.github/workflows/harness.yml` runs the offline macOS / Mac Catalyst checks on
`macos-latest`, on relevant pushes to `main` and `ci/harness`, pull requests,
manual dispatch, and a weekly schedule (Monday 03:00 UTC). Each harness builds
**and runs** its checks; failure does not cancel the other jobs.

CI has two jobs. `plan` (ubuntu) reads the changed files and asks
`scripts/harness-plan.py` which harnesses a change needs: a change selects a
harness when it touches `harness/<dir>/` or any file that harness's build
scripts and sources reach — every repo path named in a build/check script
(`-I ../autoeq/shim`, `VENDOR=../../vendor/audio`, `$SRC/...`), every file
under such a directory, plus transitive quoted imports. A new directory a
build script starts using is picked up without editing the script. A `workflow_dispatch` run given
`paths` (space-separated repo paths) plans from those paths as if they had changed, so one or two harnesses can be
rerun alone. Every harness runs when the event is `workflow_dispatch` without `paths` or
`schedule`, when the changed list cannot be determined (new branch, force push,
shallow history), when a change touches `.github/`,
`scripts/harness-plan.py` or `tweak/Makefile`, or when a changed path is no longer
in the checkout (a deletion, or a rename's old name: the diff is taken with
`--no-renames`), since a harness may still use it. A harness with no tweak
dependency is always selected, with a warning. The selected harnesses are
packed into at most five shards (all Logos/Theos harnesses in one) and run as
`Harnesses <shard>` jobs with a 45-minute timeout. Only that Theos shard uses
the setup-Theos action; its caches contain build tools/output, never
credentials or test data.

Locally, the same script explains and runs selections from the repo root:

```sh
python3 scripts/harness-plan.py explain tweak/Sources/Shared/LockScreenLyrics/SGLyricsClip.m
python3 scripts/harness-plan.py run --names "Pitch" "Palette"
```

The runner locks each harness directory and shared preferences domains for the
whole build and run, printing a waiting line on contention while unrelated
harnesses can run in parallel. Invoking a `build.sh` or check script directly
bypasses these locks.
SIGINT/SIGTERM stop and reap the harness process group before unlocking;
SIGKILL cannot be handled and may leave children running after the kernel
releases the runner's locks.

`plan --changed-from <file|->` prints the selection, shards and matrix JSON.
Selected assertion-based entries use isolated iOS simulators. No phone, Spotify
installation, API credentials or visual review is used.

CI entries do not build mutants. Mutation proofs belong to check creation, not
ordinary runs; Liveprog's `--mutations` and the player's manual Automix script
are explicit opt-ins. `local-files/suggest-sim.py` runs only its assertion scenario
and shuts down/deletes its own simulator. Harness scripts default THEOS to `$HOME/theos`.

Run the commands in the workflow locally on an Apple Silicon Mac with Xcode.
The individual READMEs describe assertions and boundaries. Image/video output
is included only when the executable also checks the result and fails nonzero.
An offline fixture does not establish live-service or device compatibility.

## Included scripts and modes

All paths below are relative to `harness/`. Build-only scripts are followed by
their check executable in the workflow.

| Script | Mode / reason |
| --- | --- |
| `album-counts/check.sh` | Spotify album play counts: cover-layout migration, URI identities, malformed and failed replies, cache bounds, and the authenticated transport's origin, redirect and size limits, with request doubles. |
| `album-credits/build.sh` | Artist-credit matching assertions. |
| `album-notes/build.sh` | Album notes against replayed catalog fixtures, and the page's note placement and footer heights over Spotify collection doubles. |
| `artist-artwork/build.sh` | Artist match and one-attempt identity rules against replayed catalog fixtures, plus the 30 MB clip cap and the Low Data policy. |
| `appearance-accent/check.sh` | Catalyst Automatic accent ownership: page in front, playing cover, picked colour, real UIKit push/pop/tab/modal, and the player's Follow the cover combinations. |
| `appearance-page/rows-check.sh` | Appearance rows of both looks, including the explicit-badge switches. |
| `audio-effects/build.sh` | `route`, `presets` and `format`: isolated settings, preset-file and audio-format text assertions. |
| `auto-translation-settings/check.sh` | Real Catalyst settings callbacks with fake providers. |
| `autoeq/build.sh` | Default offline index/preset fixtures, not `online`. |
| `clean-links/build.sh` | Pure URL-cleaning assertions. |
| `connection-test-settings/check.sh` | Catalyst lifecycle assertions with a fake backend. |
| `driver/auth-check.sh` | Foundation driver-token rotation, header and diagnostic-redaction checks; runs with `driver/phone-check.py`. |
| `driver/command-check.sh` | Driver command classification and log-cursor sequence with the real log buffer. |
| `fluid-clip/build.sh` | Generated cover/video, decoded-frame and loop assertions. |
| `haptics/build.sh` | `build/track`: synthetic ISRC/protobuf/catalog assertions. |
| `head-gestures/build.sh` | Synthetic motion traces with expected gestures. |
| `listening-stats/build.sh` | Synthetic imports, calendar cases and 100k-row checks. |
| `local-files/build.sh` | Isolated metadata and imported LRC checks, the cover resolver, and the native cover watcher (`watcher.m`) updating to system artwork that arrives after its retries. |
| `local-files/suggest-build.py` | Find Info's pure parts on the Mac: query cleaning, the three-second duration window, ranking, JSON parsing and size caps, artwork URL rewriting, and that accepting only fills the editor. |
| `lyrics/translation-check.sh` | Catalyst lyrics-menu assertions, not screenshots alone. |
| `lyrics-clip/build.sh` | Default synthetic still/animated clips with decode assertions, and the Messages and Vinyl scenes (`scenes`). `regression.sh` checks visible-frame geometry and contrast. |
| `lyrics-pip/build.sh` | Catalyst PiP text decision (`LyricsPiPText.m`) for synthetic lines and positions, plus frame fitting checks (`LyricsPiPFrame.m`) and sample frame PNGs. |
| `lyrics-sources/build.sh` | Offline provider/parser/language fixtures. |
| `lyrics-sources/state-build.sh` | Real keeper and concurrent source walk with fake replies. |
| `lyrics-store/build.sh` | Foundation codec, isolated disk reads/writes/deletion, and oldest-first count/byte pruning; builds into a temporary directory and runs the checks itself. |
| `lyrics-translation/build.sh` | Default checks include `check-ai.m`; also `--auto-retry-only`. |
| `lyrics-translation/ondevice-kept-check.sh` | Catalyst Swift check: on-device translation keeps target-language lines as completed results. |
| `meaning-translate/build.sh` | Catalyst meaning sheet's Translate / Show Original over translation doubles for every provider route: stale replies, dismissal, duplicate taps, retry, language change, attribution kept. |
| `motion/build.sh` | Generated Canvas cuts and synthetic protobuf replies. |
| `native-declutter/check.sh` | Production native section classification, isolated heading histories and marker-priority/snapshot checks with Foundation view doubles; no simulator. |
| `now-playing/build.sh` | Logos setter hooks with system setter replaced, lyrics off/on. |
| `palette/build.sh` | Generated image with asserted edge/main colors. |
| `palette/field-check.sh` | Catalyst player field palette requests across mode changes and stale replies. |
| `pitch/build.sh` | Synthetic sine pitch/speed assertions, no song argument. |
| `player/title-notification-check.sh` | Real Logos controller with offline notification fixtures. |
| `now-playing-bar/check.sh` | Catalyst title and artists split of the redesigned now playing bar through Logos: titles with and without " • ", with and without a device line, neighbour pages and an unknown track. |
| `artwork-clear/build.sh` | Clearing downloaded animated covers and artist answers in a sandboxed Caches folder: size, alert, Cancel, leased clips, stale transfers and lookups, failure reporting; songs, chosen covers, edits and lyrics untouched. |
| `fonts/build.sh` | Catalyst `FontLibrary.m` and the Free fonts page with Core Text faked at its two entry calls: installed families register off main, publish on main, never twice, and a removal is never overridden by a late publish; the real Font page (free and imported families) opens and the Free fonts page finishes a download while registrations are held, a block queued on main runs before each release, and the previews and the chosen font update after; a hidden Font page reloads nothing. |
| `gesture-hold/check.sh` | Mac check of the hold-to-play-faster helpers (`GestureHold.m`): defaults, index to speed, clamping, independence from the double tap, label and announcement text. |
| `liveprog-guard/run.py` | Mac run of the real effects engine with EEL2 Liveprog scripts: CPU-budget trips and the click-free bypass, re-enable reset, the two-second compile/@init deadline and abandoned-VM cleanup, no allocation on the render path. Manual mutation proofs require `--mutations`. |
| `library/rows-check.sh` | Simulator executable through Logos: the Library row separator spans from the artwork's text edge, mirrored right to left. |
| `home-podcasts/check.sh` | Catalyst Home filter menu through Logos: the Podcasts and audiobooks switch shown and hidden, audiobook chips, return to the default chip once, live flip; the pill's Friday ring only on a Friday, its turn's pace, fading and stopping with the pill as the row scrolls, stopping and resuming as Reduce Motion is switched, staying still once hidden. |
| `playlist/creator-check.sh` | Simulator executable through Logos: the playlist header's creator lookup keeps one-character names and skips the facepile's initial. |
| `player/lyrics-layout-check.sh` | Catalyst, `PlayerLyrics.x`'s measurements as compiled: the lyric viewport and its controls keep the player's own bounds while the cover cell pages between tracks. |
| `player/repeat-check.sh` | Production repeat-mode transition (`SGPlayerAdvanceRepeat`) extracted from `PlayerState.x`: every flag combination, command order and returned answer; no simulator. |
| `player/upcoming-tracks-check.sh` | Production upcoming-track parsing (`SGURIString`, `SGPlayerUpcomingTracks`) extracted from `PlayerState.x` and run against Foundation doubles; no simulator. |
| `player-lyric-line/build.sh` | Catalyst fitting (shrink and whole-word portions) and the line's wait/re-arm rules for synthetic lines and positions. |
| `adblock/build.sh` | The real `AdHubs.x` hook through Logos against a Hub builder double: explicit ad metadata is removed only with Hide ads on, upsells only with Hide upsells on, in all four switch combinations. |
| `player-visualiser/build.sh` | Catalyst `PlayerVisualiser.m` under stubs: the Lyrics visualizer clears its words when the lyrics are replaced by unsynced ones, and the display link asks the screen's full rate while drawing skips to 60/30/15 Hz. With `PlayerLyricStages.m`: Poster's and Cut's word reveal, the untimed fallback, the parameters' defaults, clamping and removal, the halftone made once per artwork (a failed one final, an older job never replacing a newer), and Reduce Motion. `SHOTS=<folder>` writes `poster.png` and `cut.png`. |
| `player-refinements/check.sh` | Catalyst rolling-digit rules and the real roll on a label in a window, plus Star add button and Plain checkmark through Logos; no simulator. |
| `prefs/check.sh` | Foundation preference validation plus counter persistence and file-hash checks (`counters.m`), and the Load ahead gate read through `SGEnabled` for wrong kinds and stock reset (`optional-work.m`). |
| `radio-modes/build.sh` | Foundation Spotify mocks, spoofing off/on. |
| `settings-bars/build.sh` | Catalyst `SGInsetForBars` over a 6,000-view mock window: walks counted across repeated layouts, inset follows a bar resized, hidden, removed, added, or a table moved to another window. |
| `settings-search/build.sh` | Mod Settings search: page-at-a-time index on a real run loop, keywords below titles, recent places by setting name across looks and languages. |
| `sing/render-regressions-build.sh` | Mac build of `SGSingEngine.m` with audio doubles: placed vocals keep float headroom through downstream attenuation, and the room reverb goes idle once Sing stops feeding it. |
| `sing/build.sh` | `spatial`: model-free lead, spatial and decoder assertions. |
| `sleep-timer/build.sh` | Fake player and timer/fade assertions. |
| `song-audio/build.sh` | Per-song speed, pitch, pitch-follow and reverb records in two processes, with the player and the audio setters as doubles. |
| `spicy-lyrics/build.sh` | Offline parser, cache and retry fixtures. |
| `ui-refinements/badge-check.sh` | Explicit-badge hiding in both looks: only the verified badge views paint nothing, geometry and VoiceOver kept. |
| `update/offline-check.sh` | Catalyst cached-release selection, no network. |
| `visualiser/build.sh` | Synthetic spectrum and PCM waveform assertions. |

## Excluded scripts

This inventory includes the offline scripts above and the simulator/service scripts below.
Simulator use alone does not exclude a check; `scripts/harness-plan.py` is the
authoritative entry list. Visual-only simulator scenarios are not promoted to CI
by merely compiling them.

| Script | Reason |
| --- | --- |
| `addtab/build.sh` | iOS simulator UI. |
| `album/build.sh` | iOS simulator UI. |
| `appearance-page/build.sh` | iOS simulator UI. |
| `artist/build.sh` | iOS simulator UI. |
| `audio-effects-page/build.sh` | iOS simulator UI. |
| `audio-effects/build-import.sh` | iOS simulator import page. |
| `audio-effects/build-output.sh` | iOS simulator output control and render gate. |
| `audio-effects/build-sim.sh` | iOS simulator audio chain. |
| `clean-links/build-sim.sh` | iOS simulator share/pasteboard hooks. |
| `connect/build.sh` | Opens loopback sockets; excluded by the no-network requirement. |
| `driver/build.sh` | iOS simulator driver app. |
| `haptics-page/build.sh` | iOS simulator UI. |
| `home-tiles/build.sh` | iOS simulator UI. |
| `haptics/build-sim.sh` | iOS simulator audio/haptics hooks. |
| `head-gestures/sim/build.sh` | iOS simulator hooks and teaching UI. |
| `launch/build.sh` | Requires an untracked flag table extracted from a Spotify IPA. |
| `library/build.sh` | iOS simulator UI. |
| `library/compact-check.sh` | iOS simulator UI. |
| `listening-stats/build-sim.sh` | iOS simulator UI. |
| `live-activity-page/build.sh` | iOS simulator UI. |
| `local-files/lyrics/build.sh` | iOS simulator lyrics UI. |
| `local-files/sim/build-sim.sh` | iOS simulator editor and screenshots. |
| `local-files/suggest-sim.py` | iOS simulator Edit info with Find Info against network fixtures: review sheet, Use, the picked cover's 1200 px bound, save through the overlay. |
| `lossless/build.sh` | iOS simulator decoder probe. |
| `lossless/handoff-build.sh` | iOS simulator audio chain. |
| `lyrics/build.sh` | iOS simulator lyrics UI. |
| `lyrics-page/build.sh` | iOS simulator settings UI. |
| `menu/build.sh` | iOS simulator UI. |
| `mod-settings/build.sh` | iOS simulator settings UI. |
| `morph/build.sh` | iOS simulator visual rendering. `morph/check.sh` checks the opt-in Music-like close against 9.1.90's compact transition doubles: staged geometry, velocity release, cancellation with the reversed fraction, and the off path's old numbers. |
| `native-player/build.sh` | iOS simulator UI. |
| `onboarding/build.sh` | iOS simulator UI; generates fixture release notes only inside its output directory. |
| `page-previews/build.sh` | iOS simulator: the five page settings with their preview cards, in a simulator of the run's own; asserts what VoiceOver reads and writes PNGs. |
| `player/build.sh` | iOS simulator player UI. |
| `playlist/build.sh` | iOS simulator UI. |
| `shortcuts/build.sh` | iOS simulator App Intents. |
| `sing/build-sim.sh` | iOS simulator audio chain and external model/voice. |
| `sing/button/build.sh` | iOS simulator mic-button UI. |
| `sing/download/build.sh` | Downloads the model over the network. |
| `spatial-page/build.sh` | iOS simulator UI. |
| `speed/build.sh` | iOS simulator audio chain. |
| `system-menu/build.sh` | iOS simulator UI. |
| `tabbar/build.sh` | iOS simulator UI. |
| `tabbar/fade-check.sh` | iOS simulator UI. |
| `update/build.sh` | iOS simulator and live GitHub requests. |

Excluded modes of otherwise included scripts: AutoEq `online` and translation
`--bing-live` contact services; full Sing needs a downloaded model and voice;
the audio-effects engine and haptics analyzer need external song/scoring inputs.
Optional user-supplied images, songs, saved provider replies and videos are not
used. Lyrics clips' `motion` scenarios require additional video/FFmpeg fixtures;
the default clip assertions remain enabled.
