# System menu harness

`Redesigned/ContextMenu/ContextMenu.x` and `Redesigned/Player/PlayerMenu.m` run for real against a mock of
Spotify's player ⋯ and its context menu sheet (`ContextMenu_InternalImpl.ContextMenuViewController` under its
class name, inside a navigation controller): 15 rows, each an Encore-style ListRow control whose identifier is
Spotify's item number and which acts on touch up inside, no `didSelect`, Sleep timer last and below the sheet's
fold, as on the phone. Speed, pitch, reverb and Animated artwork are stubs that log. Playing Next presents
a UIKit navigation panel from the real player-menu handler.

    THEOS=$HOME/theos ./build.sh
    xcrun simctl install <udid> build/SystemMenuHarness.app
    xcrun simctl launch --console-pty <udid> com.vitrine.systemmenuharness <scenario>

The header row is shaped like Spotify's (`trees/clean/player/01.txt`: a 402x48 row, the down arrow 48x48 at x 12
and the ⋯ 48x48 at the trailing edge), each button with a 44pt glass circle first among its subviews taking no
touches, as `PlayerHeader.x` leaves them. The player's ⋯ is the mod's own pull-down button over Spotify's ⋯, and
a tap on it is a finger's touch (`../tabbar/touch.m`), down and up at its middle: UIKit opens the button's menu
on the touch down. (Until 2026-10-06 the harness tapped with `-performPrimaryAction`, which opens a button's menu
whether or not the button holds one yet, and so missed that a finger's touch on the mod's button, holding none
until asked, was taken and opened nothing: the phone's ⋯ did nothing.) Each run taps at 1 s and prints `PASS`
or `FAIL` lines, then `done`. A pick, or opening a submenu, goes through the menu view's own
selection (`_UIContextMenuView`'s `_handleSelectionForElement:`), the harness's only private call; the mod's own
lines (`SGLog`) go to the unified log.

The ordinary sheet scenarios first check the top level: the menu is on screen (within 1 s, the simulator's
first menu of a launch being slow), the mod's ⋯ takes touches, the quick row (Share, Add to Playlist, Add to
Queue), Speed, Pitch & Reverb, Show Animated Artwork and More are in it and none of Spotify's other rows are;
then that Spotify's ⋯ action ran once, from code, after the menu was up, that Speed and pitch was told the
sheet is the player's, and that the sheet is in the mod's window under the app's, unseen, with the menu still up.
The delayed and timeout scenarios instead hold the Spotify presentation while checking the real menu's
selection or dismissal, then deliver or withhold Spotify's sheet.

- `arrow`: the mod's ⋯ sits exactly over Spotify's in the window, above its glass circle and glyph, with the ⋯'s
  label for VoiceOver; a finger on the down arrow runs Spotify's arrow action, reaches nothing of the mod's and
  opens no menu; a finger on the ⋯ then sends the mod's button its touch down and opens the menu, and the press
  (what `PlayerHeader.x`'s circle listens to) holds while the menu is up and is let go as it ends.
- `timing`: one cold opening and one warm opening after the menu and backing sheet dismiss.
  Checks the one-second cold and 250 ms warm limits, without repeated screenshot/timing rehearsals.
- `rows`: More holds Go to album, the grayed-out Lyrics and Sleep timer (below the sheet's fold), not the rows
  the quick row has; picking Go to album taps Spotify's row and the sheet goes.
- `loading`: the first menu ever, its rows 1.5 s late: More shows the system's loading row, then the rows come
  into the open More, and Go to album fires.
- `stored`: a first menu reads and stores the rows and is closed with no pick (its sheet goes); a second menu's
  sheet holds its rows back: More shows the stored rows at once, a pick on them waits, and fires once the live
  rows come.
- `quick`: Add to Queue is picked at once; the rows come 1.2 s after the sheet, and the pick waits for them.
- `quicklate`: Add to Playlist is picked and the rows never come: after 4 s Spotify's sheet is shown.
- `podcast`: a sheet with no Add to playlist row: once its rows are in, the quick row drops Add to Playlist while
  the menu is up, and More holds Go to show.
- `close`: closing the menu with no pick takes the hidden sheet away within 1 s, and a second tap opens again.
- `subpage`: the quick Share taps Spotify's Share, which pushes a page inside the sheet: the sheet is shown over
  the player, on that page; closed, the mod's window goes back under the app's.
- `sleep`: More's Sleep timer pushes its options page 0.3 s later: the same.
- `sleeppresent`: More's Sleep timer presents a context menu sheet of its own from the player, as on the phone:
  that sheet shows as Spotify's, in the app's window, no menu comes up for it, Spotify's ⋯ action ran once, and
  the card it came from goes unseen.
- `sort`: a row of the mod's own in the sheet's header (as the playlist's Sort) is in More and fires.
- `animated`: Show Animated Artwork switches it on and the sheet goes.
- `wrapped`: Spotify presents a controller of its own that puts the sheet in only as it appears
  (NavigationUI_SheetImpl.ContainerViewController on the phone); More and a pick work the same.
- `delayed-pick`, `delayed-close`: hold Spotify's presentation until after a selection or dismissal has
  ended the menu and released its anchor's session. The pending request keeps the session alive.
  Add to Queue runs exactly once on arrival after a selection; after dismissal the late sheet is
  discarded without firing anything. Weak references verify session deallocation after the sheet
  goes, beyond both timeout callbacks.
- `delayed-wrapped-pick`, `delayed-wrapped-close`: the same delayed presentation with a wrapper that
  adds the sheet only in `viewWillAppear:`, using Spotify's wrapper class identity.
- `delayed-mod-panel`, `delayed-wrapped-mod-panel`: pick Playing Next through the real menu while
  Spotify's sheet is held. The panel is presented normally and stays visible in the app window:
  it cannot satisfy the pending request. Releasing Spotify's late sheet discards that sheet,
  then releases the session.
- `request-timeout-pick`, `request-timeout-close`: no sheet ever arrives; after an early selection or
  dismissal, the request keeps the session alive until timeout, then releases it without firing an action.
- `request-superseded`: dismiss a menu whose request is pending, then start and end a newer real
  session directly before timeout. This isolates request supersession from UIKit's liquid menu
  animation (reopening during its dismissal traps inside UIKit on iOS 26.5). The newer request replaces
  the single pending slot and releases the old session. The newer cancelled session survives until
  its late sheet is discarded, then is released; neither request fires an action.

Only Spotify's context sheet or its known lazy wrapper can satisfy the pending request; a mod panel cannot.
There is deliberately no presenter-ancestry restriction: Spotify 9.1.90 can present its lazy wrapper from
NowPlayingOverlayContainer, outside the requesting controller's ancestor chain.

Known limitation: cancellation still discards the **next Spotify sheet** within the pending request's
three-second window, not a request-identified sheet. A newer request replaces that single slot. Overlapping
A/B deliveries (including same-presenter A-before-B delivery) and a page ⋯ gesture within the recency
window remain ambiguous; an unrelated Spotify context sheet can satisfy the slot. A sheet arriving after
the request window is not adopted or suppressed by that request. These are documented debt, not guarantees
of request correlation.

Use a unique temporary output directory for checks:

    HARNESS_BUILD_DIR=$(mktemp -d /tmp/fix-menu-session.XXXXXX)
    export HARNESS_BUILD_DIR
    THEOS=$HOME/theos ./build.sh
    xcrun simctl install <udid> "$HARNESS_BUILD_DIR/SystemMenuHarness.app"
    xcrun simctl launch --console-pty <udid> com.vitrine.systemmenuharness delayed-pick

For the ownership mutation check, make a temporary copy of `ContextMenu.x`, change only
`static SGRMenuSession *sg_requesting;` back to `static __weak SGRMenuSession *sg_requesting;`,
and pass its absolute path as `CONTEXT_MENU_SOURCE` to `build.sh` with a separate temporary output
directory. `delayed-pick` must fail because the outstanding request no longer survives menu ending.
For presentation recognition, restore the any-non-alert predicate: `delayed-mod-panel` must fail its panel
visibility check. Mutate only a temporary source copy, never the working source.
Remove only those temporary build/source directories after the runs.
