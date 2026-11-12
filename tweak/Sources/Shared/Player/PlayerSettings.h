// Settings of the player that hold for either look.
#import <UIKit/UIKit.h>

UIViewController *SGLockScreenWidgetPage(void);
@class SGModSection;
SGModSection *SGSleepTimerSettingsSection(void);

// Switch to video hidden from the player under either look (VideoSwitch.x), off until switched on.
#define SGKeyHideVideoSwitch @"spotifyglass.hide.videoSwitch"

// A tap on the player's cover opens Spotify's full screen cover unless this is on, under either look: each look's
// handleTap hook on CoverArtTiltView (PlayerGestures.x) returns before Spotify's, as it does while Gestures is on.
// Spotify's flag (cover_art_tilt_enabled) is left alone: with it off the cover has no CoverArtTiltView, which the
// redesign's cover rounding and the native look's hold to play faster hang on. Off until switched on.
#define SGKeyHideFullScreenCover @"spotifyglass.hide.fullScreenCover"
