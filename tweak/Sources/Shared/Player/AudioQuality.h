// The audio quality badge, under either look: the quality of the song playing, the way the Music app's Lossless
// badge sits centered under the progress bar, between the two times, and a tap on it shows the details in a popover
// (AudioQuality.x; the rules are AudioQualityRules.m).
//
// What it says is Spotify's own report for the file it plays (SPTPlayerState's playbackQuality, bitrateLevel),
// read from every player report (SGPlayerStateObserver's playerStateDidReport:), since a quality that changes
// within a song does not change the state's track. Never the quality the user asked for or the highest available.
// Lossless files of the mod's own (Shared/Lossless) are not claimed: the badge says what Spotify streams.
//
// Each look calls SGAudioQualityPlaceBadge from its DurationElementUnit's layout (Redesigned/Player/PlayerControls.x,
// Native/Player/Player.x). The badge is a subview of the unit's view, so the unit's alpha, transforms and hiding
// carry over, and it takes no part in Spotify's layout, so the times and the slider stay where they are.
#import <UIKit/UIKit.h>
#import "AudioQualityRules.h"

// Audio quality on the Player page, under either look: off until switched on, followed at once.
#define SGKeyPlayerAudioQuality @"spotifyglass.player.audioQuality"
// After the Player page's switch has stored the key: the open player follows.
void SGAudioQualitySettingChanged(void);

// Main thread. Centers the badge between `unitView`'s two times, on their middle, while the switch is on and Spotify
// reports a tier for a song playing here; hides it while the scene is landscape, while the times are hidden and where
// it does not fit between them. Returns at once while the switch is off; nothing is added to a unit while there is
// nothing to show.
void SGAudioQualityPlaceBadge(UIView *unitView);
// The badge in `unitView` while it draws (shown, and neither it nor any view above it hidden or faded out), else nil:
// a tap there is the badge's, not a seek.
UIView *SGAudioQualityShownBadge(UIView *unitView);
