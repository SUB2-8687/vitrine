// The redesign's now playing bar: the glass card it becomes (NowPlayingBar.x), on an iPad of regular width a capsule
// with shuffle, repeat, lyrics and queue buttons (no switch; Redesigned/Player/Player.h's SGRPlayerIPadRegular), Spotify's device button
// on that card hidden on request (BarConnect.x), glass behind the bar's and the tab bar's stand-ins while
// the player opens and closes (BarTransition.x), and the bar's rows in Mod Settings
// (NowPlayingBarSettings.m). The redesign keeps its own copy of the hide switch and its own key; the
// native look's lives in Native/NowPlayingBar/.
#import <UIKit/UIKit.h>

@class SGModRow;

#define SGRHideBarConnect @"spotifyglass.redesign.hide.barConnect"   // the device button on the card
// The device button kept on the card in the minimized tab bar's row (NowPlayingBar.x), off unless set: by
// default the row has the cover, the title and play alone, as the Music app's. Read each time the card goes
// into the row, so a change shows the next time the bar minimizes.
#define SGRKeyBarInlineConnect @"spotifyglass.redesign.nowPlayingBar.inlineConnect"
// The artists on a second line under the title in that row, off unless set, and only when both lines fit the
// bar's height (NowPlayingBar.x SGRBarText). A change lays the bar out again at once.
#define SGRKeyBarInlineArtist @"spotifyglass.redesign.inlinePlayer.artist"
// A Next button after play on the full card, as the Music app's mini player has, off unless set
// (NowPlayingBar.x SGRBarNextButton). The minimized row keeps play alone. A change lays the bar out again at once.
#define SGRKeyBarNextButton @"spotifyglass.redesign.nowPlayingBar.nextButton"
// The cover's shape on the card, Circle unless set; the player's open and close morph from it. A change lays the
// bar out again at once.
typedef NS_ENUM(NSInteger, SGRBarArtworkShape) {
    SGRBarArtworkShapeRoundedSquare = 0,
    SGRBarArtworkShapeCircle = 1,
};
#define SGRKeyBarArtworkShape @"spotifyglass.redesign.nowPlayingBar.artworkShape"

// The bar's rows, the Mini player section of the Player page (Redesigned/Player/PlayerSettings.m): Apple
// Music style (the tab bar's Minimize on scroll, Redesigned/Navbar/Navbar.h), the device button in that
// row, the artists under the title in that row, the Next button, the artwork's shape, and the device button
// hidden on the full card.
NSArray<SGModRow *> *SGRNowPlayingBarRows(void);

// The bar's glass card in `host`'s coordinates, with its corner radius; CGRectNull before the bar has
// been styled or while it is out of a window (NowPlayingBar.x). The bar keeps its geometry while
// Spotify hides it for the player's open and close.
CGRect SGRNowPlayingCardFrameIn(UIView *host, CGFloat *radius);
// The artwork on that card in `host`'s coordinates, with its corner radius; CGRectNull when none was found.
CGRect SGRNowPlayingArtworkFrameIn(UIView *host, CGFloat *radius);
// Lays the bar out again at once, into the minimized tab bar's slot or back above the bar
// (Navbar.h's SGRTabBarInlineSlot); TabBar.x calls it inside its own animation.
void SGRNowPlayingBarFollowTabBar(void);
