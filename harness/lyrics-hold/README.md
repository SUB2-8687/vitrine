# Lyrics hold harness

Holding a line in the redesign's lyrics (`Redesigned/Lyrics/SGRKaraokeView.m`): the menu it opens, what Copy puts
on the pasteboard, what Share says, VoiceOver's actions, and the menu's anchor and dismissal. The real view, with
`../lyrics/stubs.m` standing in for the player.

    ./build.sh
    xcrun simctl install <udid> build/LyricsHoldHarness.app
    xcrun simctl launch --console <udid> com.vojta.lyricsholdharness -check 1

`-check 1` prints PASS and FAIL lines and exits with the number of failures.

## What it does and does not show

The press is reported to the view's own `-held:` as one recognizer state at a time — `Began` opens the menu, and
`Changed` and `Ended` follow on the same line — the interaction's `-presentEditMenuWithConfiguration:` is recorded
instead of presented, and the edit menu delegate's three answers (items, anchor, dismissal) are called by hand with a
configuration. So the check covers the page's own decisions and state: which items a line offers, exactly what Copy
writes, what Share says, which lines get nothing, VoiceOver's actions, that the anchor survives Changed and Ended and
is let go only with its own menu, that a menu opened on another line while one is up keeps its items and anchor when
the old one's dismissal arrives and is let go by its own, that a configuration left over from before answers for
nothing, and that the menu goes with a line's view on every removal path (a restyle, an offscreen eviction, the song's
lines being dropped).

It does not show, because there is no finger or no UIKit presentation in it: recognizer arbitration between the long
press and the page's tap and scroll, the menu as UIKit draws and animates it, a real touch on its items, the share
sheet's own contents, and the haptics. Those are the phone's.

## The phone's pass (Lead)

1. Hold a lyric line: the menu shows **Copy**, **Share**, **Share as Card**, and **Meaning** first where that line has a meaning; a light
   tap is felt once with Vibrations → Controls on, and nothing with it off.
2. Hold and drag a little, then let go: the menu stays where it opened on that line, and closes from its own dismissal
   or a tap elsewhere.
3. With the menu up, wait for a translation to arrive (or change the Lyrics page's text size): the menu closes rather
   than pointing at a line that has gone.
4. With a menu up on one line, hold another line: the new menu opens on the new line, with its own items and its arrow
   on that line, and the first one closing does not disturb it.
5. Copy: paste into Notes — the line alone, no title, artist, translation or pronunciation.
6. Share: the line, then `— <title> · <artist>`, then `https://open.spotify.com/track/<id>` for a streamed track and
   no link for a local file; never a timestamp.
7. A tap still seeks to the line, and the page still scrolls and follows the song, with the menu never opened by a
   tap or a scroll.
8. A hold on the Sing mic, the translate button and its menu, and the auto-translation status note opens nothing.
9. VoiceOver: on a line, the actions read "Meaning" (where it has one), "Copy line", "Share line", and each does what
   the menu's item does.
