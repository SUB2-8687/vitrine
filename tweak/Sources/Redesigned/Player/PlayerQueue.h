// Player redesign: Playing Next, the tracks the player has to come (SPTPlayerState.future), as a dark sheet opened
// from the player's ⋯ menu (PlayerMenu.m) and the iPad mini player's queue button (NowPlayingBar.x), and as the iPad
// two column player's side column (PlayerLyrics.x). Spotify's own Queue button in the footer stays Spotify's.
//
// Threading: main thread only.
#import <UIKit/UIKit.h>

// Opens the sheet over what `from` (the ⋯) is in, once the menu it was picked from has gone; nothing while it is
// open already.
void SGRPlayerShowQueue(UIView *from);
// The same list for the two column player's side column (PlayerLyrics.x): no Close and no sheet, a pick skips ahead
// and the list stays. Added as a child of the player's controller by its caller.
UIViewController *SGRPlayerQueueList(void);
